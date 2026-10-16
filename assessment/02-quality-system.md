# 02 — Sistem Kualitas (quality net)

Ringkas: dua bagian yang saling menutup. **Gate workflow** memastikan sebuah perubahan tidak bisa maju tanpa inputnya
(spec, acceptance criteria, rencana desain, tes). **Jaring tes/CI** memastikan perubahan yang sudah punya input tidak
merusak jalur kritis. Setiap check kecil, melindungi satu kelas kegagalan yang nyata, dan menyebut apa yang sengaja tidak
dicakupnya. Panduan menjalankan dan memperluas ada di `assessment/quality-net-README.md`.

## 1. Gate workflow: Definition of Ready / Done

| Bagian | Isi |
|---|---|
| Template PR | `.github/pull_request_template.md`: *Spec*, *Acceptance criteria*, *Design plan*, *Tests*, *Audit items* |
| Pemeriksa | `web/quality/dor/check.cjs` (fungsi murni, tanpa dependensi) dan pembungkusnya `run.cjs`; dijalankan oleh `.github/workflows/dor-gate.yml` pada `opened/edited/synchronize/reopened` |
| Spec di repo | `assessment/specs/SPEC-001..006` (enam spec, semuanya punya skenario Given/When/Then), templat `_template.md` |
| Keterlacakan | `assessment/traceability.md` + `web/quality/checks/traceability.cjs`: setiap P0/P1 di audit punya spec dan check, atau celah yang diungkap dengan alasan |

**Aturan yang memblokir** (pesan galatnya menyebut apa yang kurang):

1. *Spec* harus menaut ke berkas di repo yang ada dan bukan stub (≥ 200 karakter), atau ke URL. `TBD`, `N/A`, kosong, atau komentar template = ditolak.
2. *Acceptance criteria*: minimal satu skenario Given / When / Then, di PR atau di spec yang ditautkan.
3. *Design plan*: minimal 120 karakter, bukan placeholder.
4. **Perubahan di kode produksi** (`api/app|config|db|lib`, `web/src`, `web/public`) wajib menyentuh minimal satu berkas tes. Perubahan hanya dokumen/CI/skrip tidak butuh tes tetapi tetap butuh tiga input di atas.

Sengaja tidak memblokir (hanya catatan): PR `fix/feat` yang tidak menyebut ID temuan audit. Alasannya: gate yang menghukum
hal kecil cepat berubah menjadi birokrasi dan orang belajar mengisi asal.

Gate-nya sendiri dites: `web/quality/dor/check.test.cjs` (12 kasus: lolos, tanpa spec, spec tidak ada, spec stub, tanpa AC,
AC di spec, rencana placeholder, kode produksi tanpa tes, web tanpa tes, perubahan dokumen, template kosong).
Peragaan lokal: PR yang mengubah controller dengan template kosong ⇒ **BLOCKED** (4 alasan);
PR yang sama dengan spec, rencana, dan tes ⇒ **PASSED**. Dua PR sungguhan (satu diblokir, satu lolos) dibuat di repo GitHub
setelah repo publik tersedia, lihat bagian 5.

## 2. Jaring tes dan CI

`.github/workflows/ci.yml`, dijalankan di setiap push ke `main` dan setiap PR. Status tunggal **Quality gate** hanya hijau
bila semua job hijau.

| Job | Menjalankan | Melindungi (audit) |
|---|---|---|
| Gate scripts + scan | `node --test web/quality/` (28 tes), lint workflow, traceability, pemindaian identifier | gate itu sendiri; R-28; hilangnya temuan |
| API — critical path | `rspec --tag critical` (45 contoh) | R-01, R-02, R-04, R-05, R-06, R-07, R-09, R-10, R-11, R-12, R-13, R-31 |
| API — contract | `rspec --tag ~critical` (66 contoh) + dokumen OpenAPI tidak basi | bentuk 32 operasi API; R-03/R-08 sisi API |
| API boots in production mode | `rails zeitwerk:check` + boot dengan `RAILS_ENV=production` dan hanya gem produksi | R-31 |
| Web | cek token dev, build produksi dengan token harus **ditolak**, `tsc --noEmit`, `vitest` (12 tes), `vite build` | R-03, R-08, R-13, R-14 |

Pilihan desain yang perlu diketahui:

