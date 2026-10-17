# SPEC-008 - Portfolio yang sudah di-review selalu bisa diekspor

Temuan audit: R-16
Status: diterima

## Masalah
Ekspor PDF menggambar teks dengan font bawaan Prawn, yang hanya bisa menggambar karakter Windows-1252 dan melempar
error untuk karakter lain. Baris yang ditampilkan untuk override assessor memuat sebuah panah, dan kutipan kandidat
adalah teks bebas (simbol, aksara lain, emoji). Akibatnya ekspor menjawab 500 untuk setiap portfolio yang sudah
di-review assessor (ada override), dan untuk kutipan apa pun di luar Windows-1252, sehingga hanya ekspor JSON yang tersisa.

## Aturan
1. Ekspor PDF tidak pernah gagal karena teks yang dimuatnya. Karakter yang tidak bisa digambar font PDF diganti dengan `?`.
2. Ekspor JSON adalah yang tanpa kehilangan: ia mempertahankan teks aslinya.
3. Baris override berbunyi "AI: L3, assessor override: L4" (tanpa simbol di luar font).

## Kriteria penerimaan
Given sebuah portfolio selesai dengan override assessor
When assessor mengekspornya sebagai PDF
Then jawabannya 200 dan bodinya adalah PDF.

Given sebuah kutipan kandidat yang memuat simbol, aksara CJK, dan emoji
When assessor mengekspor portfolio sebagai PDF
Then jawabannya 200, karakter yang tidak didukung muncul sebagai `?`, dan ekspor JSON tetap memuat kutipan aslinya.

## Di luar cakupan
Menyematkan font Unicode agar aksara lain digambar alih-alih diganti (langkah berikutnya yang masuk akal).

## Pemeriksa
api/spec/requests/api/v1/portfolios_spec.rb ("PDF export of a portfolio with an assessor override and text the PDF font cannot draw")
