# SPEC-001 - Isolasi tenant dan pengikatan login

Temuan audit: R-01, R-02
Status: diterima

## Masalah
Portfolio, skill portfolio, dan laporan fit/gap tidak punya tenant sendiri dan dicari hanya dengan id, sehingga
seorang assessor dari satu organisasi bisa membaca, mengekspor, dan mengubah kandidat milik organisasi lain. Login
mengambil tenant dari header yang dikirim klien, sehingga admin mana pun bisa mendapat token untuk organisasi mana pun.

## Aturan
1. Setiap record yang bisa dijangkau lewat id melalui API milik tepat satu tenant; pencarian dari tenant lain berperilaku sebagai "tidak ditemukan" (404), bukan 403, sehingga keberadaannya tidak terungkap.
2. Record turunan (portfolio, skill portfolio, laporan fit/gap, override) mewarisi tenant dari sesi tempat ia berada; ia dicari lewat induk yang sudah ter-scope tenant.
3. Tenant sebuah login adalah tenant milik pengguna (`users.tenant_id`). Header `X-Tenant-Scheme` yang dikirim klien diabaikan untuk autentikasi. Pengguna yang tidak ditugaskan ke organisasi tidak bisa login (403).
3a. Token tanpa claim tenant (`scheme`) ditolak; header `X-Tenant-Scheme` tidak pernah melengkapi sebuah token.
4. Job latar belakang bekerja pada id yang diberikan oleh request yang sudah diperiksa; mereka tidak memperluas akses.

## Kriteria penerimaan
Given seorang admin organisasi A dan sebuah wawancara selesai milik organisasi B
When admin itu meminta ekspor portfolio, fit/gap, regenerasi fit/gap, laporan fit/gap, atau override rating milik B lewat id
Then setiap request dijawab 404, tidak ada job yang masuk antrean, dan tidak ada baris override.

Given seorang admin organisasi A yang sedang login
When ia login sambil mengirim `X-Tenant-Scheme` milik organisasi B
Then claim scheme pada token bukan scheme milik B.

Given seorang admin organisasi A dan sebuah akun yang tidak ditugaskan ke organisasi mana pun
When akun yang belum ditugaskan itu login
Then jawabannya 403 dan tidak ada token yang diterbitkan.

Given sebuah token bertanda tangan yang tidak punya claim scheme
When token itu dipakai bersama header X-Tenant-Scheme
Then request ditolak (403).

Given seorang admin organisasi A
When ia melihat daftar assessment
Then ia hanya melihat assessment milik A.

## Di luar cakupan
Row-level security di database; endpoint WebSocket (dicatat sebagai R-19 di audit).

## Pemeriksa
api/spec/critical/tenant_isolation_spec.rb
