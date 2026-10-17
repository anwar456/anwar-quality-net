# SPEC-004 - Yang ditampilkan form adalah yang tersimpan

Temuan audit: R-03, R-10
Status: diterima

## Masalah
Menghapus sebuah skill dari form edit assessment atau vacancy hanya menghapusnya dari layar: API menghapus record
bersarang hanya ketika menerima `{ id, _destroy: true }`, yang tidak pernah dikirim web. Menghapus assessment yang
sudah punya kandidat dijawab "deleted" padahal model menolaknya.

## Aturan
1. Ketika pengguna menghapus skill yang sudah ada di form edit, payload yang dikirim memuat `{ id, _destroy: true }` untuk skill itu, dan hanya untuk skill itu.
2. Menghapus record yang ditolak oleh model dijawab 409 beserta alasannya, dan record tetap ada.
3. Kontrak API untuk atribut bersarang didokumentasikan di berkas OpenAPI dan diperiksa oleh spec API.

## Kriteria penerimaan
Given sebuah assessment dengan dua skill yang terbuka di form edit
When pengguna menghapus skill pertama dan menyimpan
Then request update memuat id skill pertama dengan `_destroy: true` dan tidak menghancurkan skill kedua.

Given sebuah vacancy dengan dua skill yang diharapkan terbuka di form edit
When pengguna menghapus yang pertama dan menyimpan
Then request update menghancurkannya, sehingga fit/gap tidak lagi membandingkan dengannya.

Given sebuah assessment yang sudah punya sesi kandidat
When seorang admin menghapusnya
Then jawabannya 409 dan assessment itu masih ada.

## Di luar cakupan
Dialog konfirmasi atau soft-delete; keduanya keputusan produk.

## Pemeriksa
web/src/pages/assessments/AssessmentEditPage.test.tsx, web/src/pages/vacancies/VacancyEditPage.test.tsx, api/spec/critical/session_lifecycle_spec.rb
