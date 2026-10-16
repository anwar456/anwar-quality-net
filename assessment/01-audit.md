# 01 — Audit Platform

Cakupan: `api/` (Rails API + Sidekiq + proxy WebSocket ke LLM audio langsung) dan `web/` (SPA React), dibaca bersama-sama.
Bahasa severity mengikuti brief (P0 blocker / P1 major / P2 minor / P3 kosmetik; setiap masalah integritas data minimal P1).

## 1. Kesimpulan

**Jangan dirilis ke klien.** Ada 1 temuan P0 yang terbukti saat aplikasi dijalankan, dan 15 temuan P1. Yang paling berbahaya:

0. **API tidak bisa start di mode produksi** (R-31): dua kesalahan terpisah membuat proses langsung crash. Di mode development semuanya tampak normal, sehingga tidak ada yang menyadarinya.
1. Satu tenant bisa membaca dan mengubah portfolio kandidat milik tenant lain (R-01), dan assessor mana pun bisa mencetak token untuk tenant mana pun (R-02).
2. Keluaran utama produk, yaitu rating skill yang bisa dipertanggungjawabkan, ternyata tidak bisa dipertanggungjawabkan: level dan confidence diambil langsung dari keluaran LLM dengan pemaksaan nilai secara diam-diam (R-05),
   coverage dipaksa menjadi "covered" tanpa bukti (R-06), dan laporan fit/gap menulis "Not assessed" untuk skill yang *sebenarnya sudah dinilai* (R-04).
3. Beberapa layar menampilkan sesuatu yang tidak tersimpan di database: skill yang dihapus tetap ada di DB (R-03), assessment yang "dihapus" tidak terhapus (R-10),
   dan tabel fit/gap kehilangan kolom "Required" (R-08).
4. Link undangan yang dikirim ke kandidat mengarah ke host API, bukan ke aplikasi web (R-07).
5. Tidak ada satu pun tes otomatis, workflow CI, atau acceptance criteria tertulis di repo (R-15, R-27), sehingga tidak satu pun masalah di atas akan tertangkap lebih awal.

## 2. Cara audit dilakukan dan batasannya

| Area | Metode | Tingkat keyakinan |
|---|---|---|
| `web/` | Membaca seluruh source non-UI-kit; `npm install && npm run build` (tsc + vite) | Build **terverifikasi hijau**; temuan berasal dari pembacaan statis |
| `api/` | Membaca setiap file di `app/`, `config/`, `db/`, `k8s/`. Setelah itu API dijalankan di Docker (Postgres 16, Redis, Puma, Sidekiq), beberapa temuan direproduksi lewat HTTP, dan boot mode produksi dicoba (R-31) | Statis, kecuali temuan yang ditandai **[terbukti]** di bawah. Sisanya dijadwalkan di suite tes tugas 2 |
| Spec | README mengarah ke wiki. Halaman PRD tidak tampil saat diakses lewat browser, tetapi isinya ada di riwayat git wiki (PRD 01 *perilaku AI interviewer*, PRD 02 *simulasi end-to-end*). Dipakai sebagai acuan untuk membedakan "salah dibangun" dari "spec tidak ada" | Baik |
| Konteks proyek | Tiket terbuka/tertutup di tracker sumber (4 item, 2 yang berbeda), catatan repo, manifest k8s, seeds, `.irbrc`, riwayat (2 commit). Tidak ditemukan kredensial di file yang di-track maupun di riwayat | Baik |

Kolom "Kelas": **BW** = built wrong (ada definisi, tetapi build menyimpang darinya); **MS** = missing/ambiguous spec (tidak pernah didefinisikan atau ambigu).

## 3. Yang sudah berjalan baik (agar daftar di bawah dibaca secara proporsional)

