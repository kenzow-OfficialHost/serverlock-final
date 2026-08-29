UNTUK VPS PTERO YANG UDAH DI INSTAL blueprint
->
->
->

cd /var/www

git clone https://github.com/kenzow-OfficialHost/serverlock-final.git

cd serverlock-final

chmod +x install.sh

./install.sh

## ServerLock Version Support

![ServerLock Version Support](docs/images/version-support.png)

## Cara Install Blueprint (Prasyarat sebelum install ServerLock)

ServerLock membutuhkan [Blueprint Framework](https://github.com/BlueprintFramework/framework) sudah terpasang di panel Pterodactyl kamu.

### 1. Set path Pterodactyl
````bash
export PTERODACTYL_DIRECTORY=/var/www/pterodactyl
````

### 2. Install dependency dasar

````bash
sudo apt update
sudo apt install -y curl wget unzip
````

### 3. Download & extract Blueprint

````bash
cd "$PTERODACTYL_DIRECTORY"
wget "https://github.com/BlueprintFramework/framework/releases/latest/download/release.zip" -O "$PTERODACTYL_DIRECTORY/release.zip"
unzip -o release.zip
````

### 4. Install Node.js, yarn, dan dependency lain

````bash
sudo apt install -y ca-certificates curl git gnupg unzip wget zip

sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_22.x nodistro main" | sudo tee /etc/apt/sources.list.d/nodesource.list
sudo apt update
sudo apt install -y nodejs

cd "$PTERODACTYL_DIRECTORY"
sudo npm i -g yarn
yarn install
````

### 5. Buat file `.blueprintrc`

````bash
echo \
'WEBUSER="www-data";
OWNERSHIP="www-data:www-data";
USERSHELL="/bin/bash";' > "$PTERODACTYL_DIRECTORY/.blueprintrc"
````

> Sesuaikan `WEBUSER`/`OWNERSHIP` kalau webserver kamu bukan pakai user `www-data` (mis. CentOS biasanya `nginx`).

### 6. Jalankan Blueprint installer

````bash
chmod +x "$PTERODACTYL_DIRECTORY/blueprint.sh"
sudo bash "$PTERODACTYL_DIRECTORY/blueprint.sh"
````

Verifikasi berhasil dengan:

````bash
blueprint -version
````

> ⚠️ **Backup dulu** folder panel + database sebelum menjalankan ini di server produksi. Referensi resmi: [blueprint.zip/guides/admin/install](https://blueprint.zip/guides/admin/install)
