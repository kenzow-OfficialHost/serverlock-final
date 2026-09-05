<?php

namespace Pterodactyl\Http\Controllers\Extensions\Serverlock;

use Illuminate\Http\Request;
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
 */
class LockController extends Controller
{
    use ResolvesServer;

    /**
     * Cari server berdasarkan uuidShort dan pastikan user yang login
     * berhak akses server itu (pemilik atau root admin).
     */
    protected function findServerForUser(Request $request, string $identifier): Server
    {
        $server = Server::where('uuidShort', $identifier)->firstOrFail();

        $user = $request->user();

        // TODO: sesuaikan dengan logic permission asli Pterodactyl kamu
        // (owner ATAU subuser dengan akses ke server ini). Ini baru cek pemilik.
        abort_unless(
            $server->owner_id === $user->id || $user->root_admin,
            403,
            'Kamu tidak punya akses ke server ini.'
        );

        return $server;
    }

    /**
     * GET status/{server} -> cek apakah server ini dikunci password.
     */
    public function status(Request $request, string $server)
    {
        $srv = $this->findServerForUser($request, $server);

        $lock = DB::table('ext_serverlock_locks')
            ->where('server_uuid', $srv->uuid)
            ->first();

        return response()->json([
            'locked' => $lock ? (bool) $lock->enabled : false,
        ]);
    }

    /**
     * POST verify/{server} -> cek password yang diketik user benar atau nggak.
     * body: { "password": "..." }
     */
    public function verify(Request $request, string $server)
    {
        $request->validate([
            'password' => 'required|string',
        ]);

        $srv = $this->findServerForUser($request, $server);

        $lock = DB::table('ext_serverlock_locks')
            ->where('server_uuid', $srv->uuid)
            ->first();

        if (!$lock || !$lock->enabled) {
            return response()->json(['valid' => true]);
        }

        $valid = Hash::check($request->input('password'), $lock->password_hash);

        return response()->json(['valid' => $valid], $valid ? 200 : 401);
    }
}
