<?php

namespace Pterodactyl\Http\Middleware\Extensions\Serverlock;

use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Pterodactyl\Models\Server;
use Pterodactyl\Http\Controllers\Extensions\Serverlock\Concerns\ResolvesServer;

/**
 * Ini jantungnya fix #1 (enforcement backend, bukan cuma UI).
 *
 * Didaftarkan ke middleware group 'client-api' lewat
 * RouteServiceProvider::boot() (Route::pushMiddlewareToGroup), jadi jalan
 * di SEMUA route /api/client/servers/{server}/** -- termasuk endpoint
 * websocket token buat console, file manager, database, backup, schedule,
 * dst. LockGate.tsx di frontend sekarang cuma UX (nyembunyiin tombol biar
 * rapi) -- kalau ada yang coba skip frontend & manggil API langsung
 * (curl/Postman/devtools), middleware ini yang beneran nolak.
 *
 * "Terverifikasi" dicek dari tabel ext_serverlock_unlocks (grant yang
 * dikeluarkan LockController::verify() saat password benar, punya masa
 * berlaku), BUKAN dari state React -- jadi grant ini valid dipakai lintas
 * request/tab/refresh sampai expired.
 */
class EnsureServerUnlocked
{
    use ResolvesServer;

    /**
     * Route milik ServerLock sendiri (status & verify) jangan pernah
     * diblok middleware ini sendiri -- kalau ke-block, user nggak akan
     * pernah bisa masukin password buat buka lock-nya.
     */
    protected const BYPASS_PREFIXES = [
        'api/client/extensions/serverlock',
    ];

    public function handle(Request $request, Closure $next)
    {
        foreach (self::BYPASS_PREFIXES as $prefix) {
            if ($request->is($prefix . '*')) {
                return $next($request);
            }
        }

        $server = $this->resolveServerFromRoute($request);

        // Route ini nggak terikat ke satu server spesifik (mis. akun,
        // daftar server, dll) -- nggak relevan buat ServerLock, lewatin.
        if (!$server) {
            return $next($request);
        }

        $user = $request->user();

        // Root admin selalu bisa lewat -- dia yang pasang lock lewat SSH,
        // jadi nggak masuk akal ngunci diri sendiri di luar.
        if ($user && $user->root_admin) {
            return $next($request);
        }

        $lock = DB::table('ext_serverlock_locks')
            ->where('server_uuid', $server->uuid)
            ->first();

        // Server ini belum pernah di-lock lewat serverlock:lock -> lewat
        // seperti biasa (default aman, opt-in per server).
        if (!$lock || !$lock->enabled) {
            return $next($request);
        }

        $hasValidGrant = $user && DB::table('ext_serverlock_unlocks')
            ->where('user_id', $user->id)
            ->where('server_uuid', $server->uuid)
            ->where('expires_at', '>', now())
            ->exists();

        if ($hasValidGrant) {
            return $next($request);
        }

        return response()->json([
            'error' => 'Server ini terkunci. Masukkan password lewat halaman console dulu.',
            'serverlock' => true,
        ], 423); // 423 Locked
    }

    /**
     * Ambil instance Server dari route saat ini, apapun bentuk binding-nya
     * (model instance, uuid, uuidShort, atau id numerik).
     */
    protected function resolveServerFromRoute(Request $request): ?Server
    {
        $param = $request->route('server');

        if ($param instanceof Server) {
            return $param;
        }

        if (is_string($param) && $param !== '') {
            return $this->resolveServer($param);
        }

        return null;
    }
}
