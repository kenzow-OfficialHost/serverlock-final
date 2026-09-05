#!/usr/bin/env bash
#
# ==========================================================
#   SERVERLOCK — FULL UNINSTALLER (v3, theme-agnostic)
# ==========================================================
#
# Berbeda dari versi sebelumnya: script ini TIDAK bergantung pada
# folder backup (/root/serverlock-backup-*), karena backup itu bisa
# saja sudah "kotor" kalau ServerLock pernah di-install ulang
# beberapa kali sebelumnya.
#
# Sebagai gantinya, script ini mencabut SECARA SPESIFIK setiap
# baris/blok yang ditambahkan ServerLock ke file inti panel,
# berdasarkan marker/komentar yang mereka taruh sendiri di source:
#   - app/Console/Kernel.php        -> komentar "ServerLock Blueprint extension commands"
#   - app/Providers/Blueprint/RouteServiceProvider.php -> komentar "ServerLock routes."
#   - resources/scripts/**/*.tsx    -> import & wrapper <LockGate>...</LockGate>
#
# Aman dijalankan berkali-kali (idempotent): kalau sebuah bagian
# sudah bersih, script cuma bilang "sudah bersih" dan lanjut.
#
# Tidak peduli tema apapun yang dipakai di atas panel (Stellar,
# default Pterodactyl, dll) karena script ini hanya mencari &
# menghapus baris yang match pola ServerLock, bukan menimpa file
# secara keseluruhan.
#
set -Eeuo pipefail

PANEL="${PANEL:-/var/www/pterodactyl}"
LOG_PREFIX="[serverlock-uninstall]"

log()  { echo "$LOG_PREFIX $*"; }
warn() { echo "$LOG_PREFIX [WARN] $*"; }
ok()   { echo "$LOG_PREFIX [OK] $*"; }

echo "=========================================================="
echo "   SERVERLOCK — FULL UNINSTALLER (v3)"
echo "=========================================================="

# ------------------------------------------------------------
# 0. VALIDASI
# ------------------------------------------------------------

if [[ $EUID -ne 0 ]]; then
    echo "ERROR: jalankan sebagai root (sudo -i lalu jalankan lagi)."
    exit 1
fi

if [[ ! -d "$PANEL" || ! -f "$PANEL/artisan" ]]; then
    echo "ERROR: Panel Pterodactyl tidak ditemukan di '$PANEL'."
    echo "       Kalau lokasi panel kamu beda, jalankan dengan:"
    echo "         PANEL=/lokasi/panel/kamu ./uninstall-serverlock.sh"
    exit 1
fi

cd "$PANEL"
log "Panel ditemukan di $PANEL"

REGFILE="$PANEL/.blueprint/extensions/blueprint/private/db/installed_extensions"

# ------------------------------------------------------------
# 1. UNLOCK SEMUA SERVER (best effort, sebelum tabel dihapus)
# ------------------------------------------------------------

log "[1/10] Mengecek status lock server (kalau command masih ada)..."
if php artisan list 2>/dev/null | grep -q 'serverlock:status'; then
    php artisan serverlock:status || true
    echo
    read -r -p "Ada server yang masih TERKUNCI di atas? Pastikan sudah aman lalu ketik y untuk lanjut uninstall (y/n): " CONFIRM
    if [[ "${CONFIRM:-n}" != "y" ]]; then
        echo "Dibatalkan oleh user."
        exit 0
    fi
else
    log "Command serverlock:status tidak ada (mungkin sudah pernah diuninstall sebagian), lanjut."
fi

# ------------------------------------------------------------
# 2. ROLLBACK MIGRATION DATABASE
# ------------------------------------------------------------

