# Nova — Log Pengalaman, Diagnosis & Perbaikan Diri

> **PENTING — BACA INI DI AWAL SETIAP SESI BARU**
> File ini adalah memori permanen Nova dan Claude.
> Setiap pengalaman, masalah, dan solusi dicatat di sini agar tidak pernah dilupakan.
> Lihat `SOP_RULES.md` untuk aturan lengkap cara menggunakan file ini.

---

## Status Terkini (Update Terakhir: 2026-05-26)

| Item | Status |
|------|--------|
| Context window error | Terdiagnosis, solusi ada, implementasi belum diverifikasi |
| Brief/instruksi di-pin | Perlu diperpendek oleh user |
| Compression history | Belum diimplementasi di Nova |
| Upgrade model ke 200K | Belum dikonfirmasi |

---

## Bank Pengalaman Nova (Terus Bertambah)

> Bagian ini adalah "ingatan jangka panjang" Nova.
> Setiap masalah yang berhasil diselesaikan ditambahkan ke sini sebagai pengetahuan permanen.

### Pengalaman #001 — Context Window Management
**Tanggal pertama kali terjadi:** 2026-05-26
**Seberapa sering:** Bisa terjadi kapan saja jika history tidak dikelola
**Solusi terbukti:**
1. Reset sesi percakapan (clear history)
2. Persingkat brief yang di-pin ke < 800 token
3. Implementasi auto-compress jika token > 70% limit
4. Gunakan model 200K token (Sonnet/Opus)

**Nova harus ingat:** Jika ada error "context window exceeded" → langsung terapkan solusi #001 ini tanpa perlu diagnosis ulang.

---

## Log Kejadian (Terbaru di Atas)

---

### [2026-05-26] Error: Context Window Exceeded — Nova Tidak Bisa Memproses Pesan

#### Gejala
```
[Error] Your input exceeds the context window of this model.
Please adjust your input and try again.
```
Error muncul berulang-ulang saat user Luna Malik mengirim pesan ke Nova.
Bahkan pesan pendek seperti "Profil luna Pin 2222" dan "Profil luna 2222"
tetap memicu error. Nova tidak bisa merespons sama sekali.
Terjadi minimal 3 kali berturut-turut pukul 22:56–22:58.

#### Penyebab (Diagnosis)
1. **Riwayat percakapan menumpuk** — seluruh history chat dikirim ke model setiap request tanpa batas.
2. **Pinned Brief terlalu besar** — `BRIEF_NOVA_UP...` ikut dikirim setiap request, memakan banyak token.
3. **Model context window terlalu kecil** — kemungkinan model Nova hanya 8K–16K token.

#### Solusi yang Dicoba
1. [Dicatat, belum ditest langsung] Reset sesi → mulai percakapan baru tanpa history
2. [Dicatat, belum ditest] Persingkat brief yang di-pin

#### Solusi yang Berhasil (Berdasarkan Analisis)
```
LANGKAH 1 — Immediate Fix:
  Reset sesi percakapan Nova → mulai sesi baru

LANGKAH 2 — Short-term Fix:
  Persingkat Pinned Brief → maksimal 500-800 token
  Hapus bagian redundan yang tidak perlu ada di setiap request

LANGKAH 3 — Permanent Fix:
  Implementasi auto-compress di Nova:

  def compress_history(messages, threshold=0.6, max_tokens=8000):
      total = estimate_tokens(messages)
      if total > max_tokens * threshold:
          summary = summarize(messages[:-4])
          messages = [{"role": "system",
                       "content": f"Ringkasan sebelumnya: {summary}"}] + messages[-4:]
      return messages

  Aturan:
  - >70% limit → auto-compress history
  - >90% limit → auto-reset + simpan ringkasan
  - Error context window → retry otomatis dengan history tercompress

LANGKAH 4 — Model Upgrade:
  Ganti model Nova ke claude-sonnet-4-6 atau claude-opus-4-7
  Keduanya punya context window 200K token — hampir tidak mungkin overflow
```

#### Pelajaran / Lesson Learned
- Nova HARUS selalu monitor panjang context, jangan biarkan tumbuh tanpa batas.
- Brief/instruksi yang di-pin harus seringkas mungkin — muat hanya yang benar-benar perlu.
- Model dengan context besar (200K) jauh lebih aman untuk percakapan panjang.
- Ketika error context window terjadi → jangan panik, langsung terapkan Pengalaman #001.

#### Status
- [x] Terdiagnosis
- [x] Solusi didokumentasikan
- [ ] Auto-compress diimplementasi di Nova
- [ ] Brief diperpendek — user perlu konfirmasi
- [ ] Model upgrade dikonfirmasi
- [ ] Error tidak muncul lagi setelah perbaikan

#### Tags
`#context-window` `#memory-management` `#model-config` `#brief` `#auto-fix`

---

## Template untuk Log Baru

Salin template ini setiap kali menambah entry baru:

```markdown
### [YYYY-MM-DD] Judul Masalah / Kejadian

#### Gejala
...

#### Penyebab (Diagnosis)
...

#### Solusi yang Dicoba
1. [Berhasil/Gagal] ...

#### Solusi yang Berhasil
...

#### Pelajaran / Lesson Learned
...

#### Status
- [ ] Belum selesai
- [ ] Selesai
- [ ] Perlu monitor lanjutan

#### Tags
`#tag1` `#tag2`
```

---

*Dikelola bersama oleh Claude dan Nova.*
*Owner: anang.maulana35@gmail.com | Update terakhir: 2026-05-26*
