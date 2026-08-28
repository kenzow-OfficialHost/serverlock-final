# Server Lock — Blueprint Extension

Nambahin gerbang password di halaman console tiap server Pterodactyl.

**Model kerjanya sekarang:** lock/unlock/generate password **cuma bisa dari
VPS lewat SSH** (artisan command). Tidak ada endpoint web/API buat set atau
matiin password. Kalau sebuah server belum pernah di-`lock` lewat command,
dia default **tidak terkunci**. Password selalu digenerate otomatis oleh
sistem, bukan diketik manual oleh siapa pun.

## ⚠️ Baca dulu sebelum pasang

1. **Ini scaffold, bukan extension jadi yang 100% siap pakai tanpa cek.**
   Saya belum bisa build & test langsung di panelmu, jadi mungkin ada
   penyesuaian kecil (nama area di `Components.yml`, target Blueprint) —
   sudah ditandai `TODO` di tiap file.

2. **Ini gerbang di level tampilan (UI), bukan blokir data di backend.**
   Overlay password nutupin layar sebelum password benar dimasukin, tapi
   data console/statistik server tetap kepanggil di background oleh
   komponen native Pterodactyl. Cukup buat mencegah orang lain buka dari
   dashboard/layarmu — bukan proteksi kelas keamanan yang nahan orang yang
   ngerti DevTools/API langsung ke endpoint native Pterodactyl (bukan
   endpoint extension ini).

3. **Node lain tidak tersentuh.** Extension ini cuma nambah 1 tabel baru
   (`ext_serverlock_locks`), 1 controller kecil (cuma 2 endpoint: status &
   verify), dan 3 command artisan baru (`serverlock:lock/unlock/status`).
   Tidak ada file inti Pterodactyl yang ditimpa/diedit — jadi server/node
   lain yang sudah jalan tidak diutak-atik.

## Cara pakai (semua dari SSH di VPS panel, di dalam `/var/www/pterodactyl`)

Kunci sebuah server (password digenerate otomatis, ditampilkan sekali):

```bash
php artisan serverlock:lock afee3ff4
```

Contoh output:

```
Server 'KENVPS8GB' (uuidShort: afee3ff4) berhasil dikunci.
Password (catat sekarang, tidak akan ditampilkan lagi):

  Xk9mQrT2sN

Hash-nya sudah tersimpan di tabel ext_serverlock_locks. Plaintext di atas tidak disimpan di mana pun.
```

Buka lock (tanpa perlu tahu password lama):

```bash
php artisan serverlock:unlock afee3ff4
```

Cek status satu server, atau semua server yang pernah diset:

```bash
php artisan serverlock:status afee3ff4
php artisan serverlock:status
```

`{server}` boleh diisi `uuidShort` (yang muncul di URL `/server/xxxxx`,
lihat contoh di screenshot-mu: `afee3ff4`), uuid penuh, atau ID numerik.

Kalau lupa/kehilangan password yang sudah digenerate, tinggal `serverlock:lock`
lagi untuk server yang sama — password lama otomatis diganti dengan yang baru.

## Cara install & build (jalankan sekali di awal)

1. Upload folder `serverlock/` ini ke server panel (SCP/SFTP), taruh di:
   `/var/www/pterodactyl/.blueprint/dev/serverlock`
   (script `deploy.sh` di bawah sudah otomatisin ini)
2. SSH ke VPS panel, masuk ke direktori Pterodactyl:
   ```bash
   cd /var/www/pterodactyl
   ```
3. Cek versi Blueprint kamu dan samakan nilai `target` di `conf.yml`:
   ```bash
   blueprint -version
   ```
4. Build extension-nya:
   ```bash
   blueprint -build
   ```
5. Kalau nggak ada error, coba `php artisan serverlock:lock <uuidShort>`
   lalu buka server itu di dashboard → harusnya muncul overlay password.
6. Kalau sudah oke dan mau dijadiin file installer permanen:
   ```bash
   blueprint -export
   ```

## Struktur

```
serverlock/
├── conf.yml                                          # manifest extension
├── database/migrations/                              # tabel ext_serverlock_locks
├── app/
│   ├── Http/Controllers/Extensions/Serverlock/
│   │   ├── LockController.php                        # HANYA status & verify
│   │   └── Concerns/ResolvesServer.php                # helper cari server + generate password
│   └── Console/Commands/Serverlock/
│       ├── LockServerCommand.php                      # serverlock:lock
│       ├── UnlockServerCommand.php                     # serverlock:unlock
│       └── ServerlockStatusCommand.php                 # serverlock:status
├── routes/client.php                                  # cuma /status & /verify
└── components/
    ├── Components.yml                                 # penempatan komponen React
    └── LockGate.tsx                                    # overlay password
```

Kalau pas `blueprint -build` ada error, screenshot-in aja errornya, saya bantu perbaiki.
