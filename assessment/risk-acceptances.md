# Penerimaan risiko

Satu-satunya cara sebuah P1 yang belum diperbaiki bisa ikut dirilis. P0 tidak pernah bisa diterima.
Gate rilis (`web/quality/release/gate.cjs`) membaca tabel ini. Sebuah baris dianggap sah hanya jika:

- **Pemilik** bernama (bukan `TBD`, `-`, atau kosong): orang yang menanggung risikonya bila terjadi.
- **Sampai** berupa tanggal `YYYY-MM-DD` yang belum lewat. Penerimaan selalu punya batas waktu.
- **Alasan** menjelaskan mengapa risikonya dapat diterima dan apa yang membatasi dampaknya (minimal 20 karakter).
- Risikonya juga **diungkap di `RELEASE_NOTES.md`**.

| Audit | Pemilik | Sampai | Alasan |
|---|---|---|---|

Saat ini kosong: tidak ada risiko yang diterima untuk versi mana pun.
