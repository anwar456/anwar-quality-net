# SPEC-003 - Coverage berarti ada bukti; sesi berakhir karena alasan yang tercatat dan benar

Temuan audit: R-06, R-09, R-12
Status: diterima

## Masalah
Skill partial dinaikkan menjadi "covered" begitu probe_count mencapai 4 tanpa pemeriksaan bukti apa pun, dan endpoint
publik `audio_complete` mengakhiri sesi apa pun, termasuk yang belum pernah dimulai, dan mencatatnya sebagai
`all_covered`. Saat assessor mengakhiri sesi, hanya baris database yang berubah: koneksi suara kandidat tetap hidup.

## Aturan
1. Sebuah skill menjadi covered hanya lewat keputusan analyzer, tunduk pada state machine (hanya maju, dua probe sebelum meninggalkan "initiated"). Tidak ada job yang menaikkan skill hanya dengan menghitung probe.
   Konsekuensi yang diketahui dan diterima: skill partial yang keluar dari jendela 6 turn analyzer tidak dievaluasi ulang, sehingga wawancara bisa berjalan sampai batas waktunya alih-alih berakhir lebih awal. Tindak lanjut: beri analyzer lebih banyak konteks untuk skill partial.
2. `POST /sessions/:token/audio_complete` mengakhiri sesi hanya bila sesi aktif dan setiap skill terkonfigurasi covered; selain itu jawabannya 409 dan tidak ada yang berubah. Mengakhiri sesi yang sudah berakhir tetap idempoten (200).
   Celah yang diketahui: ketika socket langsung menutup wawancara sendiri (AI berpamitan lebih awal), ia tetap mengakhiri sesi sendiri setelah polling 30 detik dan mencatat `all_covered`. Label itu bisa salah (R-18 di audit, tindak lanjut).
3. `end_reason` menyatakan apa yang sebenarnya terjadi.
4. Ketika sesi diakhiri oleh pihak selain koneksi langsung itu sendiri (assessor, sebuah job), koneksi langsung ikut berakhir dalam beberapa detik: browser diberi tahu (`session_ended` dengan alasan yang tercatat) dan koneksi browser serta koneksi model ditutup. Pemberitahuan hanya dikirim sekali. Koneksi memeriksa baris database setiap 3 detik, di luar thread event loop.

## Kriteria penerimaan
Given sebuah skill partial dengan 5 probe
When job analyzer coverage berjalan dan melaporkan tidak ada perubahan
Then skill itu tetap partial.

Given sebuah sesi yang belum pernah dimulai
When endpoint kandidat audio_complete dipanggil dengan tokennya
Then jawabannya 409, sesi tetap pending, dan tidak ada portfolio.

Given sebuah sesi aktif dengan satu skill terkonfigurasi yang masih terbuka
When audio_complete dipanggil
Then jawabannya 409 dan sesi tetap aktif.

Given sebuah sesi aktif yang semua skill terkonfigurasinya covered
When audio_complete dipanggil
Then sesi diakhiri dengan alasan all_covered.

Given seorang kandidat yang terhubung ke wawancara yang sedang berjalan
When seorang assessor mengakhiri sesi
Then koneksi kandidat menerima session_ended dengan alasan dari assessor, koneksi model ditutup, dan koneksi browser ditutup.

Given middleware sendiri yang mengakhiri sesi (misalnya pada batas waktu)
When kemudian ia melihat baris sudah berstatus ended
Then ia tidak mengumumkan akhir sesi untuk kedua kalinya.

## Di luar cakupan
Menjalankan WebSocket dan koneksi model yang sungguhan: R-12 diverifikasi dengan socket palsu (logika middleware itu sendiri), bukan end-to-end.

## Pemeriksa
api/spec/critical/coverage_spec.rb, api/spec/critical/session_lifecycle_spec.rb, api/spec/critical/live_session_spec.rb
