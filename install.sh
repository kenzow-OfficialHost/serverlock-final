#!/usr/bin/env bash
#
# ==========================================
#   SERVERLOCK FINAL — AUTO INSTALLER v2
# ==========================================
#
# Versi ini adalah hasil rombak total setelah proses debugging penuh:
# menutup semua celah yang bikin instalasi versi lama gagal / setengah jalan.
#
# Perbaikan dibanding versi lama:
#   1. Menyalin folder `private/` (termasuk conf.yml) ke .blueprint/extensions/serverlock
#      -> tanpa ini, Blueprint TIDAK akan pernah tahu extension ini punya versi/info.
#   2. Mendaftarkan "serverlock" ke registry
#      .blueprint/extensions/blueprint/private/db/installed_extensions
#      -> INI KUNCI UTAMA supaya ServerLock muncul di /admin/extensions.
#      Tanpa baris ini, extension bisa jalan di backend tapi TIDAK PERNAH
#      muncul di halaman admin, walau semua file lain sudah benar.
#   3. Menaruh LockGate.tsx di resources/scripts/blueprint/extensions/serverlock/
#      -> webpack.config.js BAWAAN Blueprint sudah punya alias generic:
#         '@blueprint': path.join(__dirname, '/resources/scripts/blueprint')
#         Jadi import '@blueprint/extensions/serverlock/LockGate' otomatis
#         nyambung ke file ini TANPA perlu hack/sed webpack.config.js sama
#         sekali. (Versi installer sebelumnya salah taruh di
#         .blueprint/extensions/serverlock/components/ yang TIDAK pernah
#         dibaca webpack sama sekali -> selalu berujung error
#         "Module not found: Can't resolve '@blueprint/extensions/serverlock/LockGate'")
#   4. Menyalin admin/index.blade.php (halaman detail extension di admin panel).
#   5. Idempotent: aman dijalankan berkali-kali (tidak dobel-append registry).
#
set -Eeuo pipefail

PANEL="/var/www/pterodactyl"
REPO="https://github.com/kenzow-OfficialHost/serverlock-final.git"
TMP="/tmp/serverlock-final-install"
BACKUP="/root/serverlock-backup-$(date +%Y%m%d-%H%M%S)"

echo "=========================================="
echo "   SERVERLOCK FINAL AUTO INSTALLER v2"
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
    echo "Install Blueprint dulu (lihat README.md bagian 1) sebelum lanjut."
    exit 1
fi

echo "[OK] Blueprint ditemukan."
blueprint -version || true

REGFILE="$PANEL/.blueprint/extensions/blueprint/private/db/installed_extensions"

if [[ ! -f "$REGFILE" ]]; then
    echo "ERROR: registry Blueprint ($REGFILE) tidak ditemukan."
    echo "Instalasi Blueprint kamu kemungkinan rusak/tidak lengkap."
    exit 1
fi

# ============================================================
# 4. CLONE REPOSITORY
# ============================================================

echo
echo "[1/10] Clone ServerLock..."

rm -rf "$TMP"
git clone --depth 1 "$REPO" "$TMP"

echo "[OK] Repository berhasil di-clone."

# ============================================================
# 5. BACKUP FILE
# ============================================================

echo
echo "[2/10] Membuat backup..."

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
backup_file "database/migrations/2026_08_27_000000_create_ext_serverlock_locks_table.php"
backup_file "resources/scripts/routers/ServerRouter.tsx"
backup_file "resources/scripts/blueprint/extensions/serverlock/LockGate.tsx"
backup_file "routes/blueprint/client/serverlock.php"
backup_file ".blueprint/extensions/blueprint/private/db/installed_extensions"

echo "[OK] Backup: $BACKUP"

# ============================================================
# 6. RUNTIME (app/, database/, resources/, routes/)
# ============================================================

echo
echo "[3/10] Memasang ServerLock runtime..."

cd "$PANEL"

cp -a "$TMP/source/runtime/app/." "$PANEL/app/"
cp -a "$TMP/source/runtime/database/." "$PANEL/database/"
cp -a "$TMP/source/runtime/resources/." "$PANEL/resources/"
cp -a "$TMP/source/runtime/routes/." "$PANEL/routes/"

echo "[OK] Runtime ServerLock dipasang."

# ============================================================
# 7. FOLDER EXTENSION BLUEPRINT (LENGKAP — termasuk private/)
# ============================================================

echo
echo "[4/10] Memasang folder extension .blueprint/extensions/serverlock..."

# Hanya salin isi folder milik ServerLock sendiri. Tidak menimpa
# seluruh .blueprint/extensions agar extension lain (mis. Crimson Abyss)
# tidak ikut terganggu/terhapus.

mkdir -p "$PANEL/.blueprint/extensions/serverlock"

cp -a "$TMP/source/blueprint-extension/app"        "$PANEL/.blueprint/extensions/serverlock/" 2>/dev/null || true
cp -a "$TMP/source/blueprint-extension/components"  "$PANEL/.blueprint/extensions/serverlock/" 2>/dev/null || true
cp -a "$TMP/source/blueprint-extension/routers"     "$PANEL/.blueprint/extensions/serverlock/" 2>/dev/null || true
cp -a "$TMP/source/blueprint-extension/assets"      "$PANEL/.blueprint/extensions/serverlock/" 2>/dev/null || true

# --- FIX #1: private/ (isinya conf.yml) WAJIB ikut disalin. ---
# Blueprint membaca versi & info extension dari:
#   .blueprint/extensions/serverlock/private/.store/conf.yml
# Tanpa ini extensionConfig() akan selalu null.
cp -a "$TMP/source/blueprint-extension/private" "$PANEL/.blueprint/extensions/serverlock/" 2>/dev/null || true