- Build produksi web lolos TypeScript mode strict. Routing, form, dan polling tersusun dengan wajar.
- Verifikasi JWT mengunci algoritma `HS256` (`app/lib/json_web_token.rb:18`), invite token berupa 256-bit acak (`session.rb:36`), login dan endpoint kandidat dibatasi rate limit (`rack_attack.rb`).
- Ada pengaman di level DB untuk hal yang penting bagi rating: constraint `CHECK` pada level 1–5 dan batas waktu, serta unique index pada `(session, turn)`, `(portfolio, vacancy)`, `invite_token`.
- State machine coverage (`coverage/state_engine.rb`) menegakkan aturan PRD "tidak boleh maju melewati *initiated* tanpa 2 probe" dan memproses transisi satu langkah demi satu langkah. Prompt analyzer memperlakukan teks transkrip sebagai data tak tepercaya (sadar prompt-injection) dan membatasi kenaikan probe-count maksimal +1 per eksekusi.
- Perbandingan fit/gap itu sendiri berbasis aturan dan deterministik (`fit_gap/engine.rb:43-67`); hanya narasinya yang ditulis LLM. Pembagian ini sudah tepat.
- Kode siklus hidup sesi memperlihatkan perhatian pada reconnect, grace period, dan end yang idempoten (`end_handler.rb`).

## 4. Daftar risiko berperingkat

Peringkat = severity dulu, lalu radius dampak, lalu kemungkinan terjadi. "Penangkap" = check yang akan membuat temuan ini merah di tugas 2.

### P0 — blocker

| ID | Kelas | Risiko | Dampak | Bukti | Penangkap |
|---|---|---|---|---|---|
| R-31 | BW | **API tidak bisa boot dengan `RAILS_ENV=production`**, yaitu mode yang dipakai manifest k8s (`RAILS_ENV: production`). (a) `config/environments/production.rb:34` memakai `config.active_job`, tetapi railtie ActiveJob tidak dimuat di `config/application.rb` ⇒ `NoMethodError` saat start. (b) `app/channels/audio_websocket_middleware.rb` dan `coverage_websocket_middleware.rb` mendefinisikan `AudioWebSocketMiddleware` / `CoverageWebSocketMiddleware`, padahal Zeitwerk (eager load, aktif di produksi) mengharapkan `AudioWebsocketMiddleware` / `CoverageWebsocketMiddleware` ⇒ `NameError` | Tidak ada pod API yang bisa hidup di produksi: tidak ada fitur yang bisa dipakai. Tidak terlihat di development karena di sana kode dimuat secara lazy | **Terbukti**: `rails zeitwerk:check` ⇒ `uninitialized constant AudioWebsocketMiddleware`; `RAILS_ENV=production rails runner` ⇒ `undefined method 'active_job'`. Mungkin ada masalah lain di belakang keduanya; belum terlihat karena boot berhenti di sana | `spec/critical/boot_spec.rb` (eager load seperti produksi) + job CI "API boots in production mode" (`zeitwerk:check` dan boot dengan gem produksi saja) |

### P1 — major

**Terbukti di aplikasi yang berjalan (reproduksi HTTP, 15 Okt 2026):**
R-01 (token org lain berhasil `POST /portfolio_skills/1/override` pada portfolio org pertama → 201, sedangkan jalur lewat sesi benar-benar 404),
R-02 (login dengan header `X-Tenant-Scheme: other-corp` menghasilkan token ber-claim `scheme=other-corp`),
R-03 (form edit mengirim 1 dari 2 skill → DB tetap menyimpan 2),
R-07 (`invite_url` = `http://localhost:3001/interview/<token>`, host API),
R-09 (`POST /sessions/<token>/audio_complete` tanpa auth pada sesi yang belum dimulai → 200, status `ended`, `end_reason=all_covered`),
R-10 (`DELETE` assessment yang punya sesi → 200 "Assessment deleted", `GET` sesudahnya → 200).
Temuan lain masih statis.

