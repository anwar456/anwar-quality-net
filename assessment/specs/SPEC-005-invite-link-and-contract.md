# SPEC-005 - Tautan undangan membuka wawancara; web dan API sepakat soal nama field

Temuan audit: R-07, R-08
Status: diterima

## Masalah
URL undangan dibangun dari URL dasar API, padahal halaman wawancara dilayani oleh aplikasi web, sehingga setiap
tautan yang diterima kandidat mati. Tabel fit/gap membaca `required_level` sedangkan API mengirim `expected_level`,
sehingga level yang dibutuhkan kosong di setiap baris.

## Aturan
1. URL undangan adalah `WEB_BASE_URL + /interview/:token`. `WEB_BASE_URL` adalah pengaturan terpisah dari `APP_BASE_URL` (origin API). Di produksi aplikasi menolak boot bila nilainya kosong, bukan URL http(s), atau sama origin dengan `APP_BASE_URL`.
2. Dokumen OpenAPI (`api/swagger/v1/swagger.yaml`) dihasilkan dari spec request dan menjadi kontrak antara kedua layanan; CI gagal bila dokumen itu basi.
3. Komponen web yang menampilkan respons API diuji dengan bodi yang dihasilkan dari kontrak itu, bukan dengan fixture tulis tangan.

## Kriteria penerimaan
Given WEB_BASE_URL dan APP_BASE_URL adalah origin yang berbeda
When seorang assessor mengundang kandidat
Then URL undangan diawali dengan WEB_BASE_URL.

Given sebuah baris fit/gap dengan level yang dibutuhkan 4 dan level kandidat 2
When tabel perbandingan ditampilkan
Then L4 dan L2 keduanya terlihat.

## Di luar cakupan
Versi API; menghasilkan tipe TypeScript dari kontrak (langkah berikutnya yang masuk akal).

## Pemeriksa
api/spec/critical/session_lifecycle_spec.rb, web/src/components/fitgap/ComparisonTable.contract.test.tsx, langkah CI "OpenAPI document is up to date"
