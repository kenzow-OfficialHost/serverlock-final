<?php

namespace Pterodactyl\Http\Controllers\Extensions\Serverlock\Concerns;

use Pterodactyl\Models\Server;

trait ResolvesServer
{
    /**
     * Cari Server berdasarkan uuidShort (yang muncul di URL /server/xxxxx),
     * uuid penuh, atau ID numerik — dipakai baik dari HTTP controller
     * maupun dari artisan command (CLI).
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
}
