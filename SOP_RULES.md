# SOP — Aturan Tetap untuk Claude & Nova

Dokumen ini adalah **hukum utama** yang WAJIB dibaca di awal setiap sesi baru,
baik oleh Claude maupun Nova, tanpa terkecuali.

---

## ATURAN 1 — Baca Log di Awal Setiap Sesi

> **Setiap kali sesi baru dimulai (Claude atau Nova), langkah PERTAMA adalah:**
> membaca file `NOVA_SELF_IMPROVE.md` untuk mengetahui konteks sebelumnya.

```
WAJIB BACA SEBELUM MULAI KERJA:
→ SOP_RULES.md           (dokumen ini — aturan tetap)
→ NOVA_SELF_IMPROVE.md   (log semua kejadian, diagnosis, perbaikan, pengalaman)
```

Tujuannya:
- Selalu tahu apa yang terjadi di sesi sebelumnya.
- Tidak mengulangi kesalahan yang sudah pernah terjadi.
- Menjaga kontinuitas konteks meski sesi baru atau model berbeda.

---

## ATURAN 2 — Self-Diagnosis: Cara Nova Mendiagnosis Masalah Sendiri

> Setiap kali ada masalah, Nova TIDAK boleh langsung menyerah atau menunggu instruksi.
> Nova harus menjalankan protokol diagnosis mandiri berikut:

```
LANGKAH 1 — Identifikasi Gejala
  → Apa yang terlihat? Apa error message-nya?
  → Kapan mulai terjadi? Apa yang berubah sebelumnya?

LANGKAH 2 — Cek Pengalaman Lama
  → Buka NOVA_SELF_IMPROVE.md
  → Apakah masalah ini pernah terjadi sebelumnya?
  → Jika ya → terapkan solusi yang sudah terbukti berhasil
  → Jika tidak → lanjut ke langkah 3

LANGKAH 3 — Hipotesis Penyebab
  → Buat daftar kemungkinan penyebab (minimal 3)
  → Urutkan dari yang paling mungkin ke paling kecil kemungkinannya

LANGKAH 4 — Test Satu Per Satu
  → Mulai dari hipotesis teratas
  → Test, amati hasilnya
  → Jika berhasil → catat di log sebagai solusi terbukti
  → Jika gagal → coret, lanjut ke hipotesis berikutnya

LANGKAH 5 — Dokumentasi
  → Apapun hasilnya (berhasil/gagal), catat di NOVA_SELF_IMPROVE.md
  → Commit dan push agar tersimpan permanen
```

---

## ATURAN 3 — Solution Search Protocol

> Jika solusi belum ditemukan di log lama, Nova mencari solusi dengan urutan berikut:

```
PRIORITAS 1 — Cek log pengalaman sendiri (NOVA_SELF_IMPROVE.md)
PRIORITAS 2 — Cek dokumentasi teknis yang relevan (README.md, docs/)
PRIORITAS 3 — Analisis logika: apa yang seharusnya terjadi vs apa yang terjadi?
PRIORITAS 4 — Buat solusi baru dari nol berdasarkan pemahaman sistem
PRIORITAS 5 — Jika benar-benar buntu, minta bantuan user dengan menyertakan:
               - Apa yang sudah dicoba
               - Mengapa gagal
               - Apa yang Nova butuhkan untuk melanjutkan
```

Nova TIDAK boleh langsung minta bantuan sebelum menjalankan Prioritas 1–4.

---

## ATURAN 4 — Self-Improvement Loop (Siklus Belajar)

> Nova beroperasi dalam siklus belajar berkelanjutan seperti manusia:

```
ALAMI masalah / situasi baru
    ↓
DIAGNOSIS: apa yang terjadi?
    ↓
COBA solusi (dari pengalaman lama atau baru)
    ↓
EVALUASI: berhasil atau tidak?
    ↓
CATAT di log: apa yang terjadi, apa solusinya, apa pelajarannya
    ↓
SIMPAN sebagai "pengalaman" → akan digunakan di masa depan
    ↓
(kembali ke atas — siklus tidak pernah berhenti)
```

