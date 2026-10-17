# SPEC-007 - Cek perangkat kandidat mengukur API kita dan gagal tertutup

Temuan audit: R-14
Status: diterima

## Masalah
Sebelum wawancara dimulai, browser kandidat mengukur ping, download, dan upload. Pengukuran itu memanggil host
pihak ketiga (sebuah mesin pencari, dua CDN, dua layanan echo), yang diblokir oleh Content-Security-Policy produksi,
sehingga pada konfigurasi produksi bawaan setiap kandidat gagal di cek ini dan tidak bisa memulai. Saat sebuah
pengukuran gagal, kode juga mengganti hasilnya dengan angka yang tampak wajar: nilai cadangan upload (0,5 MB/s =
4 Mbps) sama dengan batas minimum, sehingga server yang tidak terjangkau tetap bisa lolos.

## Aturan
1. Ping, download, dan upload diukur terhadap API yang dipakai audio wawancara (`/health`, `GET /speed_test`, `POST /speed_test`). Setiap URL bisa ditimpa lewat konfigurasi. Tidak ada request ke host yang tidak diizinkan CSP.
2. Pengukuran yang tidak bisa dilakukan (error jaringan, jawaban non-2xx) dihitung gagal: download 0, upload 0, ping 999. Tidak pernah ada nilai cadangan yang dikarang.
3. `GET /speed_test?bytes=N` mengembalikan N byte nol, bawaan 500 000, dibatasi 2 000 000, tanpa login, dan dibatasi 30 request per menit per IP.

## Kriteria penerimaan
Given URL dasar API adalah https://api.example.test/api/v1
When cek perangkat berjalan
Then setiap request menuju origin itu dan tidak ada request ke host lain.

Given browser tidak bisa menjangkau API (diblokir atau offline)
When cek perangkat berjalan
Then hasilnya tidak lolos, dengan download 0 dan upload 0.

Given API menjawab speed test dengan status error
When cek perangkat berjalan
Then hasilnya tidak lolos.

Given sebuah request untuk 999 999 999 byte
When sink download menjawab
Then ia mengembalikan tepat 2 000 000 byte.

## Di luar cakupan
Mengukur kualitas mikrofon atau kamera kandidat; mengubah kecepatan minimum.

## Pemeriksa
web/src/utils/internetSpeedTest.test.ts, api/spec/requests/api/v1/auth_spec.rb (operasi speed_test)
