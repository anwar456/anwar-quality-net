# SPEC-009 - Kode sebuah skill ditampilkan sekali, apa adanya

Temuan audit: tidak ada (ditemukan saat memakai aplikasi; P3 kosmetik yang sekaligus menjadi peragaan gate PR)
Status: diterima

## Masalah
Kartu skill menampilkan kode pendek di samping nama skill. Skill taksonomi sudah membawa id seperti `SK-ENG-001`,
tetapi kartu mem-padding apa pun yang diterimanya lalu menambahkan awalan `SK-` lagi, sehingga layar menampilkan
`SK-SK-ENG-001`. Kartu itu ditulis ketika id skill masih berupa angka.

## Aturan
1. Id taksonomi (string yang sudah diawali huruf) ditampilkan persis seperti tersimpan.
2. Id numerik (angka, atau string berisi digit, seperti pada data lama) ditampilkan sebagai `SK-` diikuti angka yang di-padding menjadi tiga digit.
3. Id yang hilang tidak menampilkan apa pun. Skill custom menampilkan "Custom" (tidak berubah).

## Kriteria penerimaan
Given sebuah skill dari taksonomi dengan id SK-ENG-001
When kartunya ditampilkan
Then kodenya terbaca SK-ENG-001, bukan SK-SK-ENG-001.

Given sebuah skill lama yang id-nya angka 7
When kartunya ditampilkan
Then kodenya terbaca SK-007.

Given sebuah skill tanpa id
When kartunya ditampilkan
Then tidak ada kode yang ditampilkan.

## Di luar cakupan
Mengganti nama id, atau mengubah cara skill custom diberi label.

## Pemeriksa
web/src/lib/skillCode.test.ts
