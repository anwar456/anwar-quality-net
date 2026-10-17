# 03 — Keputusan Rilis v1.0.0

## Keputusan

**BLOCKED. Versi ini tidak boleh dirilis ke klien atau ke pengguna sungguhan.**

Statusnya tidak saya putuskan sendiri di berkas ini: ia dihitung oleh gate rilis pada tag, dan tertulis di halaman Release.

- Tag: `v1.0.0` pada commit `bc5ea22`
- Run gate rilis: https://github.com/anwar456/anwar-quality-net/actions/runs/39042831630 (merah = BLOCKED)
- Halaman Release: https://github.com/anwar456/anwar-quality-net/releases/tag/v1.0.0 (judul `v1.0.0 - BLOCKED`, ditandai pre-release)
- Apa yang diklaim dan tidak diklaim versi ini: `RELEASE_NOTES.md`

Seluruh jaring pengaman hijau pada versi ini. Statusnya tetap BLOCKED karena dua hal yang tidak bisa dibuktikan oleh tes.

## Apa yang diperiksa gate dan apa temuannya

| Gerbang | Hasil | Keterangan |
|---|---|---|
| Quality net (6 job CI) | **lolos** | kontrak API, jalur kritis, boot produksi, web, skrip gate + pemindaian, status gabungan |
| Risk register: P0/P1 yang diperbaiki | **gagal, 16 dari 17** | R-15 masih terbuka |
| Catatan rilis menyebut versi dan mengungkap risiko terbuka | lolos | R-15 diungkap di `RELEASE_NOTES.md` |
| Catatan verifikasi end-to-end wawancara suara untuk versi ini | **gagal** | `assessment/e2e-verification.md` tidak ada |

### Alasan 1: R-15 (P1) terbuka, tanpa penerimaan risiko
Tidak ada spesifikasi untuk **consent kandidat, retensi rekaman dan transkrip, dan persyaratan non-fungsional**, dan PRD asli tidak ada di repositori ini. Produk ini merekam suara orang dan menyimpan transkrip serta penilaian mereka. Tanpa keputusan tertulis soal persetujuan dan berapa lama data disimpan, risikonya bukan teknis, melainkan hukum dan kepercayaan kandidat. Itu keputusan pemilik produk. Insinyur yang mengaudit tidak berhak menerimanya atas nama perusahaan.

### Alasan 2: wawancara suara langsung belum terbukti berjalan
Yang diuji otomatis adalah logika (dengan socket dan koneksi model palsu) dan lapisan REST. Yang **belum pernah** dijalankan terhadap WebSocket sungguhan, mikrofon, dan Gemini Live:
- audio dari browser sampai ke model (dugaan frame biner di audit tetap belum terbukti maupun dicabut),
- penutupan koneksi saat assessor mengakhiri sesi (R-12 diperbaiki, tetapi hanya dibuktikan dengan socket palsu),
- `end_session` pada socket yang autentikasinya gagal.

Fungsi utama produk adalah wawancara suara. Menyatakan versi ini siap tanpa pernah menjalankannya sekali pun di jalur itu adalah menyembunyikan risiko di balik build hijau. Karena itu gate meminta catatan verifikasi manual untuk **versi yang persis sama**, dengan langkah di `assessment/e2e-checklist.md`.

## Rekomendasi

1. **Jangan rilis v1.0.0** ke klien atau pengguna sungguhan.
2. **Boleh** dipakai di lingkungan staging/internal untuk menjalankan pemeriksaan end-to-end.
3. Jalan menuju versi yang bisa dirilis (`v1.0.1`, karena catatan end-to-end harus menyebut versi yang sama):
   1. Jalankan `assessment/e2e-checklist.md` di staging dengan Gemini Live sungguhan; simpan hasilnya sebagai `assessment/e2e-verification.md` (`Version: v1.0.1`, `Result: pass`). Bila ada yang gagal, perbaiki dulu.
   2. R-15, salah satu: (a) pemilik produk menulis spesifikasi consent, retensi, dan NFR lalu perbaikannya dikerjakan; atau (b) pemilik produk mengisi `assessment/risk-acceptances.md` dengan **nama, tanggal kedaluwarsa, dan alasan**, untuk pilot terbatas, dan risikonya tetap diungkap di catatan rilis.
   3. Sebelum klien sungguhan: R-19 (peran tidak diperiksa di WebSocket) dan R-20 (token undangan tidak pernah kedaluwarsa) dari daftar P2, karena keduanya menyentuh akses ke data kandidat.
   4. Beri tag baru. Gate yang sama akan menjawab lagi, dari fakta yang berubah.

## Siapa pemilik risiko bila dirilis sekarang