| ID | Kelas | Risiko | Dampak (siapa/apa yang dirugikan) | Bukti (file:baris / cara reproduksi) | Penangkap |
|---|---|---|---|---|---|
| R-01 | BW + MS | **Akses lintas tenant ke portfolio.** `Portfolio`, `PortfolioSkill`, `FitGapReport` tidak punya kolom atau scope tenant; controller mencari datanya hanya dengan id | Tenant A bisa membaca/mengekspor (PDF/JSON), men-generate ulang, dan **meng-override rating** kandidat tenant B hanya dengan menelusuri id berurutan. PII kandidat dan kutipan bukti bocor; rating bisa diubah | `portfolios_controller.rb:82,104,130,156`, `portfolio_skills_controller.rb:51`, `models/portfolio.rb`. Reproduksi: dua org, JWT org A, `GET /api/v1/portfolios/<id-org-B>/export?format=json` | Request spec: id lintas tenant harus 404 di setiap route portfolio |
| R-02 | BW + MS | **Login mencetak token untuk tenant mana pun.** `scheme` diambil dari header `X-Tenant-Scheme` yang dikontrol klien, `users` tidak punya relasi ke tenant, dan saat header tidak ada (web tidak pernah mengirimnya) fallback-nya `SELECT scheme FROM organizations LIMIT 1` | Admin mana pun bisa bertindak di tenant mana pun; pada instalasi multi-tenant sungguhan, login mendarat di tenant yang acak | `authentication_controller.rb:16,24-29`; `grep -r X-Tenant-Scheme web/src` → tidak ada hasil | Request spec: login dengan header scheme asing harus ditolak; tenant saat login harus ditentukan secara deterministik |
| R-03 | BW | **Menghapus skill di form edit tidak pernah tersimpan.** UI membuang barisnya dari array form; API hanya menghapus dengan `_destroy`, yang tidak pernah dikirim kode web mana pun | Assessor melihat skill hilang; DB tetap menyimpannya. Pada assessment, skill itu masih diwawancarai, masih ada di prompt dan portfolio. Pada vacancy, skill itu masih memengaruhi fit/gap ("layar ≠ penyimpanan") | `AssessmentEditPage.tsx:76-79`, `VacancyEditPage.tsx:41-48,76`; `grep _destroy web/src` → hanya deklarasi tipe | API spec (id anak yang dihilangkan dihapus atau ditolak) + tes web untuk pembangun payload |
| R-04 | MS + BW | **Fit/gap menulis "Not assessed" untuk skill yang sudah dinilai.** Skill portfolio disimpan dengan `skill_id`/`skill_label` yang dikembalikan LLM; contoh di PRD memakai `sk-eng-001` dan "React / Frontend Development", sedangkan taksonomi seed memakai `SK-ENG-001` / "React / Frontend Development Core". Pencocokan case-sensitive pada id, lalu label persis | Keputusan perekrutan menampilkan gap padahal sebenarnya match; atau skill menghilang diam-diam dari laporan | `portfolios/generator.rb:106,156-177`, `fit_gap/engine.rb:88-91`, `db/seeds.rb:84-97`, PRD 01 §5 | Unit spec: generator harus mengaitkan hasil ke baris skill yang dikonfigurasi, bukan ke teks LLM |
| R-05 | BW | **Rating tidak bisa dipertanggungjawabkan.** `level` diproses `to_i.clamp(1,5)` sehingga level yang hilang/sampah diam-diam menjadi L1; `confidence` adalah apa pun yang ditulis LLM padahal PRD 01 §5 mendefinisikannya secara deterministik dari `probe_count`/state; skill yang dilewatkan LLM tidak muncul; penyimpanan tidak transaksional (`destroy_all` lalu N kali `create!` → setengah portfolio tersimpan dan ditandai failed); sesi dengan transkrip kosong tetap menghasilkan portfolio "complete" | Kandidat mendapat rating karangan atau yang digelembungkan dengan confidence `high`; premis utama produk runtuh | `generator.rb:150-179` (clamp di baris 161, 173), `generator.rb:22-36`, `end_handler.rb:14-44` (tidak ada guard transkrip minimum) | Unit spec: payload LLM tidak valid ⇒ generate gagal dan tidak ada yang tersimpan; confidence dihitung di server; transkrip kosong ⇒ tidak ada portfolio |
| R-06 | BW (melebihi spec) | **Coverage dipaksa menjadi "covered".** Skill `partial` apa pun dengan `probe_count >= 4` diubah ke `covered` tanpa pengecekan bukti. PRD menyatakan covered butuh bukti yang bisa dipertahankan | Skill ditandai covered (dan confidence "high" menurut R-05) dengan sinyal tipis; interview berakhir lebih awal lewat `all_covered`; assessor melihat gambaran yang keliru | `coverage_analyzer_worker.rb:84-101` vs PRD 01 §4 | Worker spec: partial + probe_count 4 harus tetap partial tanpa bukti dari analyzer |
| R-07 | BW | **Link undangan mengarah ke API.** `invite_url` = `APP_BASE_URL` + `/interview/:token`, padahal `APP_BASE_URL` didokumentasikan dan dikonfigurasi sebagai URL *backend*; halaman interview ada di origin web. Tiket tracker tentang "halaman error Rails untuk `/interview/:token`" adalah gejala bug ini, yang salah dikategorikan sebagai soal kerapian routing | Setiap undangan yang dikirim ke kandidat adalah link mati kecuali ada yang mengedit host secara manual | `session.rb:28-31`, `k8s/configmap.yaml:20`, `api/README.md:30`, PRD 02 fase 1 (link di domain aplikasi), tracker #1/#3 | Spec: `invite_url` dibangun dari setting origin web tersendiri; boot check bahwa nilainya berbeda dari URL API |
| R-08 | BW | **Seam tabel fit/gap rusak.** API mengirim `expected_level`; tabel membaca `required_level`, sehingga kolom "Required" kosong di setiap baris. Penanda ✏ "override manusia diterapkan" membaca `is_override`, yang tidak pernah dikirim API | Inti laporan (required vs aktual) hilang separuh, dan override manusia tidak terlihat di dalamnya. Tabel U10 di PRD 02 menampilkan keduanya | `ComparisonTable.tsx:50`, `types/index.ts:132,136`, `fit_gap/engine.rb:58-66` | Contract test: fixture API di-parse oleh tipe/renderer web; satu skema bersama |
| R-09 | BW | **`audio_complete` tanpa autentikasi, tidak peduli state, dan reason di-hard-code.** Siapa pun yang memegang invite token bisa mengakhiri sesi *pending* (belum pernah dimulai); dicatat sebagai `all_covered` apa pun kondisi coverage-nya, lalu meng-generate portfolio dari transkrip kosong (memicu R-05) | Assessment selesai palsu; analitik `end_reason` salah | `sessions_controller.rb:115-129` | Request spec: hanya sesi aktif yang coverage-nya lengkap yang bisa diakhiri lewat jalur ini |
| R-10 | BW | **"Delete assessment" melaporkan sukses padahal tidak ada yang terhapus** bila sudah ada sesi (`restrict_with_error` membuat `destroy` mengembalikan false; controller mengabaikannya dan mengembalikan 200 "Assessment deleted") | Pengguna mengira data sudah dihapus (ekspektasi privasi/retensi), padahal belum | `assessments_controller.rb:51-54`, `models/assessment.rb:7` | Request spec: delete saat ada sesi ⇒ 422/409, record tetap ada |
| R-11 | BW | **Penyimpanan transkrip menelan semua error.** Nomor turn dinaikkan di memori lebih dulu; kegagalan DB hanya di-log, sehingga portfolio kemudian dibuat dari transkrip yang berlubang tanpa ada sinyal ke siapa pun | Rating dihitung dari bukti yang tidak lengkap tanpa peringatan | `audio_websocket_middleware.rb:649-659`, `:178` | Spec: penulisan yang gagal dimunculkan (retry + flag pada sesi), tidak pernah diam |
| R-12 | BW (statis, perlu verifikasi) | **"End session" oleh assessor tidak menghentikan stream langsung.** REST end hanya mengubah baris dan mem-publish ke channel monitor; socket audio kandidat dan koneksi LLM upstream tidak diberi tahu | Biaya terus berjalan, kandidat terus berbicara dengan interviewer yang sesinya sudah "ended", turn tambahan masuk setelah portfolio mulai di-generate | `sessions_controller.rb:60-78`, `end_handler.rb:48-55`, tidak ada subscriber di `audio_websocket_middleware.rb` | Integration spec (butuh runtime) |
| R-13 | MS + BW | **Tidak ada cara membuat assessor pertama.** Seeds membuat org dan taksonomi tetapi tidak membuat user; web memanggil endpoint `/signup` yang tidak ada (`SignupPage` tidak terpasang di router). Web memakai `VITE_DEV_TOKEN` saat build bila tidak ada token login, yang berarti kredensial bisa tertanam di bundle produksi | Lingkungan baru tidak bisa dipakai tanpa akses console; jika env var itu diset saat build, token menjadi publik dan logout tidak pernah berfungsi | `db/seeds.rb`, `config/routes.rb`, `services/auth.ts:16`, `stores/authAtom.ts:9-11`, `services/api.ts:30-33` | Seed spec; build check web yang gagal bila `VITE_DEV_TOKEN` diset untuk produksi |
| R-14 | BW (tergantung konfigurasi) | **Kandidat bisa terblokir di hardware check pada produksi.** Tombol start nonaktif sampai speed test lolos; tes memanggil host pihak ketiga yang dilarang CSP bawaan (`connect-src 'self' <api>`), dan override endpoint kosong di `.env.example` | Pada konfigurasi produksi default, setiap kandidat gagal di cek "internet" dan tidak bisa memulai | `HardwareCheck.tsx:127,284`, `internetSpeedTest.ts:44-47,59-63,92-96`, CSP `vercel.json`, `.env.example` | Config check: build produksi mewajibkan URL speed-test dan CSP harus mengizinkannya |
| R-15 | MS | **Spec hilang di bagian yang paling penting.** Tidak ada acceptance criteria (PRD 02 berupa simulasi naratif, tanpa Given/When/Then); tidak ada yang mendefinisikan tenancy, auth/role, consent kandidat, retensi rekaman/transkrip, kedaluwarsa undangan, perilaku saat gagal, maupun NFR; PRD tidak ada di repo dan gagal tampil di wiki. PRD 01 dan PRD 02 saling bertentangan (jendela analyzer 6 vs 2 turn; id skill huruf kecil vs besar; skill discovered mulai di probe_count 0 pada PRD, 1 pada kode) | Tidak ada yang bisa memastikan apakah R-01…R-14 itu bug; setiap perselisihan jadi soal tafsir | Riwayat wiki, `README.md`, tidak adanya `docs/` | **Gate Definition-of-Ready** (tugas 2): tidak ada perubahan yang boleh merge tanpa spec + AC + catatan desain yang ditautkan |