- **Tes jalur kritis berbeda dari tes kontrak.** Tes kontrak (rswag) mendokumentasikan perilaku API apa adanya dan menghasilkan `swagger.yaml`. Tes `critical` menuntut perilaku yang *benar* menurut spec, dan karena itu merah di kondisi sekarang. Regresi di jalur kritis tampil sebagai job bernama sendiri, tidak tercampur.
- **Tanpa API key apa pun.** Generator dan analyzer menerima klien LLM yang disuntikkan; tes memakai `FakeLlm`. CI deterministik dan gratis.
- **Kontrak web↔API dibaca dari satu sumber.** Tes web membangun bodi respons dari skema di `api/swagger/v1/swagger.yaml`, yang dijaga tetap jujur oleh tes API. Field yang diganti nama di satu sisi membuat satu sisi merah.
- **Eager load dipisah dari variabel `CI`.** Konfigurasi bawaan membuat *seluruh* suite gagal dimuat begitu `CI=true` (yang diset otomatis oleh GitHub), sehingga satu cacat boot menutupi semua hasil lain. `test.rb` sekarang memakai `EAGER_LOAD=true`, dan cacat boot dilaporkan oleh tes khusus (`boot_spec.rb`) dan job boot produksi. Ini bukan melemahkan check: cacatnya tetap merah, hanya tidak menutupi yang lain.
- **Daftar identifier terlarang disimpan sebagai hash SHA-256**, supaya daftar itu sendiri tidak menyebut nama yang dilarang. Pesan galat hanya menyebut nomor istilah dan berkas.
- **Dua check terakhir sengaja bukan tes unit:** `no-dev-token` membaca kode sumber karena yang dijaga adalah isi bundle produksi, bukan perilaku fungsi.

## 3. Kondisi dasar sebelum perbaikan (baseline merah)

Dijalankan lokal di Docker (Ruby 3.3.2, Postgres 16, Redis 7) dan Node 24, 16 Okt 2026.

| Check | Hasil | Alasan merah |
|---|---|---|
| API — kontrak | 59 / 59 hijau | — |
| API — critical path | **20 merah** dari 31 | R-01 ×5, R-02, R-04 ×2, R-05 ×5, R-06, R-07, R-09 ×2, R-10, R-11, R-31 (total 20) |
| API boots in production mode | **merah** | `config.active_job` tidak ada; `AudioWebsocketMiddleware` tidak ditemukan |
| Web — tes | **3 merah** dari 4 | R-03 (assessment, vacancy), R-08 |
| Web — typecheck, build | hijau | — |
| Cek token dev | **merah** (1) | `stores/authAtom.ts:10` |
| Pemindaian identifier | **merah** (53 temuan, 26 berkas) | R-28 |
| Skrip gate (23 tes unit), traceability | hijau | — |

Setiap merah dicek penyebabnya: tes gagal karena cacat yang dimaksud, bukan karena salah setup (satu kali tes mengganggu
akibat nama helper bertabrakan dengan method internal Rails, diperbaiki sebelum baseline ini diambil).

## 4. Apa yang tidak dilindungi (diungkap, bukan disembunyikan)

- **R-12**: assessor mengakhiri sesi tetapi stream audio kandidat tetap hidup. Butuh tes integrasi tingkat socket.
- **R-14**: CSP produksi vs host speed-test. Butuh pengecekan di browser.
- **R-13 (sebagian)**: tidak ada tes untuk jalur membuat assessor pertama.
- **WebSocket** secara umum (audio, monitor): tidak ada tes; R-19 dan kecurigaan frame biner belum terbukti.
- **Kualitas penilaian LLM**: tes memastikan rating *berasal dari* data kita dan divalidasi, bukan bahwa levelnya tepat.
- **Workflow GitHub Actions belum pernah berjalan di GitHub** (repo belum ada). Yang sudah dilakukan: YAML diparse, dan setiap perintah job diulang di Docker dengan variabel lingkungan yang sama. Run pertama di GitHub adalah verifikasi yang tersisa.

## 5. Bukti gate

Repo: https://github.com/anwar456/anwar-quality-net

- **Gate DoR** diperagakan dengan dua PR sungguhan (satu diblokir, satu lolos). Tautannya dicatat di `03-release-decision.md`.
- Gate-nya diuji sendiri (13 kasus untuk DoR, 4 untuk keterlacakan, 4 untuk pemindai identifier, 3 untuk token dev, 4 untuk lint workflow, ditambah kasus untuk gate itu sendiri sebagai kode produksi).

## 6. Red → green

Perbaikan R-31 sampai R-11 dimulai dari tes yang sudah merah (commit `9d50de5`, ditulis sebelum satu baris pun kode produksi diubah). Untuk R-14 dan R-16 tes ditulis bersamaan dengan perbaikannya, lalu dijalankan terhadap kode lama untuk membuktikan merah (3 dari 3 dan 500, dicatat di pesan commit). Tugas `users:create_admin` (R-13) adalah fitur baru: tesnya ditulis bersamaan dan tidak ada bukti merah-dulu. Tidak ada tes yang dilemahkan.
Satu-satunya perubahan pada tes yang sudah ada dirinci di pesan commit-nya: pemicu tes atomicity (confidence tidak lagi menjadi input, jadi pemicunya diganti dengan ringkasan kosong; asersinya sama) dan tes login (dibuat lebih kuat, bukan lebih lemah).

### Apa yang berubah, per commit

