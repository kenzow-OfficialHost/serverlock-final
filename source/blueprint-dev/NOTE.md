Folder ini dulu punya salinan app/, database/, components/, routes/ yang
persis sama kayak di `source/blueprint-extension/` dan `source/runtime/` --
tapi `install.sh` cuma pernah baca SATU file dari sini:

    admin/index.blade.php

Salinan lain di folder ini nggak pernah dipakai instalasi manapun, jadi
cuma bikin bingung file mana yang "asli" kalau ada perubahan (sempat ada
3 salinan LockController.php yang beda2 versi). Makanya dihapus.

Kalau butuh source of truth buat app/PHP & database/migrations, lihat:
- `source/runtime/` -> yang beneran dipasang installer ke panel
- `source/blueprint-extension/` -> salinan buat metadata Blueprint
  (`.blueprint/extensions/serverlock/`), harus disinkronin manual tiap
  ada perubahan di runtime/.
