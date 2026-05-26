# Token Router Skill — Panduan untuk Codex

Skill ini mengajarkan cara routing request AI secara cerdas ke model murah vs powerful berdasarkan kompleksitas tugas.
Hemat biaya hingga **60–92%** tanpa kehilangan kualitas signifikan.

---

## Pilihan Router

| Router | Repo | Keunggulan |
|--------|------|------------|
| **RouteLLM** (rekomendasi) | [lm-sys/RouteLLM](https://github.com/lm-sys/RouteLLM) | Open-source, 4 router siap pakai, kompatibel OpenAI API |
| **LLMRouter** | [ulab-uiuc/LLMRouter](https://github.com/ulab-uiuc/LLMRouter) | 16+ routing model, multi-round, agentic, personalized |
| **ClawRouter** | [BlockRunAI/ClawRouter](https://github.com/BlockRunAI/ClawRouter) | 41+ model, routing <1ms, hemat 92% vs Claude Opus |

---

## Instalasi

```bash
pip install routellm
```

---

## Cara Pakai — RouteLLM

```python
from routellm.controller import Controller

client = Controller(
    routers=["mf"],          # matrix factorization (terbaik)
    strong_model="gpt-4o",
    weak_model="gpt-4o-mini",
)

response = client.chat.completions.create(
    model="router-mf-0.11856",  # threshold 0.0–1.0
    messages=[{"role": "user", "content": "pertanyaanmu di sini"}]
)
```

### Threshold

```
0.0  → selalu pakai model lemah (paling hemat)
1.0  → selalu pakai model kuat (paling akurat)
0.11 → sweet spot: 70–80% request ke model lemah
```

---

## Cara Pakai — LLMRouter (Agentic/Multi-round)

```bash
pip install llmrouter
```

```python
from llmrouter import Router

router = Router(
    mode="agentic",   # single_round | multi_round | agentic | personalized
    strong_model="claude-opus-4-7",
    weak_model="claude-haiku-4-5"
)

result = router.route("tugas coding kompleks ini...")
```

---

## Router yang Tersedia di RouteLLM

| Kode | Nama | Keterangan |
|------|------|------------|
| `mf` | Matrix Factorization | Terbaik, direkomendasikan |
| `sw_ranking` | SW Ranking (Elo) | Cepat, berbasis preferensi |
| `bert` | BERT Classifier | Berbasis NLP |
| `causal_llm` | Causal LLM | Paling akurat, LLM-based |

---

## Kapan Pakai Router

- **Gunakan** — banyak request campuran (simple + complex)
- **Skip** — semua request butuh model terkuat (debugging critical)
- **Sweet spot** — 70–80% request bisa dihandle model lemah

---

## Konfigurasi Lokal (config.json)

```json
{
  "router": "mf",
  "strong_model": "claude-opus-4-7",
  "weak_model": "claude-haiku-4-5",
  "threshold": 0.12,
  "fallback": "weak"
}
```

---

## Fix Error "Missing model" (CodexClientError 4)

Error ini muncul saat request ke API tidak menyertakan field `model`.

**Penyebab:**  
`client.messages.create()` dipanggil tanpa parameter `model`.

**Fix — selalu sertakan `model`:**

```python
response = client.messages.create(
    model="claude-haiku-4-5-20251001",   # ← wajib ada
    max_tokens=1024,
    messages=messages,
)
```

**Atau pakai `router.py` yang sudah include fix ini:**

```python
from router import chat

reply = chat([{"role": "user", "content": "Halo"}])
```

---

## Self-Healing — Jika Routing Gagal

1. Cek API key model strong/weak
2. Turunkan threshold jika sering error di strong model
3. Fallback ke weak model langsung jika router down
4. Pastikan `model` selalu di-set — lihat bagian Fix di atas
5. Cari solusi: [RouteLLM Issues](https://github.com/lm-sys/RouteLLM/issues)

---

## Konteks Kolaborasi

Skill ini dipakai bersama oleh **Claude** dan **Codex** dalam sesi kolaborasi AI.
Claude sebagai tangan kanan (reasoning, planning), Codex sebagai tangan kiri (coding, execution).
Router memastikan keduanya tidak boros token untuk tugas sederhana.