# --- Admin view (halaman detail extension di admin panel) ---
mkdir -p "$PANEL/.blueprint/extensions/serverlock/admin"
if [[ -f "$TMP/source/blueprint-dev/admin/index.blade.php" ]]; then
    cp -a "$TMP/source/blueprint-dev/admin/index.blade.php" \
        "$PANEL/.blueprint/extensions/serverlock/admin/index.blade.php"
fi

echo "[OK] Folder extension ServerLock dipasang lengkap."

# ============================================================
# 8. FIX #2 — DAFTARKAN KE REGISTRY BLUEPRINT (WAJIB!)
# ============================================================

echo
echo "[5/10] Mendaftarkan ServerLock ke registry Blueprint..."

# Blueprint menentukan "extension apa saja yang terinstall" BUKAN dengan
# scan folder, tapi dengan baca 1 file teks ini:
#   .blueprint/extensions/blueprint/private/db/installed_extensions
# Formatnya: |nama1,|nama2,|nama3,
#
# Tanpa baris di bawah ini, ServerLock TIDAK AKAN PERNAH muncul di
# halaman /admin/extensions walaupun semua file lain sudah lengkap.

if grep -q "serverlock" "$REGFILE" 2>/dev/null; then
    echo "[OK] 'serverlock' sudah terdaftar di registry, dilewati."
else
    printf '|serverlock,' >> "$REGFILE"
    echo "[OK] 'serverlock' berhasil ditambahkan ke registry."
fi

chown www-data:www-data "$REGFILE"

# ============================================================
# 9. FIX #3 — TARUH LockGate.tsx DI LOKASI YANG BENAR-BENAR DIBACA WEBPACK
# ============================================================

echo
echo "[6/10] Memasang komponen frontend LockGate ke lokasi yang benar..."

# PENTING: ServerRouter.tsx meng-import lewat:
#   import LockGate from '@blueprint/extensions/serverlock/LockGate';
#
# webpack.config.js BAWAAN Blueprint sudah punya alias generic:
#   '@blueprint': path.join(__dirname, '/resources/scripts/blueprint')
#
# Jadi file HARUS ada di:
#   resources/scripts/blueprint/extensions/serverlock/LockGate.tsx
#
# BUKAN di .blueprint/extensions/serverlock/components/ (folder itu cuma
# dipakai Blueprint buat metadata/registrasi extension, bukan dibaca webpack).

mkdir -p "$PANEL/resources/scripts/blueprint/extensions/serverlock"

cp -a "$TMP/source/blueprint-extension/components/LockGate.tsx" \
    "$PANEL/resources/scripts/blueprint/extensions/serverlock/LockGate.tsx"

echo "[OK] LockGate.tsx dipasang di resources/scripts/blueprint/extensions/serverlock/"

# ============================================================
# 10. PERMISSION
# ============================================================

echo
echo "[7/10] Memperbaiki permission..."

chown -R www-data:www-data \
    "$PANEL/.blueprint/extensions/serverlock" \
    "$PANEL/resources/scripts/blueprint/extensions/serverlock" \
    "$PANEL/storage" \
    "$PANEL/bootstrap/cache"

chmod -R ug+rwX \
    "$PANEL/storage" \
    "$PANEL/bootstrap/cache"

echo "[OK] Permission selesai."

# ============================================================
# 11. DATABASE
# ============================================================

echo
echo "[8/10] Menjalankan migration..."

cd "$PANEL"
php artisan migrate --force

echo "[OK] Migration selesai."

# ============================================================
# 12. CACHE
# ============================================================

echo
echo "[9/10] Membersihkan cache..."

php artisan optimize:clear

echo "[OK] Laravel cache dibersihkan."

# ============================================================
# 13. FRONTEND BUILD
# ============================================================

echo
echo "[10/10] Build frontend..."

cd "$PANEL"

if [[ ! -d node_modules ]]; then
    echo "node_modules belum ada, menjalankan yarn install..."
    yarn install --frozen-lockfile
fi

NODE_OPTIONS=--openssl-legacy-provider yarn build:production

echo "[OK] Frontend build selesai."

# ============================================================
# 14. VALIDASI
# ============================================================

echo
echo "=========================================="
echo "        VALIDASI SERVERLOCK"
echo "=========================================="

echo
echo "--- Commands ---"
php artisan list | grep -E 'serverlock:(lock|status|unlock)' || {
    echo "ERROR: command ServerLock tidak ditemukan."
    exit 1
}

echo
echo "--- Routes ---"
php artisan route:list 2>/dev/null | grep serverlock || {
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
echo "--- Registry Blueprint ---"
cat "$REGFILE"; echo

echo
echo "=========================================="
echo " SERVERLOCK BERHASIL DIINSTALL"
echo "=========================================="
echo
echo "Cek di browser: https://domain-panel-kamu/admin/extensions"
echo "Kartu 'Server Lock' harus sudah muncul di situ."
echo
echo "Backup perubahan tersimpan di:"
echo "$BACKUP"
echo
echo "Cara pakai:"
echo "  php artisan serverlock:lock {server}     # kunci server (id/uuid/uuidShort)"
echo "  php artisan serverlock:status [server]   # lihat status (kosongkan utk lihat semua)"
echo "  php artisan serverlock:unlock {server}   # buka kunci server"
echo
echo "Reset password user tertentu:"
echo "  $TMP/scripts/serverlock-reset-user.sh USER_ID"
echo
echo "=========================================="
echo "             SELESAI"
echo "=========================================="
