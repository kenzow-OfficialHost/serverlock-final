<?php

namespace Pterodactyl\Console\Commands\Serverlock;

use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
use Pterodactyl\Http\Controllers\Extensions\Serverlock\Concerns\ResolvesServer;

/**
 * php artisan serverlock:unlock {server}
 *
 * Matiin lock sebuah server (misal lupa password / mau dibuka permanen).
 * Baris di tabel ext_serverlock_locks tidak dihapus, cuma di-nonaktifkan,
 * supaya kalau mau di-lock ulang nanti tinggal jalanin serverlock:lock lagi.
 */
class UnlockServerCommand extends Command
{
    use ResolvesServer;

    protected $signature = 'serverlock:unlock {server : uuidShort, uuid, atau ID server}';

    protected $description = 'Matikan lock pada sebuah server (hanya bisa dijalankan dari VPS/SSH).';

    public function handle(): int
    {
        $identifier = $this->argument('server');
        $srv = $this->resolveServer($identifier);

        if (!$srv) {
            $this->error("Server dengan identifier '{$identifier}' tidak ditemukan.");

            return self::FAILURE;
        }

        $updated = DB::table('ext_serverlock_locks')
            ->where('server_uuid', $srv->uuid)
            ->update(['enabled' => false, 'updated_at' => now()]);

        if (!$updated) {
            $this->comment("Server '{$srv->name}' memang belum pernah dikunci -- tidak ada yang diubah.");

            return self::SUCCESS;
        }

        $this->info("Server '{$srv->name}' (uuidShort: {$srv->uuidShort}) berhasil dibuka / lock dimatikan.");

        return self::SUCCESS;
    }
}