### P2 — minor (berjalan dan datanya benar, tetapi ada masalah terbatas/tidak memblokir)

| ID | Kelas | Risiko | Bukti |
|---|---|---|---|
| R-16 | BW (perlu verifikasi) | Ekspor PDF kemungkinan error pada karakter di luar Windows-1252 (font bawaan PDF): baris override memuat "→", dan kutipan kandidat berupa teks bebas. Ekspor JSON tetap berfungsi | `exports/pdf_generator.rb:85,100` |
| R-17 | BW | Batas waktu hanya ditegakkan saat ada event transkripsi; timer klien mulai ulang dari durasi penuh saat halaman di-refresh dan mengakhiri sesi sebagai `manual_candidate`, bukan `time_ceiling` | `audio_websocket_middleware.rb:661-678`, `InterviewTimer.tsx:20-22`, `InterviewPage.tsx:173-181,254-258` |
| R-18 | BW | `end_reason` salah label: kandidat yang menutup tab dicatat sebagai `error` dan tampil sebagai "Last: failed" | `audio_websocket_middleware.rb:501-517`, `AssessmentListPage.tsx:21-22` |
| R-19 | BW | Kedua pintu masuk WebSocket menerima JWT tenant yang valid apa pun tanpa memeriksa role (token ber-role kandidat bisa menonton monitor coverage langsung) | `coverage_websocket_middleware.rb:125-137`, `audio_websocket_middleware.rb:742-750` |
| R-20 | MS | Invite token tidak pernah kedaluwarsa atau dirotasi (teks error menyebut "expired"); tidak ada yang mencegah dua koneksi bersamaan pada satu token (sesi upstream ganda, nomor turn bertabrakan) | `sessions_controller.rb:119-137`, `audio_websocket_middleware.rb:733-761` |
| R-21 | BW | Skill discovered yang tertinggal di `initiated` memblokir `all_covered` selamanya (PRD berakhir hanya pada skill terkonfigurasi); `find_map(nil)` bisa cocok dengan skill custom yang salah | `coverage/map_injector.rb:48-58`, `coverage/analyzer.rb:167-170` |
| R-22 | BW | Regenerasi fit/gap menghapus laporan cache sebelum job selesai; halaman web meng-enqueue ulang job setiap 5 detik saat 404; ekspor JSON diam-diam mengembalikan `null` untuk laporan di jeda itu | `portfolio_skills_controller.rb:41-48`, `FitGapReportPage.tsx:28-44,62`, `portfolios_controller.rb:218-222` |
| R-23 | MS | Mengedit assessment menulis ulang anchor yang dipakai sesi/portfolio yang sudah ada (tidak ada snapshot); system prompt lama tetap aktif sampai job async selesai, padahal API menjawab `system_prompt_generated: true` | `assessments_controller.rb:42-46`, `generator.rb:41-48` |
| R-24 | BW | "Rahasia" sinyal sistem `SYS-TC-7x9k` di-hard-code di source dan ditulis ke dalam prompt yang dilihat model, sehingga bisa dipancing keluar | `audio_websocket_middleware.rb:16`, `system_prompt_compiler.rb:140,149` |
| R-25 | MS | Desain auth: kunci penandatangan dipakai bersama antar-service (token dari service saudara = admin penuh di sini); role dipercaya dari JWT selama 3 hari tanpa cek DB; JWT disimpan di `localStorage`; CSP mengizinkan script `'unsafe-inline'` | `json_web_token.rb`, `authorize_api_request.rb:8`, `vercel.json` |
| R-26 | BW | Kebersihan operasional: Rails 7.0 dan Puma 5.6 sudah end-of-life; `web/package-lock.json` tidak di-commit; Dockerfile berjalan sebagai root tanpa `.dockerignore` (file `application.yml` lokal bisa ikut masuk ke image); manifest memakai `:latest`, tidak merujuk `Secret` apa pun (boot butuh `SECRET_KEY_BASE`, kredensial DB, API key), berisi placeholder origin, dan menjalankan Sidekiq dengan `-e staging` terhadap konfigurasi produksi | `Gemfile:5-9`, `Dockerfile`, `k8s/*.yaml` |
| R-27 | BW | **Tidak ada tes, tidak ada CI, tidak ada lint gate**: nol file spec/test, tidak ada workflow, hanya `.rspec`; web tidak punya script test. Tidak ada kontrak antara kedua service | struktur repo |
| R-28 | BW | **Kerahasiaan / pengungkapan**: source memuat hostname organisasi, project container registry, nama node pool dan service, serta rujukan silang ke service saudara. Harus dibersihkan sebelum repo publik (satu-satunya aturan keras di brief); juga membuka topologi infrastruktur | `k8s/*`, `README.md`, `vercel.json`, komentar di `api/app` |
| R-29 | BW (proses) | Tiket tracker #1–#4 sudah ditutup tetapi belum diperbaiki: tidak ada catch-all route JSON, dan halaman edit menelan 404 lalu menampilkan form kosong | `config/routes.rb`, `AssessmentEditPage.tsx:51-57`, `VacancyEditPage.tsx:39` |