**Tidak ada.** Tidak ada penerimaan risiko tercatat, dan saya tidak menerima risiko R-15 atas nama siapa pun. Bila organisasi tetap ingin merilis, penerimanya harus orang yang berwenang atas data kandidat (pemilik produk atau hukum/kepatuhan), bukan pembuat audit, dan harus menuliskannya di `assessment/risk-acceptances.md` dengan nama, batas waktu, dan alasan. Gate baru akan mengizinkan setelah itu, dan hanya selama belum kedaluwarsa.

## Risiko lain yang ikut terbawa (tidak memblokir, diungkap)

Semua tercatat di `assessment/01-audit.md` bagian 8. Yang paling relevan:
- **R-19, R-20**: akses WebSocket tidak memeriksa peran; token undangan tidak kedaluwarsa dan bisa dipakai bersamaan.
- **R-17, R-18**: batas waktu hanya diperiksa saat ada transkripsi; `end_reason` bisa salah label (kandidat yang menutup tab tercatat `error`).
- **R-21, R-22**: discovered skill yang menahan `all_covered`; regenerasi fit/gap meninggalkan jeda tanpa laporan.
- **R-06 (diterima)**: skill partial yang keluar dari jendela 6 turn analyzer tidak dievaluasi ulang, sehingga wawancara bisa berjalan sampai batas waktu.
- **R-11 (dimitigasi, belum tuntas)**: kehilangan transkrip kini terdeteksi sebelum menilai, tetapi jalur tulisnya masih hanya mencatat error ke log.
- **R-26**: Rails 7.0 dan Puma 5.6 sudah end-of-life; Dockerfile berjalan sebagai root; manifest tanpa `Secret`.

## Mengapa keputusan ini bisa dipercaya

- **Dihitung, bukan ditulis tangan.** `web/quality/release/gate.cjs` (10 tes) membaca matriks risiko, penerimaan risiko, catatan rilis, dan catatan end-to-end. P0 tidak pernah bisa diterima; "dimitigasi" bukan "diperbaiki"; penerimaan tanpa nama, tanpa alasan, atau kedaluwarsa tidak dihitung. Gate yang gagal menyelesaikan diri dianggap BLOCKED.
- **Bisa dipakai lagi.** Tidak ada yang spesifik untuk v1.0.0 di dalam gate. Rilis berikutnya cukup memberi tag baru.
- **Nilai tes hijau diuji pada dirinya sendiri.** Seluruh jaring (160+ pemeriksaan otomatis) hijau pada versi ini, tetapi itu hanya satu dari empat syarat. Jaring itu tidak bisa menjawab apakah audio sampai ke model.
- **Kesalahan saya sendiri di sepanjang jalan, yang saya catat bukan saya sembunyikan:** kesimpulan awal "tidak ada P0" salah (R-31 baru terlihat setelah aplikasi dijalankan); R-16 saya nilai P2 dari membaca kode, ternyata P1; satu bug di workflow saya membuat job boot produksi merah lama setelah perbaikan aslinya selesai; PR #2 saya sangka lolos gate padahal diblokir (lihat di bawah).

## Bukti proses dan tautan

| Hal | Tautan / hasil |
|---|---|
| Gate rilis | [run 39042831630](https://github.com/anwar456/anwar-quality-net/actions/runs/39042831630): BLOCKED, tag `v1.0.0` |
| Halaman Release | https://github.com/anwar456/anwar-quality-net/releases/tag/v1.0.0 |
| CI pada commit yang ditandai | [run 39042703461](https://github.com/anwar456/anwar-quality-net/actions/runs/39042703461): hijau |
| PR yang **diblokir** gate | [#1](https://github.com/anwar456/anwar-quality-net/pull/1): *Definition of Ready* merah (spec, acceptance criteria, rencana desain, dan tes tidak ada), dibiarkan terbuka |
| PR yang awalnya **diblokir tetapi ter-merge** | [#2](https://github.com/anwar456/anwar-quality-net/pull/2): deskripsi otomatis GitHub tidak memuat bagian wajib sehingga gate memblokir, tetapi ter-merge karena perlindungan `main` belum aktif. Temuan: **gate hanya mengunci bila branch protection aktif**; sesudahnya ruleset `protect-main` dipasang dan nama check yang diwajibkan dikoreksi |
| PR yang **lolos** gate | [#3](https://github.com/anwar456/anwar-quality-net/pull/3): semua 7 check hijau termasuk *Definition of Ready*, ter-merge dengan `f085f1b`. Isinya perbaikan nyata pada gate itu sendiri (`SPEC-010`) |

Catatan ruang lingkup: keputusan ini berlaku untuk keadaan pada commit `bc5ea22` (tag). PR #3 menambah perbaikan pada gate DoR sesudah tag; perubahan itu akan masuk ke versi berikutnya.
