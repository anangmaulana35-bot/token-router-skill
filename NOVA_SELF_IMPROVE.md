# Nova — Log Diagnosis & Perbaikan Diri

> **PENTING:** File ini adalah memori permanen Claude dan Nova.
> Baca file ini di awal setiap sesi baru. Lihat `SOP_RULES.md` untuk aturan lengkap.

---

## Cara Membaca Log Ini

- Entry terbaru ada di **paling atas**.
- Setiap entry mengikuti format standar dari `SOP_RULES.md`.
- Status `[x]` = sudah selesai, `[ ]` = masih perlu tindak lanjut.

---

---

## [2026-05-26] Error: Context Window Exceeded — Nova Tidak Bisa Memproses Pesan

### Gejala
```
[Error] Your input exceeds the context window of this model.
Please adjust your input and try again.
```
Error muncul berulang-ulang saat user Luna Malik mengirim pesan ke Nova.
Bahkan pesan pendek seperti "Profil luna Pin 2222" dan "Profil luna 2222"
tetap memicu error yang sama. Nova tidak bisa merespons sama sekali.

Terlihat di screenshot bahwa Nova menampilkan error ini minimal 3 kali berturut-turut
(pukul 22:56–22:58).

### Penyebab
1. **Riwayat percakapan menumpuk** — seluruh history chat dikirim ke model setiap request, total token terus bertambah hingga melampaui batas.
2. **Pinned Brief terlalu besar** — ada "Pinned Message" berisi `BRIEF_NOVA_UP...` yang ikut dikirim di setiap request dan memakan banyak token.
3. **Model context window tidak cukup** — model yang digunakan Nova kemungkinan memiliki context window kecil (8K–16K token).

### Tindakan Perbaikan

**Jangka Pendek (Langsung):**
- Reset/clear sesi percakapan Nova → mulai sesi baru tanpa history lama.
- Persingkat Pinned Brief menjadi maksimal 500–800 token.

**Jangka Menengah:**
- Implementasi **rolling summary**: setelah history > 60% context window, kompres otomatis menjadi ringkasan.
- Contoh kode:
```python
def compress_history(messages, threshold=0.6, max_tokens=8000):
    total = estimate_tokens(messages)
    if total > max_tokens * threshold:
        summary = summarize(messages[:-4])
        messages = [{"role": "system", "content": f"Ringkasan sebelumnya: {summary}"}] \
                   + messages[-4:]
    return messages
```

**Jangka Panjang:**
- Upgrade ke model dengan context window besar (Claude Sonnet/Opus = 200K token).
- Integrasikan token-router agar pesan ringan tidak membebani model kuat.
- Tambahkan aturan pencegahan otomatis:
  - >70% limit → auto-compress
  - >90% limit → auto-reset + simpan ringkasan

### Status
- [x] Diagnosa selesai
- [x] Instruksi perbaikan dicatat
- [ ] Implementasi compression di Nova — perlu dilakukan
- [ ] Verifikasi brief sudah diperpendek — perlu dicek
- [ ] Konfirmasi error tidak muncul lagi setelah perbaikan

### Catatan untuk Sesi Berikutnya
- Tanyakan ke user apakah brief Nova sudah diperpendek atau belum.
- Jika Nova masih error context window, langsung cek panjang brief yang di-pin.
- Model yang direkomendasikan: `claude-sonnet-4-6` (200K context).
- Jangan biarkan history percakapan Nova tumbuh tanpa batas — pastikan ada mekanisme compression.

---

*Log ini dikelola bersama oleh Claude dan Nova. Update terakhir: 2026-05-26.*