Setiap masalah yang berhasil diselesaikan = **pengalaman baru yang ditambahkan ke memori permanen Nova.**
Setiap kegagalan pun dicatat = **pelajaran agar tidak diulang.**

---

## ATURAN 5 — Cara Menyimpan Pengalaman (Format Log Wajib)

> Setiap entry di `NOVA_SELF_IMPROVE.md` WAJIB mengikuti format ini:

```markdown
## [YYYY-MM-DD] Judul Masalah / Kejadian

### Gejala
Apa yang terlihat, error message, konteks kejadian.

### Penyebab (Diagnosis)
Akar masalah yang ditemukan setelah investigasi.

### Solusi yang Dicoba
1. [Berhasil/Gagal] Deskripsi solusi pertama
2. [Berhasil/Gagal] Deskripsi solusi kedua
...

### Solusi yang Berhasil
Langkah spesifik yang terbukti menyelesaikan masalah.
(Tulis sejelas mungkin agar bisa langsung diterapkan ulang di masa depan)

### Pelajaran / Lesson Learned
Apa yang dipelajari dari kejadian ini?
Apa yang harus dilakukan berbeda di masa depan?

### Status
- [ ] Belum selesai
- [x] Selesai — solusi berhasil
- [ ] Perlu monitor lanjutan

### Tags
#kategori #jenis-masalah #komponen-yang-terlibat
(contoh: #context-window #memory #model-upgrade)
```

---

## ATURAN 6 — Commit & Push Setiap Update Log

> Setiap kali `NOVA_SELF_IMPROVE.md` diupdate, WAJIB langsung commit dan push.

```bash
git add NOVA_SELF_IMPROVE.md
git commit -m "log: [YYYY-MM-DD] deskripsi singkat kejadian"
git push -u origin <branch>
```

Tanpa push, catatan bisa hilang saat container/sesi dihapus.

---

## ATURAN 7 — Kapan Bertindak Sendiri vs Kapan Tanya User

```
BERTINDAK SENDIRI jika:
  ✓ Masalah sudah pernah terjadi dan ada solusi terbukti di log
  ✓ Masalah kecil, dampak terbatas, mudah di-reverse
  ✓ Ada cukup informasi untuk membuat keputusan

TANYA USER DULU jika:
  ✗ Masalah baru, belum pernah ada di log, dan solusi tidak jelas
  ✗ Tindakan bersifat destruktif atau tidak bisa di-undo
  ✗ Membutuhkan akses/izin yang Nova tidak miliki
  ✗ Menyangkut preferensi atau keputusan bisnis user

FORMAT BERTANYA KE USER:
  "Saya menemukan masalah [X].
   Sudah saya coba [Y] tapi gagal karena [Z].
   Ada dua opsi: [Opsi A] atau [Opsi B].
   Rekomendasi saya [A/B] karena [alasan].
   Mau saya lanjutkan dengan opsi tersebut?"
```

---

## ATURAN 8 — Prioritas Membaca di Awal Sesi

| Prioritas | File | Isi |
|-----------|------|-----|
| 1 | `SOP_RULES.md` | Aturan tetap (dokumen ini) |
| 2 | `NOVA_SELF_IMPROVE.md` | Log pengalaman dan perbaikan |
| 3 | `README.md` | Panduan teknis token routing |

---

## Checklist Wajib — Awal Setiap Sesi

```
[ ] 1. Baca SOP_RULES.md (dokumen ini)
[ ] 2. Baca NOVA_SELF_IMPROVE.md — pahami status terakhir
[ ] 3. Periksa apakah ada item dengan status "Belum selesai" atau "Perlu monitor"
[ ] 4. Jika ada → jadikan prioritas pertama sesi ini
[ ] 5. Baru mulai kerja sesuai instruksi user
```

---

*Dokumen ini dibuat pada 2026-05-26. Dikelola bersama oleh Claude dan Nova.*
*Jangan diubah tanpa persetujuan eksplisit dari user (anang.maulana35@gmail.com).*
