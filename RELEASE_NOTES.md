# Release notes

Status bukan ditentukan oleh berkas ini. Status (RELEASABLE atau BLOCKED) ditentukan oleh gate rilis pada tag
(`.github/workflows/release.yml`) dan tertulis di halaman *Release* GitHub untuk tag yang bersangkutan.
Berkas ini menyatakan apa yang diklaim oleh sebuah versi dan risiko yang diungkap.

## v1.0.0

Versi pertama setelah audit dan perbaikan. Dasarnya adalah kode yang diterima, dengan perbaikan untuk satu masalah P0
dan lima belas masalah P1 (lihat `assessment/01-audit.md`).

### Yang diklaim versi ini

- **API bisa start di mode produksi** (R-31), diperiksa dengan `zeitwerk:check` dan boot memakai hanya gem produksi.
- **Isolasi tenant**: data portfolio, rating, dan fit/gap satu organisasi tidak bisa dibaca atau diubah organisasi lain (R-01); token login mengikuti organisasi pengguna, bukan header dari klien (R-02).
- **Rating bisa dipertanggungjawabkan**: level, identitas skill, dan confidence berasal dari data kita dan divalidasi; rating tidak dibuat dari transkrip kosong atau bolong; hasil disimpan seluruhnya atau tidak sama sekali (R-04, R-05, R-11). Coverage tidak lagi dinaikkan hanya karena hitungan probe (R-06).
- **Yang tampil di layar sama dengan yang tersimpan**: skill yang dihapus di form benar-benar terhapus (R-03); hapus assessment yang punya kandidat menjawab 409 (R-10); tabel fit/gap menampilkan level yang dibutuhkan dan penanda override (R-08).
- **Siklus hidup sesi**: tautan undangan membuka halaman wawancara di aplikasi web (R-07); sesi hanya bisa diakhiri kandidat jika benar-benar berjalan dan coverage lengkap (R-09); saat assessor mengakhiri sesi, koneksi suara kandidat ikut ditutup (R-12).
- **Operasional**: assessor pertama bisa dibuat (`rails users:create_admin`, R-13); token dev tidak bisa masuk ke bundle produksi (R-13); cek perangkat kandidat mengukur ke API sendiri dan gagal tertutup (R-14); ekspor PDF tidak lagi gagal karena karakter di dalam teks (R-16); repositori tidak memuat nama organisasi pemilik (R-28).

### Yang tidak diklaim

- Wawancara suara langsung **belum diuji end-to-end** (WebSocket sungguhan dan Gemini Live). Logikanya diuji dengan socket palsu. Karena itu gate rilis meminta catatan verifikasi manual untuk versi ini.
- Tidak ada spesifikasi untuk consent kandidat, retensi rekaman dan transkrip, atau persyaratan non-fungsional.
- Kualitas penilaian model bahasa (apakah level L3 memang tepat) tidak diuji oleh kode.

### Risiko terbuka yang diungkap

| ID | Sev | Apa | Mitigasi saat ini |
|---|---|---|---|
| R-15 | P1 | Consent kandidat, retensi data, dan NFR tidak ditentukan; PRD asli tidak ada di repositori ini | Gate DoR mencegah perubahan baru tanpa spec; 8 spec tertulis ada untuk perilaku yang diperbaiki. **Belum cukup untuk dipakai oleh klien sungguhan** |

Risiko P2/P3 yang masih terbuka (token undangan tidak kedaluwarsa, peran tidak diperiksa di WebSocket, `end_reason`
yang bisa salah label, discovered skill yang menahan `all_covered`, dan lainnya) tercantum di
`assessment/01-audit.md` bagian 8 beserta urutan prioritasnya.

### Cara membaca status rilis

Sebuah versi **RELEASABLE** hanya jika: seluruh CI hijau; setiap P0 diperbaiki; setiap P1 diperbaiki atau punya
penerimaan risiko bernama dan belum kedaluwarsa di `assessment/risk-acceptances.md`; catatan rilis ini menyebut versi dan
mengungkap setiap risiko terbuka; dan ada catatan verifikasi end-to-end untuk versi itu di
`assessment/e2e-verification.md`. Selain itu statusnya **BLOCKED**, dengan alasan tertulis.
