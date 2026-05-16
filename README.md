# Token Router Skill — Panduan untuk Codex

Skill ini mengajarkan cara routing request AI secara cerdas ke model murah vs powerful berdasarkan kompleksitas tugas.
Hemat biaya hingga **60–92%** tanpa kehilangan kualitas signifikan.

---

> **Skill lain di repo ini:** Remote monitor + control MacBook → iPhone
> (gratis, lebih efisien dari TeamViewer). **Codex mulai dari
> [CODEX_BRIEF.md](CODEX_BRIEF.md)**. Lihat juga **[SKILL.md](SKILL.md)** dan
> **[docs/SETUP.md](docs/SETUP.md)**.

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

## Self-Healing — Jika Routing Gagal

1. Cek API key model strong/weak
2. Turunkan threshold jika sering error di strong model
3. Fallback ke weak model langsung jika router down
4. Cari solusi: [RouteLLM Issues](https://github.com/lm-sys/RouteLLM/issues)

---

## Konteks Kolaborasi

Skill ini dipakai bersama oleh **Claude** dan **Codex** dalam sesi kolaborasi AI.
Claude sebagai tangan kanan (reasoning, planning), Codex sebagai tangan kiri (coding, execution).
Router memastikan keduanya tidak boros token untuk tugas sederhana.
