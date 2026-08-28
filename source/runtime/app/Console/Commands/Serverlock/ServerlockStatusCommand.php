<?php

namespace Pterodactyl\Console\Commands\Serverlock;

use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
use Pterodactyl\Http\Controllers\Extensions\Serverlock\Concerns\ResolvesServer;
use Pterodactyl\Models\Server;

/**
 * php artisan serverlock:status            -> daftar semua server yang PERNAH diset (locked/unlocked)
 * php artisan serverlock:status {server}    -> status satu server spesifik
 */
class ServerlockStatusCommand extends Command
{
    use ResolvesServer;

    protected $signature = 'serverlock:status {server? : uuidShort, uuid, atau ID server (kosongkan untuk lihat semua)}';

    protected $description = 'Lihat status lock server (satu server, atau daftar semua yang pernah diset).';

    public function handle(): int
    {
        $identifier = $this->argument('server');

        if ($identifier) {
            $srv = $this->resolveServer($identifier);

            if (!$srv) {
                $this->error("Server dengan identifier '{$identifier}' tidak ditemukan.");

                return self::FAILURE;
            }

            $lock = DB::table('ext_serverlock_locks')->where('server_uuid', $srv->uuid)->first();

            $this->line("Server : {$srv->name} ({$srv->uuidShort})");
            $this->line('Status : ' . ($lock && $lock->enabled ? '<fg=red>TERKUNCI</>' : '<fg=green>tidak dikunci</>'));

            return self::SUCCESS;
        }

        $locks = DB::table('ext_serverlock_locks')->get();

        if ($locks->isEmpty()) {
            $this->comment('Belum ada satu pun server yang pernah diset lewat serverlock:lock.');

            return self::SUCCESS;
        }

        $rows = $locks->map(function ($lock) {
            $srv = Server::where('uuid', $lock->server_uuid)->first();

            return [
                $srv->uuidShort ?? '(server dihapus)',
                $srv->name ?? '-',
                $lock->enabled ? 'TERKUNCI' : 'tidak dikunci',
                $lock->updated_at,
            ];
        });

        $this->table(['uuidShort', 'Nama Server', 'Status', 'Terakhir diubah'], $rows);

        return self::SUCCESS;
    }
}