### P3 — kosmetik

R-30: request tanpa token dijawab `403 Tenant not found` (bukan 401) karena tenant diperiksa sebelum autentikasi (terbukti lewat spec); tidak ada `.gitattributes`, sehingga checkout di Windows membuat `bin/*` ber-CRLF dan Ruby di Docker memberi peringatan `shebang line ending with \r`; `database.yml` menulis keras nama database development sehingga `DB_NAME` diabaikan di environment tersebut; `paginate` menerima `page<=0` / `per_page<=0`; README tidak sinkron (`.env.example` dan fallback web memakai port 3000 sedangkan API berjalan di 3001; `GEMINI_ANALYSIS_MODEL` didokumentasikan tetapi kode membaca `GEMINI_FLASH_MODEL`; langkah 7 menunjuk `../ai-interview-web` yang tidak ada); `.irbrc` mengquery kolom `discarded_at` yang tidak ada di schema; `SignupPage` mati; komentar route menyebut `/end` padahal route-nya `/end_session`; index ganda pada `coverage_maps.session_id`; drift tipe TS (`skill_id: number` vs id string, status sesi tanpa `failed`); tidak ada cara mengubah bahasa interview setelah dibuat.

### Kecurigaan terbuka yang butuh cek runtime (belum diklaim sebagai temuan)

