# Verifikasi end-to-end wawancara suara (manual)

Bagian yang tidak bisa dibuktikan oleh tes otomatis: browser sungguhan, mikrofon, WebSocket, dan Gemini Live.
Dilakukan sekali per versi yang akan dirilis, oleh orang yang menjalankan rilis. Hasilnya dicatat di
`assessment/e2e-verification.md` (berkas itu **tidak ada** sampai pemeriksaan ini dilakukan; ketiadaannya adalah salah satu
alasan gate rilis menjawab BLOCKED).

## Prasyarat
- Lingkungan staging dengan `GEMINI_API_KEY` sungguhan, `WEB_BASE_URL` dan `APP_BASE_URL` yang berbeda.
- Dua organisasi (A dan B) dan satu admin untuk masing-masing (`rails users:create_admin`).

## Langkah dan hasil yang diharapkan
1. Masuk sebagai admin A, buat assessment dengan 2 skill dan batas waktu 10 menit, undang kandidat. **Tautan undangan membuka halaman wawancara di aplikasi web.**
2. Buka tautan di browser kandidat, lulus cek perangkat. **Cek perangkat lolos tanpa permintaan ke host pihak ketiga** (lihat tab Network).
3. Wawancara berjalan dua arah: AI bertanya, kandidat menjawab, transkrip muncul. **Audio kandidat sampai ke model** (ini yang belum pernah dibuktikan: frame biner).
4. Pantau di monitor assessor: **coverage berubah sesuai jawaban**.
5. Dari dashboard assessor, akhiri sesi saat wawancara berjalan. **Dalam beberapa detik browser kandidat menampilkan layar selesai dan suara berhenti** (R-12).
6. Tunggu portfolio. **Rating memuat kutipan, level 1-5, confidence sesuai coverage.** Ekspor PDF dan JSON; **keduanya terunduh**.
7. Masuk sebagai admin B, coba buka portfolio A dengan id-nya. **404.**
8. Ulangi wawancara dan biarkan waktu habis. **Sesi berakhir dengan alasan `time_ceiling`** (catatan: R-17 menyebut ini hanya dicek saat ada transkripsi).

## Catatan hasil

Salin ke `assessment/e2e-verification.md`:

```
Version: v1.0.0
Date: YYYY-MM-DD
Environment: staging
Tester: nama
Result: pass | fail
Steps that failed or deviated: ...
```

`Result: pass` hanya jika langkah 1-8 sesuai. Bila ada yang gagal, tulis `Result: fail` dan alasannya: itu tetap catatan
yang jujur, dan gate tetap menjawab BLOCKED.
