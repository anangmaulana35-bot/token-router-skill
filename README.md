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

## Self-Healing — Jika Routing Gagal

1. Cek API key model strong/weak
2. Turunkan threshold jika sering error di strong model
3. Fallback ke weak model langsung jika router down
4. Cari solusi: [RouteLLM Issues](https://github.com/lm-sys/RouteLLM/issues)

---

## Cara Pakai Gemini 3.5 Flash di Agent (ClawRouter / Hermes-style)

### Mengapa Gemini 3.5 Flash?

| Metrik | Gemini 3.5 Flash | Claude Haiku 4.5 | GPT-4o Mini |
|--------|-----------------|-----------------|-------------|
| Latensi | ~500ms | ~600ms | ~700ms |
| Harga input | $0.075/M token | $0.08/M token | $0.15/M token |
| Tool use | Ya | Ya | Ya |
| Konteks | 1M token | 200K token | 128K token |

Ideal sebagai **weak model** di router — tangani 70–80% request sederhana dengan biaya minimal.

---

### 1. Pakai via LiteLLM (universal adapter)

LiteLLM membungkus Gemini agar kompatibel dengan format OpenAI — cocok untuk semua framework agent.

```bash
pip install litellm
```

```python
import os
import litellm

os.environ["GEMINI_API_KEY"] = "your-google-ai-studio-key"

response = litellm.completion(
    model="gemini/gemini-3.5-flash",
    messages=[{"role": "user", "content": "Tulis fungsi Python untuk sorting"}],
)
print(response.choices[0].message.content)
```

---

### 2. Pakai di RouteLLM (routing otomatis)

```python
from routellm.controller import Controller
import litellm

client = Controller(
    routers=["mf"],
    strong_model="claude-opus-4-8",        # model kuat — tugas kompleks
    weak_model="gemini/gemini-3.5-flash",  # Gemini Flash — tugas ringan
)

response = client.chat.completions.create(
    model="router-mf-0.11856",
    messages=[{"role": "user", "content": "pertanyaanmu di sini"}]
)
```

---

### 3. Pakai di ClawRouter (41+ model, <1ms routing)

ClawRouter dari [BlockRunAI](https://github.com/BlockRunAI/ClawRouter) mendukung Gemini natively.

```python
from clawrouter import ClawRouter

router = ClawRouter(
    strong_model="claude-opus-4-8",
    weak_model="gemini-3.5-flash",   # identifier native ClawRouter
    provider_weak="google",
    threshold=0.15,
)

result = router.chat("Jelaskan konsep recursion secara singkat")
```

---

### 4. Pakai di Agent Hermes-style (tool use / function calling)

Hermes mengacu pada pola agent dengan function calling. Gemini 3.5 Flash mendukung tool use penuh:

```python
import google.generativeai as genai

genai.configure(api_key="your-google-ai-studio-key")

tools = [
    {
        "function_declarations": [
            {
                "name": "get_weather",
                "description": "Ambil cuaca kota tertentu",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "city": {"type": "string", "description": "Nama kota"},
                    },
                    "required": ["city"],
                },
            }
        ]
    }
]

model = genai.GenerativeModel("gemini-3.5-flash", tools=tools)
chat = model.start_chat()

response = chat.send_message("Cuaca Jakarta hari ini?")

# Cek apakah model memanggil tool
if response.candidates[0].content.parts[0].function_call:
    fc = response.candidates[0].content.parts[0].function_call
    print(f"Tool dipanggil: {fc.name}, args: {dict(fc.args)}")
```

---

### 5. Integrasi di config.json Token Router

```json
{
  "router": "mf",
  "strong_model": "claude-opus-4-8",
  "weak_model": "gemini/gemini-3.5-flash",
  "weak_model_provider": "google",
  "threshold": 0.12,
  "fallback": "weak"
}
```

---

### Tips Praktis

- **API Key**: Daftar di [Google AI Studio](https://aistudio.google.com) → gratis tier tersedia
- **Konteks panjang**: Gemini 3.5 Flash unggul untuk dokumen besar (1M token context)
- **Threshold**: Mulai dari `0.12`; naikkan jika weak model sering gagal
- **Tool use**: Gunakan format `google.generativeai` langsung, atau LiteLLM untuk unified API

---

## Konteks Kolaborasi

Skill ini dipakai bersama oleh **Claude** dan **Codex** dalam sesi kolaborasi AI.
Claude sebagai tangan kanan (reasoning, planning), Codex sebagai tangan kiri (coding, execution).
Router memastikan keduanya tidak boros token untuk tugas sederhana.
