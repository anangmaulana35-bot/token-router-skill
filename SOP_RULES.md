# SOP — Aturan Tetap untuk Claude & Nova

Dokumen ini adalah **hukum utama** yang WAJIB dibaca di awal setiap sesi baru,
baik oleh Claude maupun Nova, tanpa terkecuali.

---

## ATURAN 1 — Baca Log di Awal Setiap Sesi

> **Setiap kali sesi baru dimulai (Claude atau Nova), langkah PERTAMA adalah:**
> membaca file `NOVA_SELF_IMPROVE.md` untuk mengetahui konteks sebelumnya.

```
WAJIB BACA SEBELUM MULAI KERJA:
→ NOVA_SELF_IMPROVE.md   (log semua kejadian, diagnosis, perbaikan)
→ SOP_RULES.md           (dokumen ini — aturan tetap)
```

Tujuannya:
- Selalu tahu apa yang terjadi di sesi sebelumnya.
- Tidak mengulangi kesalahan yang sudah pernah terjadi.
- Menjaga kontinuitas konteks meski sesi baru atau model berbeda.

---

## ATURAN 2 — Catat Setiap Diagnosis dan Perbaikan

> **Setiap kali ada masalah yang didiagnosis atau diperbaiki pada Nova atau sistem,
> WAJIB dicatat di `NOVA_SELF_IMPROVE.md` sebelum sesi berakhir.**

Format log yang harus diikuti:

```markdown
## [YYYY-MM-DD] Judul Masalah

### Gejala
Deskripsi apa yang terlihat / error message yang muncul.

### Penyebab
Hasil diagnosis — apa akar masalahnya.

### Tindakan Perbaikan
Langkah-langkah yang sudah dilakukan untuk memperbaiki.

### Status
- [ ] Belum selesai
- [x] Sudah selesai
- [ ] Perlu monitor lebih lanjut

### Catatan Tambahan
Hal-hal yang perlu diingat untuk sesi berikutnya.
```

---

## ATURAN 3 — Commit & Push Setiap Update Log

> **Setiap kali `NOVA_SELF_IMPROVE.md` diupdate, WAJIB langsung commit dan push.**

Ini memastikan log tersimpan permanen di GitHub dan bisa diakses kapan saja,
bahkan setelah container/sesi dihapus.

```bash
git add NOVA_SELF_IMPROVE.md
git commit -m "log: [tanggal] deskripsi singkat kejadian"
git push -u origin <branch>
```

---

## ATURAN 4 — Prioritas Membaca

Urutan file yang harus dibaca di awal sesi (dari yang paling penting):

| Prioritas | File | Isi |
|-----------|------|-----|
| 1 | `SOP_RULES.md` | Aturan tetap (dokumen ini) |
| 2 | `NOVA_SELF_IMPROVE.md` | Log semua kejadian dan perbaikan |
| 3 | `README.md` | Panduan teknis token routing |

---

## ATURAN 5 — Jangan Mulai Kerja Sebelum Tahu Konteks

> Jika belum membaca log, **jangan langsung eksekusi** instruksi apapun.
> Baca dulu, pahami konteks, baru bertindak.

Ini mencegah:
- Melakukan perbaikan yang sudah pernah dilakukan sebelumnya.
- Mengulang kesalahan lama.
- Kehilangan konteks kolaborasi antara Claude dan Nova.

---

## Ringkasan Checklist Awal Sesi

```
[ ] 1. Baca SOP_RULES.md (dokumen ini)
[ ] 2. Baca NOVA_SELF_IMPROVE.md (log terbaru)
[ ] 3. Pahami status terakhir: apa yang sedang dikerjakan, apa yang belum selesai
[ ] 4. Baru mulai kerja
```

---

*Dokumen ini dibuat pada 2026-05-26. Jangan diubah tanpa persetujuan eksplisit.*
