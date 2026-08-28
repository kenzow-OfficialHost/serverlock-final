<?php

namespace Pterodactyl\Console\Commands\Serverlock;

use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Pterodactyl\Http\Controllers\Extensions\Serverlock\Concerns\ResolvesServer;

/**
 * php artisan serverlock:lock {server} [--length=10]
 *
 * {server} boleh diisi: uuidShort (yang muncul di URL /server/xxxxx),
 * uuid penuh, atau ID numerik server di database.
 *
 * Password SELALU digenerate otomatis oleh sistem (bukan diketik manual)
 * dan cuma ditampilkan SEKALI di layar ini -- catat baik-baik / kirim ke
 * client lewat jalur aman, karena tidak disimpan dalam bentuk plaintext
 * di database (yang tersimpan cuma hash-nya).
 */
class LockServerCommand extends Command
{
    use ResolvesServer;

    protected $signature = 'serverlock:lock {server : uuidShort, uuid, atau ID server} {--length=10 : panjang password yang digenerate}';

    protected $description = 'Kunci sebuah server dengan password yang digenerate otomatis (hanya bisa dijalankan dari VPS/SSH).';

    public function handle(): int
    {
        $identifier = $this->argument('server');
        $length = max(6, (int) $this->option('length'));

        $srv = $this->resolveServer($identifier);

        if (!$srv) {
            $this->error("Server dengan identifier '{$identifier}' tidak ditemukan.");
            $this->line('Gunakan uuidShort (contoh: afee3ff4), uuid penuh, atau ID numerik server.');

            return self::FAILURE;
        }

        $password = $this->generateReadablePassword($length);

        DB::table('ext_serverlock_locks')->updateOrInsert(
            ['server_uuid' => $srv->uuid],
            [
                'password_hash' => Hash::make($password),
                'enabled' => true,
                'updated_at' => now(),
                'created_at' => now(),
            ]
        );

        $this->newLine();
        $this->info("Server '{$srv->name}' (uuidShort: {$srv->uuidShort}) berhasil dikunci.");
        $this->line('Password (catat sekarang, tidak akan ditampilkan lagi):');
        $this->newLine();
        $this->line("  <fg=black;bg=green> {$password} </>");
        $this->newLine();
        $this->comment('Hash-nya sudah tersimpan di tabel ext_serverlock_locks. Plaintext di atas tidak disimpan di mana pun.');

        return self::SUCCESS;
    }
}
