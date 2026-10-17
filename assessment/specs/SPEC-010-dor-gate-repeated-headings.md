# SPEC-010 - Gate Definition of Ready membaca isi PR apa adanya

Temuan audit: tidak ada (ditemukan dengan memakai gate pada pull request sungguhan)
Status: diterima

## Masalah
GitHub mengisi pull request baru dengan pesan commit bila branch hanya punya satu commit, lalu menambahkan template
repositori di bawahnya. Gate memecah isi PR di setiap `## Judul` dan menyimpan kemunculan terakhir dari sebuah judul,
sehingga bagian template yang kosong di bawah bagian yang sudah diisi penulis menimpanya: sebuah PR yang membawa
semua input di pesan commit-nya akan dilaporkan tidak membawa apa pun. Ditemukan ketika memeriksa mengapa sebuah PR
sungguhan, yang dibuka dengan isi otomatis, diblokir. Pemblokiran itu benar (pesan commit-nya tidak punya bagian,
sehingga template tetap kosong), tetapi ia memperlihatkan bahwa sebuah judul bisa muncul dua kali dan salinan
terakhir yang menang.

## Aturan
1. Bila sebuah judul muncul lebih dari sekali, isi di bawah semua kemunculannya digabung, berurutan.
2. Kemunculan yang kosong atau placeholder karenanya tidak pernah menyembunyikan yang terisi, dan yang terisi tidak harus yang terakhir.
3. Isi PR yang setiap kemunculan judul wajibnya kosong atau placeholder tetap diblokir.

## Kriteria penerimaan
Given isi PR dengan Spec, Acceptance criteria, dan Design plan yang terisi, diikuti template kosong
When pemeriksaan Definition of Ready berjalan
Then ia lolos.

Given isi PR yang hanya berisi template kosong, dua kali
When pemeriksaan Definition of Ready berjalan
Then ia diblokir, dengan satu alasan untuk spec, satu untuk kriteria penerimaan, dan satu untuk rencana desain.

## Di luar cakupan
Menilai apakah spec atau rencananya bagus; gate hanya memeriksa bahwa keduanya ada dan bukan placeholder.

## Pemeriksa
web/quality/dor/check.test.cjs
