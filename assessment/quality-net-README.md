# Quality net

Jaring pengaman kecil dengan dua bagian: **gate workflow** (perubahan tidak boleh maju tanpa inputnya) dan **jaring tes/CI**
(perubahan tidak boleh maju bila merusak jalur kritis). Setiap check melindungi satu kelas kegagalan yang nyata.
Daftar risiko dan alasannya ada di `assessment/01-audit.md`; penjelasan lengkap di `assessment/02-quality-system.md`.

## Peta

| Check | Di mana | Melindungi | Sengaja tidak mencakup |
|---|---|---|---|
| Definition of Ready | `web/quality/dor/`, `.github/workflows/dor-gate.yml`, `.github/pull_request_template.md` | PR tanpa spec, acceptance criteria (Given/When/Then), rencana desain, atau tes | Kualitas isi spec; hanya memastikan ada dan bukan placeholder |
| Keterlacakan | `web/quality/checks/traceability.cjs`, `assessment/traceability.md` | Temuan P0/P1 tidak bisa hilang diam-diam dari daftar | Temuan P2/P3 |
| Jalur kritis API | `api/spec/critical/` (tag `critical`) | Isolasi tenant, integritas rating, siklus hidup sesi, boot | Perilaku WebSocket/audio langsung (R-12) |
| Kontrak API | `api/spec/requests/`, `api/swagger/v1/swagger.yaml` | Bentuk respons tiap endpoint; dokumen OpenAPI tidak basi | Performa, beban |
| Boot produksi | job CI `API boots in production mode` | API bisa start dengan setelan dan gem produksi | Infrastruktur nyata (secret, DB produksi) |
| Web | `web/src/**/*.test.tsx` | Payload form sesuai kontrak API; komponen memakai field yang benar | Tampilan visual, e2e di browser |
| Kerahasiaan | `web/quality/scan/` | Nama organisasi/produk/klien tidak ada di repo (daftar disimpan sebagai hash) | Isi berkas biner |
| Token dev | `web/quality/checks/no-dev-token.cjs` | Token login tidak bisa masuk ke bundle produksi | Rahasia lain |

## Menjalankan di lokal

```bash
# Skrip gate (tanpa dependensi, butuh Node 20+)
node --test web/quality/
node web/quality/checks/traceability.cjs
node web/quality/scan/identifiers.cjs
node web/quality/checks/no-dev-token.cjs

# Simulasi gate DoR untuk sebuah PR (isi PR di file, bandingkan dengan main)
node web/quality/dor/run.cjs --body pr.md --title "fix: ..." --base origin/main

# Web
cd web && npm ci && npm run typecheck && npm test

# API (butuh Ruby 3.3.2 + Postgres + Redis; paling mudah lewat Docker)
cd api && bundle install
RAILS_ENV=test bundle exec rails db:create db:schema:load
RAILS_ENV=test bundle exec rspec --tag critical      # jalur kritis
RAILS_ENV=test bundle exec rspec --tag ~critical     # kontrak API
RAILS_ENV=test bundle exec rake rswag:specs:swaggerize   # regenerasi swagger.yaml, lalu commit
```

CI (`.github/workflows/ci.yml`) menjalankan semuanya pada setiap push dan PR, dan status tunggal **Quality gate** hanya hijau
bila semua job hijau. Lindungi cabang `main` dengan status itu dan dengan **Definition of Ready**.

## Aturan

1. **Merah dijadikan hijau dengan memperbaiki cacat, bukan dengan melemahkan tes.** Tes boleh diubah hanya bila spec-nya berubah, dan perubahan itu ada di PR yang menautkan spec baru.
2. Perubahan di `api/app|config|db` atau `web/src` wajib menyentuh minimal satu file tes.
3. Bug baru ditemukan ⇒ tulis tes merahnya lebih dulu, tautkan ke baris di `assessment/traceability.md`.

## Menambah check

- **Tes jalur kritis API:** buat `api/spec/critical/xxx_spec.rb`, beri tag `:critical`, tulis di kepala berkas apa yang dilindungi dan apa yang tidak.
- **Endpoint baru:** tambahkan spec rswag di `api/spec/requests/api/v1/`, jalankan `swaggerize`, commit `swagger.yaml`.
- **Tes web terhadap respons API:** pakai `sampleOf("NamaSkema")` dari `web/src/test/openapiSample.ts` agar bodi respons berasal dari kontrak, bukan fixture tulis tangan.
- **Identifier terlarang baru:** `node web/quality/scan/identifiers.cjs --hash <istilah>` lalu tempel hasilnya di `web/quality/scan/forbidden-terms.sha256`.
- **Spec baru:** salin `assessment/specs/_template.md`, tautkan di PR (bagian *Spec*).

## Catatan lingkungan lokal

Folder `dev-local/` (di-gitignore) berisi docker-compose untuk Postgres, Redis, API, Sidekiq, dan adapter DeepSeek lokal.
Tidak ada yang di dalamnya dipakai CI.
