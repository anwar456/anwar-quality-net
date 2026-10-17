# SPEC-006 - Layanan bisa start di produksi dan tidak membawa rahasia atau identitas pihak lain

Temuan audit: R-31, R-13, R-28
Status: diterima

## Masalah
Boot dengan setelan produksi gagal dua kali (sebuah konstanta yang namanya tidak cocok dengan nama berkasnya, dan
sebuah pemanggilan konfigurasi untuk komponen yang tidak dimuat). Token login bisa ikut terkompilasi ke bundle web.
Repositori menyebut nama organisasi pemilik latihan ini, host-nya, dan registry-nya.

## Aturan
1. `rails zeitwerk:check` lolos dan aplikasi boot dengan `RAILS_ENV=production` dan hanya grup gem produksi.
2. Bundle web produksi tidak memuat `VITE_DEV_TOKEN`: kode hanya membacanya di balik `import.meta.env.DEV`, dan karena Vite menerbitkan setiap variabel `VITE_*` dari lingkungan build (sebuah library menarik seluruh `import.meta.env`), build produksi itu sendiri menolak berjalan selama variabel itu terisi.
3. Tidak ada berkas atau path ter-track yang memuat identifier dari daftar terlarang (disimpan sebagai hash di web/quality/scan/forbidden-terms.sha256).
4. Instalasi baru bisa membuat assessor pertamanya dengan `rails users:create_admin EMAIL=.. PASSWORD=.. SCHEME=..`: admin terikat ke organisasi, password minimal 12 karakter, menjalankannya dua kali memperbarui pengguna yang sama, dan input yang salah tidak membuat apa pun.

## Kriteria penerimaan
Given grup gem produksi dan setelan produksi
When aplikasi dimuat penuh (eager load)
Then ia boot tanpa error.

Given build produksi aplikasi web
When kode sumber diperiksa
Then tidak ada pembacaan VITE_DEV_TOKEN tanpa penjaga.

Given VITE_DEV_TOKEN terisi di lingkungan sebuah build produksi
When build dijalankan
Then ia berhenti dengan error dan tidak menerbitkan apa pun.

Given instalasi baru dengan satu organisasi dan tanpa pengguna
When operator menjalankan tugas create-admin
Then admin bisa login dan token membawa scheme organisasi itu.

Given berkas-berkas ter-track di repositori
When pemindaian kerahasiaan berjalan
Then ia tidak melaporkan identifier terlarang.

## Di luar cakupan
Pengelolaan rahasia pada deployment sungguhan (Kubernetes Secrets dimiliki tim platform).

## Pemeriksa
api/spec/critical/boot_spec.rb, api/spec/tasks/create_admin_task_spec.rb, job CI "API boots in production mode", web/quality/checks/no-dev-token.cjs, web/quality/scan/identifiers.cjs
