#!/usr/bin/env bash
set -Eeuo pipefail

PANEL="/var/www/pterodactyl"
REPO="https://github.com/kenzow-OfficialHost/serverlock-final.git"
TMP="/tmp/serverlock-final-install"
BACKUP="/root/serverlock-backup-$(date +%Y%m%d-%H%M%S)"

echo "=========================================="
echo "   SERVERLOCK FINAL AUTO INSTALLER"
echo "=========================================="

# ============================================================
# 1. ROOT
# ============================================================

if [[ $EUID -ne 0 ]]; then
    echo "ERROR: jalankan sebagai root."
    exit 1
fi

# ============================================================
# 2. CEK PTERODACTYL
# ============================================================

if [[ ! -d "$PANEL" ]]; then
    echo "ERROR: $PANEL tidak ditemukan."
    exit 1
fi

if [[ ! -f "$PANEL/artisan" ]]; then
    echo "ERROR: Pterodactyl tidak valid."
    exit 1
fi

echo "[OK] Pterodactyl ditemukan."

# ============================================================
# 3. CEK BLUEPRINT
# ============================================================

if ! command -v blueprint >/dev/null 2>&1; then
    echo "ERROR: Blueprint tidak ditemukan."
    exit 1
fi

echo "[OK] Blueprint ditemukan."
blueprint -version || true

# ============================================================
# 4. CLONE REPOSITORY
# ============================================================

echo
echo "[1/7] Clone ServerLock..."

rm -rf "$TMP"

git clone --depth 1 "$REPO" "$TMP"

echo "[OK] Repository berhasil di-clone."

# ============================================================
# 5. BACKUP FILE
# ============================================================

echo
echo "[2/7] Membuat backup..."

mkdir -p "$BACKUP"

backup_file() {
    local file="$1"

    if [[ -e "$PANEL/$file" || -L "$PANEL/$file" ]]; then
        mkdir -p "$BACKUP/$(dirname "$file")"
        cp -a "$PANEL/$file" "$BACKUP/$file"
    fi
}

backup_file "app/Console/Kernel.php"
backup_file "app/Providers/Blueprint/RouteServiceProvider.php"
backup_file "app/Http/Controllers/Extensions/Serverlock/LockController.php"
backup_file "app/Http/Controllers/Extensions/Serverlock/Concerns/ResolvesServer.php"
backup_file "app/Http/Controllers/Admin/Extensions/serverlock/serverlockExtensionController.php"
backup_file "database/migrations/2026_08_27_000000_create_ext_serverlock_locks_table.php"
backup_file "resources/scripts/routers/ServerRouter.tsx"
backup_file "resources/scripts/blueprint/extensions/LockGate.tsx"
backup_file "resources/scripts/blueprint/extensions/Components.yml"
backup_file "routes/blueprint/client/serverlock.php"

echo "[OK] Backup: $BACKUP"

# ============================================================
# 6. RESTORE RUNTIME
# ============================================================

echo
echo "[3/7] Memasang ServerLock runtime..."

cd "$PANEL"

cp -a "$TMP/source/runtime/app/." "$PANEL/app/"
cp -a "$TMP/source/runtime/database/." "$PANEL/database/"
cp -a "$TMP/source/runtime/resources/." "$PANEL/resources/"
cp -a "$TMP/source/runtime/routes/." "$PANEL/routes/"

echo "[OK] Runtime ServerLock dipasang."

# ============================================================
# 7. BLUEPRINT FILES
# ============================================================

echo
echo "[4/7] Memasang file Blueprint ServerLock..."

# Hanya salin file yang berasal dari package ServerLock.
# Tidak menimpa seluruh .blueprint agar extension lain
# seperti Crimson Abyss tidak ikut terhapus.

if [[ -d "$PANEL/.blueprint" ]]; then

    mkdir -p \
        "$PANEL/.blueprint/extensions/serverlock"

    cp -a \
        "$TMP/source/blueprint-extension/app" \
        "$PANEL/.blueprint/extensions/serverlock/" 2>/dev/null || true

    cp -a \
        "$TMP/source/blueprint-extension/components" \
        "$PANEL/.blueprint/extensions/serverlock/" 2>/dev/null || true

    cp -a \
        "$TMP/source/blueprint-extension/routers" \
        "$PANEL/.blueprint/extensions/serverlock/" 2>/dev/null || true

    cp -a \
        "$TMP/source/blueprint-extension/assets" \
        "$PANEL/.blueprint/extensions/serverlock/" 2>/dev/null || true

fi

echo "[OK] Blueprint ServerLock dipasang."

# ============================================================
# 8. DATABASE
# ============================================================

echo
echo "[5/7] Menjalankan migration..."

cd "$PANEL"

php artisan migrate --force

echo "[OK] Migration selesai."

# ============================================================
# 9. PERMISSION
# ============================================================

echo
echo "[6/7] Memperbaiki permission..."

chown -R www-data:www-data \
    "$PANEL/storage" \
    "$PANEL/bootstrap/cache"

chmod -R ug+rwX \
    "$PANEL/storage" \
    "$PANEL/bootstrap/cache"

echo "[OK] Permission selesai."

# ============================================================
# 10. CACHE
# ============================================================

php artisan optimize:clear

echo "[OK] Laravel cache dibersihkan."

# ============================================================
# 11. FRONTEND BUILD
# ============================================================

echo
echo "[7/7] Build frontend..."

cd "$PANEL"

if [[ ! -d node_modules ]]; then
    echo "node_modules belum ada."
    echo "Menjalankan yarn install..."

    yarn install --frozen-lockfile
fi

NODE_OPTIONS=--openssl-legacy-provider \
    yarn build:production

echo "[OK] Frontend build selesai."

# ============================================================
# 12. VALIDASI
# ============================================================

echo
echo "=========================================="
echo "        VALIDASI SERVERLOCK"
echo "=========================================="

echo
echo "--- Commands ---"

php artisan list | grep -E \
    'serverlock:(lock|status|unlock)' \
    || {
        echo "ERROR: command ServerLock tidak ditemukan."
        exit 1
    }

echo
echo "--- Routes ---"

php artisan route:list 2>/dev/null | grep serverlock \
    || {
        echo "ERROR: route ServerLock tidak ditemukan."
        exit 1
    }

echo
echo "--- Database ---"

php artisan tinker --execute='
try {
    $count = DB::table("ext_serverlock_locks")->count();
    echo "ext_serverlock_locks: OK".PHP_EOL;
    echo "Records: ".$count.PHP_EOL;
} catch (Throwable $e) {
    echo "ERROR DATABASE: ".$e->getMessage().PHP_EOL;
    exit(1);
}
'

echo
echo "=========================================="
echo " SERVERLOCK BERHASIL DIINSTALL"
echo "=========================================="
echo
echo "Backup:"
echo "$BACKUP"
echo
echo "Commands:"
echo "  php artisan serverlock:lock"
echo "  php artisan serverlock:status"
echo "  php artisan serverlock:unlock"
echo
echo "Reset password User ID:"
echo "  $TMP/scripts/serverlock-reset-user.sh USER_ID"
echo
echo "=========================================="
echo "             SELESAI"
echo "=========================================="