log "[2/10] Rollback migration database..."
MIGRATION_FILE=$(find "$PANEL/database/migrations" -maxdepth 1 -iname "*create_ext_serverlock_locks_table*" 2>/dev/null | head -n1 || true)
if [[ -n "$MIGRATION_FILE" ]]; then
    php artisan migrate:rollback --path="${MIGRATION_FILE#$PANEL/}" --force || \
        warn "Rollback migration gagal (mungkin tabel sudah tidak ada), lanjut."
    rm -f "$MIGRATION_FILE"
    ok "Migration file dihapus."
else
    log "Tidak ada file migration ServerLock ditemukan, dilewati."
fi

# ------------------------------------------------------------
# 3. HAPUS DARI REGISTRY BLUEPRINT
# ------------------------------------------------------------

log "[3/10] Membersihkan registry Blueprint..."
if [[ -f "$REGFILE" ]]; then
    sed -i 's/|serverlock,//g' "$REGFILE"
    ok "Registry dibersihkan."
else
    warn "Registry file tidak ditemukan di $REGFILE, dilewati."
fi

# ------------------------------------------------------------
# 4. HAPUS FOLDER-FOLDER MILIK SERVERLOCK
# ------------------------------------------------------------

log "[4/10] Menghapus folder-folder ServerLock..."

FOLDERS_TO_REMOVE=(
    "$PANEL/.blueprint/extensions/serverlock"
    "$PANEL/app/Console/Commands/Serverlock"
    "$PANEL/app/Http/Controllers/Extensions/Serverlock"
    "$PANEL/app/Http/Controllers/Admin/Extensions/serverlock"
    "$PANEL/app/BlueprintFramework/Extensions/serverlock"
    "$PANEL/resources/scripts/blueprint/extensions/serverlock"
)

for f in "${FOLDERS_TO_REMOVE[@]}"; do
    if [[ -e "$f" ]]; then
        rm -rf "$f"
        ok "Dihapus: $f"
    fi
done

# File route spesifik
if [[ -f "$PANEL/routes/blueprint/client/serverlock.php" ]]; then
    rm -f "$PANEL/routes/blueprint/client/serverlock.php"
    ok "Dihapus: routes/blueprint/client/serverlock.php"
fi

# ------------------------------------------------------------
# 5. BERSIHKAN app/Console/Kernel.php (hapus 2 baris ServerLock)
# ------------------------------------------------------------

log "[5/10] Membersihkan app/Console/Kernel.php..."
KERNEL="$PANEL/app/Console/Kernel.php"
if [[ -f "$KERNEL" ]] && grep -q "ServerLock Blueprint extension commands" "$KERNEL"; then
    cp -a "$KERNEL" "$KERNEL.bak-serverlock-uninstall"
    # Hapus baris komentar + baris load() yang mengikutinya
    sed -i '/ServerLock Blueprint extension commands/,+1d' "$KERNEL"
    ok "Kernel.php dibersihkan (backup: Kernel.php.bak-serverlock-uninstall)."
else
    log "Kernel.php sudah bersih / tidak ada jejak ServerLock."
fi

# ------------------------------------------------------------
# 6. BERSIHKAN RouteServiceProvider.php (hapus blok rute ServerLock)
# ------------------------------------------------------------

log "[6/10] Membersihkan RouteServiceProvider.php..."
RSP="$PANEL/app/Providers/Blueprint/RouteServiceProvider.php"
if [[ -f "$RSP" ]] && grep -q "ServerLock routes\." "$RSP"; then
    cp -a "$RSP" "$RSP.bak-serverlock-uninstall"
    # Hapus blok dari komentar "/*" sebelum "ServerLock routes."
    # sampai statement Route::...group(...serverlock.php...); yang mengakhirinya.
    perl -0pi -e 's{/\*\s*\n\s*\* ServerLock routes\..*?group\(base_path\(.routes/blueprint/client/serverlock\.php.\)\);\s*\n}{}s' "$RSP"
    ok "RouteServiceProvider.php dibersihkan (backup: RouteServiceProvider.php.bak-serverlock-uninstall)."
    if grep -q "ServerLock routes\." "$RSP"; then
        warn "Masih ada sisa teks 'ServerLock routes.' di RouteServiceProvider.php, cek manual."
    fi
