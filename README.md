# WhatsApp Proxy Auto Installer

Skrip ini menginstal **WhatsApp Official Proxy** pada Ubuntu atau Debian menggunakan image Docker resmi `facebook/whatsapp_proxy:latest` dan membuka endpoint TCP **443**.

> Proxy WhatsApp ini ditujukan untuk koneksi chat. VoIP tidak didukung oleh implementasi resmi saat ini.

## Instalasi cepat

Jalankan sebagai `root` atau gunakan `sudo`:

```bash
curl -fsSL https://raw.githubusercontent.com/OWNER/REPOSITORY/main/install-whatsapp-proxy.sh -o install-whatsapp-proxy.sh
sudo bash install-whatsapp-proxy.sh
```

Saat diminta, masukkan domain/subdomain yang mengarah ke IP server. Jika tidak memakai domain, tekan Enter dan skrip akan menggunakan IP publik server.

Skrip juga meminta PIN instalasi:

```text
027005
```

PIN diperlukan sebelum proses instalasi dimulai dan dibatasi tiga percobaan.

> **Penting:** PIN yang ditanam langsung di dalam skrip bukan pengamanan kriptografis. Siapa pun yang dapat membaca file skrip dapat melihat PIN tersebut. Gunakan repository privat dan batasi akses server bila PIN ini harus dirahasiakan.

## Yang dilakukan skrip

- Mendukung Ubuntu dan Debian berbasis `systemd`.
- Menginstal Docker Engine bila belum tersedia.
- Mengambil image resmi `facebook/whatsapp_proxy:latest`.
- Menjalankan container dengan restart otomatis.
- Memetakan hanya `TCP 443:443` ke publik sesuai permintaan.
- Mengaktifkan UFW dan mengizinkan SSH serta TCP 443.
- Menyediakan perintah status, log, dan restart melalui Docker.

## Perintah pengelolaan

```bash
sudo docker ps --filter name=whatsapp-proxy
sudo docker logs -f whatsapp-proxy
sudo docker restart whatsapp-proxy
sudo docker stop whatsapp-proxy
sudo docker rm -f whatsapp-proxy
```

Untuk menghapus data konfigurasi lokal:

```bash
sudo rm -rf /opt/whatsapp-proxy
```

## Catatan port

Port 443 digunakan sebagai endpoint utama sesuai permintaan. Dokumentasi resmi WhatsApp merekomendasikan port 443 dan 587 untuk fungsi dasar chat dan media pada endpoint publik. Karena installer ini sengaja hanya membuka 443, sebagian fungsi media dapat tidak tersedia pada jaringan tertentu.

Pastikan:

1. IP publik server dapat menerima koneksi masuk TCP 443.
2. Jika memakai domain, DNS A/AAAA mengarah ke server.
3. Provider VPS atau firewall jaringan tidak memblokir port 443.
4. Jangan menaruh kredensial, token, atau kunci pribadi di repository.

## Troubleshooting

Periksa status container:

```bash
sudo docker ps -a --filter name=whatsapp-proxy
sudo docker logs --tail=200 whatsapp-proxy
sudo ss -lntp | grep ':443'
```

Jika port 443 sudah dipakai Nginx, Apache, atau layanan lain, hentikan layanan tersebut atau pilih server yang port 443-nya kosong.

## Sumber resmi

- [WhatsApp Proxy di GitHub](https://github.com/WhatsApp/proxy)
- [WhatsApp Help Center: How to set up a proxy server](https://faq.whatsapp.com/1299035810920553)

## Lisensi

Skrip installer ini dirilis di bawah MIT License. WhatsApp Proxy dan image Docker tetap mengikuti lisensi dan ketentuan pemiliknya.
