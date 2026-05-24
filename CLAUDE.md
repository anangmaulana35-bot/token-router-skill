# LeanCtx — Panduan Claude

## Aturan Hemat Token

- Jawaban singkat dan padat. Tidak ada padding atau basa-basi.
- Gunakan bullet point untuk daftar, bukan paragraf panjang.
- Kode: tampilkan hanya bagian yang relevan, bukan file lengkap jika tidak diminta.
- Jangan ulangi pertanyaan pengguna sebelum menjawab.

## Cara Pakai LeanCtx

```python
from lean_ctx import LeanCtx

ctx = LeanCtx(token_budget=8192, system_prompt="Kamu asisten AI.")
ctx.add("user", "pertanyaan...")
messages = ctx.get_messages()  # sudah dikompres
stats = ctx.token_usage()       # lihat token yang dihemat
```

## Stack Token Optimization

1. **lean-ctx** — kompres context sebelum dikirim ke API
2. **RouteLLM** — routing ke model murah jika query sederhana
3. **Threshold 0.12** — 70–80% request pakai model lemah (haiku/mini)
