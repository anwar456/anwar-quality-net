# 02 — Sistem Kualitas (quality net)

Ringkas: dua bagian yang saling menutup. **Gate workflow** memastikan sebuah perubahan tidak bisa maju tanpa inputnya
(spec, acceptance criteria, rencana desain, tes). **Jaring tes/CI** memastikan perubahan yang sudah punya input tidak
merusak jalur kritis. Setiap check kecil, melindungi satu kelas kegagalan yang nyata, dan menyebut apa yang sengaja tidak
dicakupnya. Panduan menjalankan dan memperluas ada di `quality/README.md`.

## 1. Gate workflow: Definition of Ready / Done

| Bagian | Isi |
|---|---|
| Template PR | `.github/pull_request_template.md`: *Spec*, *Acceptance criteria*, *Design plan*, *Tests*, *Audit items* |
| Pemeriksa | `quality/dor/check.js` (fungsi murni, tanpa dependensi) dan pembungkusnya `run.js`; dijalankan oleh `.github/workflows/dor-gate.yml` pada `opened/edited/synchronize/reopened` |
| Spec di repo | `docs/specs/SPEC-001..006` (enam spec, semuanya punya skenario Given/When/Then), templat `_template.md` |
| Keterlacakan | `docs/traceability.md` + `quality/checks/traceability.js`: setiap P0/P1 di audit punya spec dan check, atau celah yang diungkap dengan alasan |

**Aturan yang memblokir** (pesan galatnya menyebut apa yang kurang):

1. *Spec* harus menaut ke berkas di repo yang ada dan bukan stub (≥ 200 karakter), atau ke URL. `TBD`, `N/A`, kosong, atau komentar template = ditolak.
2. *Acceptance criteria*: minimal satu skenario Given / When / Then, di PR atau di spec yang ditautkan.
3. *Design plan*: minimal 120 karakter, bukan placeholder.
4. **Perubahan di kode produksi** (`api/app|config|db|lib`, `web/src`, `web/public`) wajib menyentuh minimal satu berkas tes. Perubahan hanya dokumen/CI/skrip tidak butuh tes tetapi tetap butuh tiga input di atas.

Sengaja tidak memblokir (hanya catatan): PR `fix/feat` yang tidak menyebut ID temuan audit. Alasannya: gate yang menghukum
hal kecil cepat berubah menjadi birokrasi dan orang belajar mengisi asal.

Gate-nya sendiri dites: `quality/dor/check.test.js` (12 kasus: lolos, tanpa spec, spec tidak ada, spec stub, tanpa AC,
AC di spec, rencana placeholder, kode produksi tanpa tes, web tanpa tes, perubahan dokumen, template kosong).
Peragaan lokal: PR yang mengubah controller dengan template kosong ⇒ **BLOCKED** (4 alasan);
PR yang sama dengan spec, rencana, dan tes ⇒ **PASSED**. Dua PR sungguhan (satu diblokir, satu lolos) dibuat di repo GitHub
setelah repo publik tersedia, lihat bagian 5.

## 2. Jaring tes dan CI

`.github/workflows/ci.yml`, dijalankan di setiap push ke `main` dan setiap PR. Status tunggal **Quality gate** hanya hijau
bila semua job hijau.

| Job | Menjalankan | Melindungi (audit) |
|---|---|---|
| Gate scripts + scan | `node --test quality/`, traceability, pemindaian identifier | gate itu sendiri; R-28; hilangnya temuan |
| API — critical path | `rspec --tag critical` (31 contoh) | R-01, R-02, R-04, R-05, R-06, R-07, R-09, R-10, R-11, R-31 |
| API — contract | `rspec --tag ~critical` (59 contoh) + dokumen OpenAPI tidak basi | bentuk 32 operasi API; R-03/R-08 sisi API |
| API boots in production mode | `rails zeitwerk:check` + boot dengan `RAILS_ENV=production` dan hanya gem produksi | R-31 |
| Web | `tsc --noEmit`, `vitest`, cek token dev, `vite build` | R-03, R-08, R-13 |

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

## 5. Bukti gate dan red → green

- **PR yang diblokir dan PR yang lolos:** dibuat setelah repo publik ada; tautan dicatat di `03-release-decision.md`.
- **Catatan red → green** (apa yang merah, apa yang diubah, apa yang hijau sekarang): bagian *6* di bawah, diisi pada tugas 3 dengan rujukan commit.

## 6. Red → green

Diisi pada tugas 3.