else
    log "RouteServiceProvider.php sudah bersih / tidak ada jejak ServerLock."
fi

# ------------------------------------------------------------
# 7. BERSIHKAN SISA IMPORT & WRAPPER LockGate DI FRONTEND
#    (theme-agnostic: cari di SELURUH resources/scripts,
#     bukan cuma path default Pterodactyl)
# ------------------------------------------------------------

log "[7/10] Mencari & membersihkan sisa referensi LockGate di frontend..."

MATCHES=$(grep -rl "LockGate" "$PANEL/resources/scripts" 2>/dev/null || true)

if [[ -n "$MATCHES" ]]; then
    while IFS= read -r file; do
        cp -a "$file" "$file.bak-serverlock-uninstall"
        # Hapus baris import LockGate (apapun sumbernya)
        sed -i '/^import LockGate from/d' "$file"
        # Hapus baris pembuka <LockGate ...> (children di dalamnya dibiarkan)
        sed -i '/<LockGate[ >]/d' "$file"
        # Hapus baris penutup </LockGate>
        sed -i '/<\/LockGate>/d' "$file"
        ok "Dibersihkan: $file (backup: $file.bak-serverlock-uninstall)"
    done <<< "$MATCHES"
else
    log "Tidak ada file frontend yang mengandung 'LockGate'."
fi

# ------------------------------------------------------------
# 8. VALIDASI SISA REFERENSI (informational, tidak menghentikan)
# ------------------------------------------------------------

log "[8/10] Scan akhir untuk sisa referensi 'serverlock' (case-insensitive)..."
REMAINING=$(grep -rli "serverlock" "$PANEL/app" "$PANEL/routes" "$PANEL/resources/scripts" "$PANEL/database/migrations" 2>/dev/null | grep -v '\.bak-serverlock-uninstall$' || true)

if [[ -n "$REMAINING" ]]; then
    warn "Masih ada file yang menyebut 'serverlock', cek manual:"
    echo "$REMAINING" | sed 's/^/    - /'
else
    ok "Tidak ada sisa referensi 'serverlock' di app/routes/resources/database."
fi

# ------------------------------------------------------------
# 9. TEST ARTISAN, BERSIHKAN CACHE, BUILD ULANG FRONTEND
# ------------------------------------------------------------

log "[9/10] Test php artisan..."
if ! php artisan list > /dev/null 2>/tmp/serverlock-artisan-error.log; then
    echo
    echo "ERROR: php artisan masih gagal setelah pembersihan. Detail:"
    cat /tmp/serverlock-artisan-error.log
    echo
    echo "Perbaiki dulu error di atas secara manual sebelum lanjut build frontend."
    exit 1
fi
ok "php artisan berjalan normal."

log "Membersihkan cache Laravel..."
php artisan optimize:clear

log "Build ulang frontend (yarn build:production)..."
if [[ ! -d "$PANEL/node_modules" ]]; then
    yarn install
fi
NODE_OPTIONS=--openssl-legacy-provider yarn build:production

# ------------------------------------------------------------
# 10. PERMISSION
# ------------------------------------------------------------

log "[10/10] Memperbaiki permission..."
chown -R www-data:www-data "$PANEL/storage" "$PANEL/bootstrap/cache"
chmod -R ug+rwX "$PANEL/storage" "$PANEL/bootstrap/cache"

echo
echo "=========================================================="
echo " SERVERLOCK BERHASIL DI-UNINSTALL SECARA UTUH"
echo "=========================================================="
echo
echo "Cek ulang:"
echo "  1. Buka /admin/extensions -> kartu 'Server Lock' harus hilang."
echo "  2. Buka console salah satu server -> harus normal, tanpa error."
echo "  3. File *.bak-serverlock-uninstall yang tersisa aman dihapus"
echo "     manual kalau semua sudah dipastikan normal."
