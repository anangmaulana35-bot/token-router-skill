# Nova — Catatan Perbaikan Diri (Self-Improve Log)

Dokumen ini berisi instruksi dan catatan untuk Nova agar bisa mendiagnosis
dan memperbaiki dirinya sendiri tanpa perlu intervensi manual.

---

## [2026-05-26] Error: Context Window Exceeded

### Gejala
```
[Error] Your input exceeds the context window of this model.
Please adjust your input and try again.
```
Error ini muncul berulang kali saat Nova diajak bicara, bahkan untuk pesan pendek sekalipun.

### Penyebab (Diagnosis)

1. **Riwayat percakapan terlalu panjang** — setiap request mengirim seluruh history chat ke model, sehingga token terus menumpuk.
2. **Pinned Brief terlalu besar** — instruksi/brief yang di-pin (BRIEF_NOVA_UP...) ikut dikirim di setiap request dan memakan banyak token.
3. **Model context window terlalu kecil** — model yang dipakai Nova mungkin hanya mendukung context pendek (misal 8K–16K token).

### Instruksi Perbaikan (Self-Fix Steps)

#### Langkah 1 — Reset Context
- Mulai sesi percakapan baru (clear/reset history).
- Jangan bawa history lama ke sesi baru kecuali benar-benar diperlukan.

#### Langkah 2 — Persingkat Brief / Instruksi
- Audit panjang brief yang di-pin. Targetkan maksimal **500–800 token**.
- Hapus bagian yang redundan atau jarang dipakai.
- Pisahkan brief menjadi modul kecil, muat hanya yang relevan per sesi.

#### Langkah 3 — Aktifkan Context Compression
- Gunakan teknik **rolling summary**: setelah N pesan, rangkum history lama
  menjadi 1–2 paragraf ringkasan, lalu ganti history dengan ringkasan itu.
- Contoh trigger: jika total token history > 60% dari context window, auto-compress.

```python
# Contoh logika compression sederhana
def compress_history(messages, threshold=0.6, max_tokens=8000):
    total = estimate_tokens(messages)
    if total > max_tokens * threshold:
        summary = summarize(messages[:-4])   # ringkas semua kecuali 4 pesan terakhir
        messages = [{"role": "system", "content": f"Ringkasan sebelumnya: {summary}"}] \
                   + messages[-4:]
    return messages
```

#### Langkah 4 — Upgrade Model Context Window
- Jika error masih terjadi setelah compression, pertimbangkan pindah ke model
  dengan context window lebih besar:

| Model               | Context Window |
|---------------------|---------------|
| claude-haiku-4-5    | 200K token    |
| claude-sonnet-4-6   | 200K token    |
| claude-opus-4-7     | 200K token    |

- Update `config.json` Nova:
```json
{
  "model": "claude-sonnet-4-6",
  "max_context_tokens": 180000,
  "auto_compress_threshold": 0.7
}
```

#### Langkah 5 — Integrasikan dengan Token Router
- Gunakan skill `token-router` agar pesan sederhana tidak membebani model kuat.
- Pesan ringan (salam, jawaban pendek) → weak model (Haiku).
- Pesan kompleks (analisis, coding, multi-step) → strong model (Sonnet/Opus).
- Ini otomatis mengurangi beban context pada model kuat.

---

## Aturan Pencegahan (Prevention Rules)

Nova HARUS menjalankan cek berikut sebelum setiap request:

```
1. Hitung estimasi total token (history + brief + pesan baru).
2. Jika > 70% dari max context → jalankan compression dulu.
3. Jika > 90% dari max context → reset history, simpan ringkasan.
4. Jika error context window terjadi → otomatis retry dengan history yang sudah dicompress.
5. Jangan pernah mengirim raw history tanpa batas.
```

---

## Referensi

- [Anthropic Context Window Docs](https://docs.anthropic.com/en/docs/about-claude/models)
- [RouteLLM untuk token routing](https://github.com/lm-sys/RouteLLM)
- Skill terkait: `token-router-skill` (repo ini)
