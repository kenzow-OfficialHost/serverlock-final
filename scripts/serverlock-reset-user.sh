#!/usr/bin/env bash
set -euo pipefail

PANEL_DIR="/var/www/pterodactyl"

if [[ "${EUID}" -ne 0 ]]; then
    echo "ERROR: Jalankan sebagai root."
    exit 1
fi

if [[ ! -d "$PANEL_DIR" ]]; then
    echo "ERROR: $PANEL_DIR tidak ditemukan."
    exit 1
fi

if [[ $# -ne 1 || ! "$1" =~ ^[0-9]+$ ]]; then
    echo "Usage: $0 <PTERODACTYL_USER_ID>"
    exit 1
fi

USER_ID="$1"
cd "$PANEL_DIR"

read -rsp "Password baru ServerLock untuk User ID ${USER_ID}: " NEW_PASS
echo

if [[ -z "$NEW_PASS" ]]; then
    echo "ERROR: Password tidak boleh kosong."
    unset NEW_PASS
    exit 1
fi

export NEW_PASS USER_ID

php artisan tinker --execute='
$userId = (int) getenv("USER_ID");
$password = getenv("NEW_PASS");

$servers = DB::table("servers")
    ->where("owner_id", $userId)
    ->select("id", "uuid", "uuidShort", "name")
    ->get();

echo "User ID: ".$userId.PHP_EOL;
echo "Total server milik user: ".$servers->count().PHP_EOL.PHP_EOL;

if ($servers->isEmpty()) {
    echo "Tidak ada server untuk User ID tersebut.".PHP_EOL;
    exit;
}

$changed = 0;
$skipped = 0;
$failed = 0;

foreach ($servers as $server) {
    $lock = DB::table("ext_serverlock_locks")
        ->where("server_uuid", $server->uuid)
        ->first();

    if (!$lock || (int) $lock->enabled !== 1) {
        $skipped++;
        echo "[SKIP] ".$server->uuidShort." | ".$server->name." | ServerLock tidak aktif/tidak ada".PHP_EOL;
        continue;
    }

    DB::table("ext_serverlock_locks")
        ->where("server_uuid", $server->uuid)
        ->update([
            "password_hash" => Hash::make($password),
            "enabled" => 1,
            "updated_at" => now(),
        ]);

    $newHash = DB::table("ext_serverlock_locks")
        ->where("server_uuid", $server->uuid)
        ->value("password_hash");

    if (Hash::check($password, $newHash)) {
        $changed++;
        echo "[OK]   ".$server->uuidShort." | ".$server->name." | Password berhasil di-reset".PHP_EOL;
    } else {
        $failed++;
        echo "[FAIL] ".$server->uuidShort." | ".$server->name." | Hash::check gagal".PHP_EOL;
    }
}

echo PHP_EOL."===== HASIL =====".PHP_EOL;
echo "Diubah : ".$changed.PHP_EOL;
echo "Skip   : ".$skipped.PHP_EOL;
echo "Gagal  : ".$failed.PHP_EOL;

if ($failed > 0) {
    echo "HASIL: ADA YANG GAGAL".PHP_EOL;
    exit(2);
}

echo "HASIL: SEMUA YANG DIUBAH VALID".PHP_EOL;
'

unset NEW_PASS USER_ID