| Commit | Temuan | Merah sebelumnya | Yang diubah (akar masalah) | Hijau sekarang |
|---|---|---|---|---|
| `a04fb7a` | R-31 | `boot_spec`, `zeitwerk:check`, boot produksi | Konfigurasi ActiveJob yang mati dihapus; nama kelas WebSocket disamakan dengan nama file | boot dengan gem produksi; server produksi sungguhan menjawab health 200 |
| `a0bd664` | R-01, R-02 | 6 contoh `tenant_isolation_spec` | Portfolio dicari lewat sesi ber-tenant (gagal tertutup); `users.tenant_id`; token tanpa `scheme` ditolak | 9 contoh, termasuk 2 baru |
| `af849b9` | R-04, R-05, R-06, R-11 | 9 contoh (generator, fit/gap, coverage) | Validasi penuh sebelum menulis, identitas dan confidence dari data kita, satu transaksi, promosi otomatis dihapus | 13 contoh generator (5 baru), 5 fit/gap, 4 coverage |
| `726346e` | R-07, R-09, R-10 | 4 contoh `session_lifecycle_spec` | `audio_complete` hanya mengonfirmasi fakta; delete menjawab 409; `WEB_BASE_URL` dengan pengaman boot | 6 contoh; kontrak diperbarui |
| `d01873a` | R-03, R-08, R-13 | 3 tes web | `withDestroyed` di dua halaman edit; tipe dan tabel mengikuti kontrak; build produksi menolak token dev | 9 tes web |
| `315fa9e` | R-28 | pemindai: 50 baris di 26 berkas | Placeholder netral, tanpa mengubah logika | bersih |
| `63d6b95` | (CI) | job Boot di GitHub | Perintah terpotong komentar YAML; lint ditambahkan | semua job |
| `085f552` | R-13, R-14 | 3 tes web (kode lama meloloskan cek saat server error) | `users:create_admin`; cek mengukur ke API sendiri dan gagal tertutup | 3 tes web, 3 contoh API (speed test), 3 contoh rake |
| `876a4a5` | R-16 | spec PDF: 500 | Teks disaring ke Windows-1252 sebelum digambar | 200 |

### Run CI di GitHub

Run bertanda ✔ hijau, ✘ merah. Isi kolom kedua adalah job yang merah.

| Run | Commit | Hasil | Job merah |
|---|---|---|---|
| [38851526425](https://github.com/anwar456/anwar-quality-net/actions/runs/38851526425) | `a5a458f` | ✘ | critical path, boot produksi, scripts+scan, web |
| [38859953259](https://github.com/anwar456/anwar-quality-net/actions/runs/38859953259) | `a04fb7a` (R-31) | ✘ | keempatnya masih merah |
| [38860690598](https://github.com/anwar456/anwar-quality-net/actions/runs/38860690598) | `a0bd664` (R-01, R-02) | ✘ | keempatnya |
| [38861552805](https://github.com/anwar456/anwar-quality-net/actions/runs/38861552805) | `af849b9` (R-04..R-11) | ✘ | keempatnya |
| [38862304946](https://github.com/anwar456/anwar-quality-net/actions/runs/38862304946) | `726346e` (R-07, R-09, R-10) | ✘ | **critical path berubah hijau**; sisa: scripts+scan, web, boot |
| [38864366358](https://github.com/anwar456/anwar-quality-net/actions/runs/38864366358) | `315fa9e` (R-28) | ✘ | hanya boot produksi |
| [38864637294](https://github.com/anwar456/anwar-quality-net/actions/runs/38864637294) | `63d6b95` | ✔ | — |
| [38865512049](https://github.com/anwar456/anwar-quality-net/actions/runs/38865512049) | `085f552` | ✔ | — |
| [38866561912](https://github.com/anwar456/anwar-quality-net/actions/runs/38866561912) | `876a4a5` | ✔ | — |

Dua catatan jujur tentang tabel itu:

1. Job *boot produksi* tetap merah sampai `63d6b95`, **padahal R-31 sudah diperbaiki di `a04fb7a`** dan diverifikasi lokal (server produksi sungguhan dijalankan). Penyebabnya bug saya di workflow: satu perintah terpotong komentar YAML sehingga job itu gagal untuk alasan lain. Itu baru terlihat setelah job lain hijau. Pelajarannya sudah dijadikan check (lint workflow) dan dicatat di audit.
2. Job *tes kontrak API* hijau di setiap run, termasuk yang pertama: kontrak mendokumentasikan perilaku asli sejak awal, dan tetap hijau ketika perilaku diperbaiki karena dokumennya diregenerasi dari spec yang sama.

### Yang masih merah atau tersisa, dengan sengaja

Lihat `01-audit.md` bagian 8. R-12 (stream audio tidak berhenti saat assessor mengakhiri sesi) diperbaiki belakangan, dengan tes terhadap socket palsu: logika middleware terbukti, tetapi **belum diuji lewat WebSocket dan Gemini Live sungguhan**. R-15 dimitigasi, bukan tuntas. Keduanya diungkap di `traceability.md` dan di keputusan rilis.
