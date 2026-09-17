<?php

namespace Pterodactyl\Http\Controllers\Extensions\Serverlock\Concerns;

use Pterodactyl\Models\Server;
use Pterodactyl\Models\User;

trait ResolvesServer
{
    /**
     * Cari Server berdasarkan uuidShort (yang muncul di URL /server/xxxxx),
     * uuid penuh, atau ID numerik — dipakai baik dari HTTP controller,
     * artisan command (CLI), maupun middleware.
     */
    protected function resolveServer(string $identifier): ?Server
    {
        return Server::where('uuidShort', $identifier)
            ->orWhere('uuid', $identifier)
            ->orWhere('id', is_numeric($identifier) ? (int) $identifier : -1)
            ->first();
    }

    /**
     * Bikin password acak yang aman tapi gampang diketik ulang oleh user
     * (hindari karakter yang gampang ketuker: 0/O, 1/l/I).
     */
    protected function generateReadablePassword(int $length = 10): string
    {
        $chars = 'ABCDEFGHJKMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789';
        $max = strlen($chars) - 1;
        $out = '';

        for ($i = 0; $i < $length; $i++) {
            $out .= $chars[random_int(0, $max)];
        }

        return $out;
    }

    /**
     * Cek apakah $user boleh akses $server -- dipakai bareng oleh
     * LockController (endpoint status/verify) DAN EnsureServerUnlocked
     * middleware (validasi grant), supaya definisi "boleh akses"-nya cuma
     * ada di SATU tempat, nggak dobel-tulis dan gampang out-of-sync.
     *
     * Aturan:
     *  - root admin selalu boleh.
     *  - pemilik server selalu boleh.
     *  - subuser yang memang ditambahkan ke server itu ikut boleh
     *    (sebelumnya subuser di-403 terus, ini yang diperbaiki).
     */
    protected function userCanAccessServer(?User $user, Server $server): bool
    {
        if (!$user) {
            return false;
        }

        if ($user->root_admin) {
            return true;
        }

        if ((int) $server->owner_id === (int) $user->id) {
            return true;
        }

        return $server->subusers()->where('user_id', $user->id)->exists();
    }
}