- Frame WebSocket biner: browser mengirim `ArrayBuffer` mentah; server memperlakukan frame `String` yang tidak diawali `{` sebagai audio dan sisanya sebagai kontrol JSON (`audio_websocket_middleware.rb:65-71,418-441`). Jika library WebSocket menyerahkan frame biner sebagai array byte, audio mikrofon tidak akan pernah diteruskan. Produk tampaknya pernah berjalan sebelumnya, jadi kemungkinan besar aman; akan dibuktikan lewat tes tingkat socket.
- `{"type":"end_session"}` yang tiba pada socket yang autentikasinya gagal akan mendereferensi session nil di dalam event loop (handler pesan hanya me-rescue `JSON::ParserError`).

## 5. Pola sistemik (mengapa masalah ini terus berulang)

1. **Batas kepercayaan digambar di tempat yang salah.** Header dari klien (R-02), teks LLM (R-04, R-05, R-06), pemegang invite token (R-09), dan state form di browser (R-03) diperlakukan sebagai kebenaran. Satu aturan menyelesaikan seluruh kelas ini: *kunci identitas dan level berasal dari record kita sendiri; teks eksternal adalah data yang divalidasi, tidak pernah dijadikan kunci.*
2. **Tenancy berdasarkan konvensi, bukan konstruksi.** Scope diterapkan per model dan dimatikan diam-diam bila tenant tidak diset (`tenant_scoped.rb:18-24`); tabel anak sama sekali tidak punya tenant. Setiap endpoint baru yang memakai `Child.find(id)` membuka kembali R-01.
3. **Seam web/API tidak punya kontrak.** Pembungkusan envelope, nama field, semantik URL, dan semantik penghapusan disepakati dari ingatan (R-03, R-07, R-08). Tes skema/fixture bersama jauh lebih murah daripada QA manual sebanyak apa pun.
4. **Kegagalan ditelan demi menjaga interview tetap hidup**, yang benar untuk panggilan langsung tetapi salah untuk catatan. `rescue => log` di sekitar penyimpanan (R-11, sebagian R-05) mengubah gangguan menjadi data yang salah secara diam-diam.
5. **Pekerjaan dimulai dari spec hantu** (R-15): perilaku ditambahkan padahal tidak diminta PRD (R-06) dan ketidakkonsistenan PRD diselesaikan secara implisit di kode (R-04). Tanpa acceptance criteria tidak ada build merah yang bisa dijadikan rujukan.

