<?php

namespace Pterodactyl\Http\Controllers\Extensions\Serverlock;

use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Pterodactyl\Http\Controllers\Controller;
use Pterodactyl\Http\Controllers\Extensions\Serverlock\Concerns\ResolvesServer;
use Pterodactyl\Models\Server;

/**
 * PENTING: sengaja CUMA ada 2 endpoint publik di sini (status & verify).
 *
 * Mengunci (set password) dan membuka paksa (disable) server SENGAJA
 * TIDAK bisa dilakukan lewat web/API sama sekali -- itu cuma bisa lewat
 * artisan command yang dijalankan admin via SSH di VPS panel:
 *
 *   php artisan serverlock:lock {server}
 *   php artisan serverlock:unlock {server}
 *   php artisan serverlock:status [{server}]
 *
 * Kalau server belum pernah di-lock lewat command itu, dia otomatis
 * TIDAK terkunci (default aman, opt-in per server).
 *
 * ENFORCEMENT BENERAN ada di EnsureServerUnlocked (middleware, jalan di
 * semua route /api/client/servers/{server}/**). Endpoint verify() di sini
 * cuma satu-satunya cara buat DAPETIN grant itu -- password yang benar
 * bikin baris baru/refresh di ext_serverlock_unlocks yang divalidasi
 * middleware, bukan sekadar balikin true/false ke frontend.
 */
class LockController extends Controller
{
    use ResolvesServer;

    /** Berapa lama grant "sudah verifikasi" berlaku sebelum harus masukin password lagi. */
    protected const GRANT_TTL_HOURS = 4;

    /** Maksimal percobaan password salah beruntun sebelum kena lockout sementara. */
    protected const MAX_ATTEMPTS = 5;

    /** Lama lockout sementara (menit) setelah kehabisan percobaan. */
    protected const LOCKOUT_MINUTES = 5;

    /**
     * Cari server berdasarkan uuidShort dan pastikan user yang login
     * berhak akses server itu (pemilik, subuser, atau root admin).
     */
    protected function findServerForUser(Request $request, string $identifier): Server
    {
        $server = Server::where('uuidShort', $identifier)->firstOrFail();

        abort_unless(
            $this->userCanAccessServer($request->user(), $server),
            403,
            'Kamu tidak punya akses ke server ini.'
        );

        return $server;
    }

    /**
     * GET status/{server} -> cek apakah server ini dikunci, dan apakah
     * user yang lagi login udah punya grant unlock yang masih berlaku.
     */
    public function status(Request $request, string $server)
    {
        $srv = $this->findServerForUser($request, $server);
        $user = $request->user();

        $lock = DB::table('ext_serverlock_locks')
            ->where('server_uuid', $srv->uuid)
            ->first();

        $locked = $lock ? (bool) $lock->enabled : false;

        $alreadyUnlocked = false;

        if ($locked) {
            $alreadyUnlocked = DB::table('ext_serverlock_unlocks')
                ->where('user_id', $user->id)
                ->where('server_uuid', $srv->uuid)
                ->where('expires_at', '>', now())
                ->exists();
        }

        return response()->json([
            'locked' => $locked,
            // Grant dari sesi verify sebelumnya masih berlaku -> frontend
            // nggak perlu nampilin form password lagi.
            'already_unlocked' => $alreadyUnlocked,
        ]);
    }

    /**
     * POST verify/{server} -> cek password yang diketik user, dan kalau
     * benar, terbitkan grant unlock (dibaca middleware EnsureServerUnlocked).
     * body: { "password": "..." }
     *
     * Rate limit ganda:
     *  - route-level: throttle:8,1 (lihat routes/client.php)
     *  - lockout per (user, server) di tabel ext_serverlock_attempts, biar
     *    nggak gampang dihindari cuma dengan ganti IP.
     */
    public function verify(Request $request, string $server)
    {
        $request->validate([
            'password' => 'required|string',
        ]);

        $srv = $this->findServerForUser($request, $server);
        $user = $request->user();

        $lock = DB::table('ext_serverlock_locks')
            ->where('server_uuid', $srv->uuid)
            ->first();

        if (!$lock || !$lock->enabled) {
            return response()->json(['valid' => true]);
        }

        $attempt = DB::table('ext_serverlock_attempts')
            ->where('user_id', $user->id)
            ->where('server_uuid', $srv->uuid)
            ->first();

        if ($attempt && $attempt->locked_until && Carbon::parse($attempt->locked_until)->isFuture()) {
            $retryAfter = now()->diffInSeconds(Carbon::parse($attempt->locked_until));

            return response()->json([
                'valid' => false,
                'locked_out' => true,
                'retry_after' => $retryAfter,
                'message' => "Terlalu banyak percobaan salah. Coba lagi dalam {$retryAfter} detik.",
            ], 429);
        }

        $valid = Hash::check($request->input('password'), $lock->password_hash);

        if (!$valid) {
            $attempts = ($attempt->attempts ?? 0) + 1;
            $lockedUntil = null;

            if ($attempts >= self::MAX_ATTEMPTS) {
                $lockedUntil = now()->addMinutes(self::LOCKOUT_MINUTES);
                $attempts = 0; // reset hitungan, mulai dari nol lagi setelah lockout habis
            }

            DB::table('ext_serverlock_attempts')->updateOrInsert(
                ['user_id' => $user->id, 'server_uuid' => $srv->uuid],
                [
                    'attempts' => $attempts,
                    'locked_until' => $lockedUntil,
                    'updated_at' => now(),
                    'created_at' => $attempt->created_at ?? now(),
                ]
            );

            return response()->json(['valid' => false], 401);
        }

        // Password benar: reset counter percobaan & terbitkan grant unlock.
        DB::table('ext_serverlock_attempts')
            ->where('user_id', $user->id)
            ->where('server_uuid', $srv->uuid)
            ->delete();

        $expiresAt = now()->addHours(self::GRANT_TTL_HOURS);

        DB::table('ext_serverlock_unlocks')->updateOrInsert(
            ['user_id' => $user->id, 'server_uuid' => $srv->uuid],
            [
                'expires_at' => $expiresAt,
                'updated_at' => now(),
                'created_at' => now(),
            ]
        );

        return response()->json([
            'valid' => true,
            'expires_at' => $expiresAt->toIso8601String(),
        ]);
    }
}
