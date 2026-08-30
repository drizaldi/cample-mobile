# Cample Mobile App (Flutter Frontend)

Aplikasi mobile untuk penyewaan peralatan camping (**Cample**). Dibangun menggunakan framework **Flutter**, aplikasi ini menyediakan antarmuka modern dan responsif baik untuk **Pelanggan (User)** maupun **Pengelola Toko (Admin)**.

🔗 **Backend Repository (Laravel REST API):** [https://github.com/drizaldi/cample-backend](https://github.com/drizaldi/cample-backend)

---

## Prasyarat Sistem
Sebelum menjalankan aplikasi, pastikan perangkat Anda telah memenuhi prasyarat berikut:
- **Flutter SDK** >= 3.x ([Panduan Install Flutter](https://docs.flutter.dev/get-started/install))
- **Dart SDK** (Otomatis terpasang bersama Flutter)
- **IDE**: Visual Studio Code / Android Studio
- **Device Pengujian**:
  - HP Android Fisik (dengan fitur *USB Debugging* aktif), atau
  - Emulator Android, atau
  - Browser Google Chrome *(untuk web testing)*
- **Backend Laravel** sudah berjalan (lihat dokumentasi di folder backend).

---

## Panduan Setup & Instalasi (Bagi Developer)

Ikuti langkah-langkah berikut setelah melakukan `git clone` repository ini:

### 1. Unduh Semua Dependencies
Buka terminal di dalam folder project ini, lalu jalankan:
```bash
flutter pub get
```

### 2. Konfigurasi Environment (`.env`)
Salin file template `.env.example` menjadi `.env`:
```bash
cp .env.example .env
```
*(Atau salin manual file `.env.example` lalu ubah namanya menjadi `.env`).*

Buka file `.env` dan sesuaikan URL API dengan kondisi jaringan Anda:

* **Opsi A (Satu Jaringan WiFi / Localhost):**
  Ganti dengan IP lokal laptop/komputer server backend Anda:
  ```env
  API_BASE_URL=http://192.168.1.xxx/backend_cample/public/api
  ```
* **Opsi B (Beda Jaringan / Menggunakan Ngrok):**
  Gunakan URL HTTPS publik dari Ngrok:
  ```env
  API_BASE_URL=https://your-subdomain.ngrok-free.app/backend_cample/public/api
  ```

---

## Cara Menjalankan Aplikasi

Pastikan server Backend Laravel sudah aktif, lalu jalankan salah satu perintah berikut:

### A. Menjalankan di Google Chrome (Web)
```bash
flutter run -d chrome --web-browser-flag "--disable-web-security"
```
*(Flag `--disable-web-security` digunakan untuk mencegah pemblokiran CORS saat mengakses API lokal).*

### B. Menjalankan di HP Fisik (Android via USB)
1. Colokkan HP ke laptop via kabel USB.
2. Pastikan HP terdeteksi:
   ```bash
   flutter devices
   ```
3. Jalankan aplikasi:
   ```bash
   flutter run
   ```

### C. Membuat File Installer APK (Android)
Untuk membuat file installer `.apk` yang bisa dibagikan ke HP lain:
```bash
flutter build apk --debug
```
File APK akan berada di folder: `build/app/outputs/flutter-apk/app-debug.apk`.

---

## Fitur Utama Aplikasi
- **Katalog & Sewa**: Eksplorasi peralatan camping, pilih varian, sistem keranjang, dan sewa multi-item.
- **Pembayaran DP (Midtrans)**: Integrasi Midtrans Snap untuk pembayaran uang muka (DP 50%) via Virtual Account / QRIS.
- **Manajemen Pesanan**: Pelacakan status pesanan real-time dari *Menunggu DP*, *Menunggu Konfirmasi*, *Siap Diambil*, *Disewa*, hingga *Selesai*.
- **Dashboard Admin**:
  - Manajemen Katalog & Varian Produk.
  - Manajemen Diskon & Banner Promo Toko.
  - Verifikasi Pengambilan Barang & Pelunasan Offline.
  - Form Pengembalian Barang (Kalkulasi Otomatis Denda Kerusakan & Denda Keterlambatan).
  - Laporan Keuangan & Cetak/Ekspor PDF Rekapitulasi Pendapatan.