## 6. Garis ship / do-not-ship

**Jangan dirilis.** Untuk mencapai "rilis dengan risiko sisa yang diungkap", hal berikut harus diperbaiki *dan* dijaga oleh check yang tetap ada di CI:

| Gate | Item |
|---|---|
| Wajib diperbaiki agar aplikasi bisa hidup di produksi | R-31 |
| Wajib diperbaiki sebelum data klien masuk | R-01, R-02, R-03, R-07, R-09, R-10 |
| Wajib diperbaiki sebelum rating ditampilkan ke pengambil keputusan perekrutan | R-04, R-05, R-06, R-08, R-11 |
| Harus diperbaiki, atau punya pemilik + mitigasi + tanggal | R-12, R-13, R-14, R-15 |
| Gate proses yang harus ditegakkan pipeline mulai sekarang | spec/AC/rencana desain tertaut di setiap perubahan (R-15); tes tersedia (R-27); pemindaian kerahasiaan (R-28); kontrak web↔API (R-08) |

Temuan P2/P3 boleh ikut rilis bila dicantumkan di release notes beserta pemiliknya.

## 7. Asumsi yang saya buat (tidak ada kanal tanya jawab)

- Tenancy: satu organisasi per pelanggan; assessor hanya boleh melihat data organisasinya sendiri. Tidak dinyatakan di mana pun; diasumsikan.
- PRD 01 adalah sumber kebenaran untuk semantik rating (aturan confidence, aturan coverage); PRD 02 untuk alur. Bila keduanya bertentangan saya ikut PRD 01 dan mencatat konfliknya sebagai R-15.
- "Cacat" pada kualitas percakapan AI interviewer di luar cakupan; saya mengaudit data yang disimpan dan dihitung sistem, bukan apakah suara modelnya terdengar manusiawi.
- Severity diterapkan dari atas ke bawah sesuai brief: eksposur lintas tenant dan layar≠penyimpanan adalah P1 (integritas data), bukan P0, karena fungsi utama masih berjalan. Satu-satunya P0 adalah R-31, karena tanpa itu aplikasi tidak bisa hidup di produksi sama sekali.
- Temuan statis yang menyentuh perilaku yang hanya terlihat saat runtime diberi label demikian dan akan dikonfirmasi (atau dicabut) oleh suite tes di tugas 2.

## 8. Status akhir

Akan dilengkapi setelah tugas 2–4. Setiap R-xx akan ditandai **fixed / remaining (pemilik, mitigasi)** beserta rujukan commit dan check yang menjaganya.
