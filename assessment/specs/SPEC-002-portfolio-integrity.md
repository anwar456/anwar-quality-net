# SPEC-002 - Rating berasal dari wawancara dan data kita sendiri

Temuan audit: R-04, R-05, R-11
Status: diterima

## Masalah
Generator portfolio menyimpan apa pun id skill, label, level, dan confidence yang dikembalikan LLM. Level yang
hilang diam-diam menjadi L1, confidence tidak dihitung dengan aturan di PRD 01, hasil sebagian tetap tersimpan bila
skill berikutnya tidak valid, wawancara tanpa transkrip tetap dinilai, dan fit/gap gagal mencocokkan skill yang id
tersimpannya berbeda huruf besar/kecil dari yang dikonfigurasi.

## Aturan
1. Identitas (id dan label skill) dari rating sebuah skill terkonfigurasi disalin dari skill terkonfigurasi pada assessment yang dirujuk jawaban LLM; teks LLM hanya dipakai untuk menemukan skill itu (id dibandingkan tanpa peduli huruf besar/kecil dan spasi).
2. `level` harus bilangan bulat 1..5. Selain itu seluruh generasi gagal; tidak pernah dipotong (clamp) atau diberi nilai bawaan.
3. `confidence` dihitung: high = covered dan probe_count >= 3; medium = probe_count 2 atau partial; low = probe_count <= 1 atau initiated. Confidence dari LLM diabaikan.
4. Generasi bersifat semua-atau-tidak-sama-sekali: bila ada satu skill tidak valid, tidak ada skill portfolio yang tersimpan dan portfolio ditandai gagal beserta alasannya.
5. Wawancara tanpa transkrip, atau yang nomor turn-nya bolong, tidak dinilai; portfolio ditandai gagal ("transcript incomplete").
6. Fit/gap mencocokkan sebuah kebutuhan dengan skill yang dinilai lewat id yang dinormalisasi lebih dulu, lalu lewat label tanpa peduli huruf besar/kecil.
7. Setiap skill terkonfigurasi harus dinilai tepat satu kali, setiap rating harus mengutip minimal satu bukti dan membawa ringkasan; penilaian skill yang tidak dikonfigurasi, atau yang terlewat, menggagalkan seluruh generasi. Level boleh ditulis `3` atau `L3`, tidak yang lain.
8. Transkrip harus memuat minimal satu turn kandidat.

## Kriteria penerimaan
Given wawancara selesai dengan transkrip lengkap dan peta coverage
When LLM menjawab dengan huruf besar/kecil id atau label yang berbeda untuk sebuah skill terkonfigurasi
Then skill portfolio yang tersimpan memakai id dan label yang dikonfigurasi.

Given jawaban LLM dengan level yang hilang, nol, atau di luar rentang
When portfolio digenerasi
Then generasi gagal, portfolio berstatus gagal, dan tidak ada skill yang tersimpan.

Given sebuah skill yang partial dengan 2 probe
When LLM menyebut confidence-nya high
Then confidence yang tersimpan adalah medium.

Given wawancara yang transkripnya kosong atau turn-nya bolong
When portfolio digenerasi
Then portfolio ditandai gagal dan tidak ada yang tersimpan.

## Di luar cakupan
Apakah level dari LLM adalah penilaian yang baik; kebijakan retry job.

## Pemeriksa
api/spec/critical/portfolio_generation_spec.rb, api/spec/critical/fit_gap_spec.rb
