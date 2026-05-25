# NOVA — Error Log & Diagnosis

**Tanggal:** 2026-05-25
**Branch:** claude/nova-error-logs-H7IGB
**Sumber:** Screenshot chat Telegram Nova (11:39–11:45)

---

## Error yang Terdeteksi

### ERROR #1 — Stream Timeout (CRITICAL)

```
⌛ Still working... (3 min elapsed — iteration 1/90,
   waiting for stream response (150s, no chunks yet))
```

**Artinya:** Nova mengirim request ke LLM (strong model), tapi setelah **150 detik** tidak ada satu chunk pun yang balik. Ini bukan lambat — ini **hang total**.

**Root cause yang mungkin:**

| # | Kemungkinan | Indikasi |
|---|---|---|
| 1 | **API key habis / rate limit** | Provider menolak request, stream tidak pernah dibuka |
| 2 | **Timeout config terlalu pendek** di sisi client, lalu retry loop | `iteration 1/90` — berarti ada retry loop tapi chunk tidak pernah datang |
| 3 | **Network issue** antara Nova dan LLM provider | Request terkirim, response tidak balik |
| 4 | **Model overloaded** (provider side) | Stream dibuka tapi terhenti di awal |
| 5 | **Payload terlalu besar** (context overflow) | Provider choke sebelum stream dimulai |
| 6 | **Bug di streaming handler** | Stream dibuka, chunk datang, tapi tidak terdeteksi sebagai "chunks received" |

**Yang paling kritis:** `iteration 1/90` berarti Nova akan loop sampai 90x — kalau tidak ada circuit breaker yang proper, ini bisa habiskan semua token/quota sebelum user tahu ada masalah.

---

### ERROR #2 — Mock ASR Provider (HIGH)

```
Audio diterima oleh provider mock.
Transkrip penuh membutuhkan provider ASR yang diaktifkan,
tetapi file sudah tervalidasi dan siap diproses.
```

**Artinya:** Nova menerima voice message (audio), tapi ASR (Automatic Speech Recognition / speech-to-text) yang aktif adalah **mock provider** — bukan provider nyata. Akibatnya: audio tidak ditranskrip, Nova tidak bisa baca isi pesan suara.

**Root cause yang mungkin:**

| # | Kemungkinan | Indikasi |
|---|---|---|
| 1 | **ASR provider tidak dikonfigurasi** di environment | Env var `ASR_PROVIDER` kosong atau fallback ke mock |
| 2 | **API key ASR tidak di-set** (Whisper/Google STT/Deepgram) | Provider dideteksi tapi auth gagal → fallback mock |
| 3 | **Feature flag ASR dimatikan** | Config `asr_enabled: false` atau serupa |
| 4 | **Dependency ASR tidak terinstall** | Library Whisper / SDK tidak ada di environment |

---

## Timeline Error (dari screenshot)

```
11:39 — Nova menerima voice message (0:06)
11:42 — Nova masih "working..." — 3 menit elapsed, iteration 1/90, stream timeout 150s
11:44 — Nova menerima voice message ke-2 (0:03) → Mock ASR response
11:44 — Nova menerima voice message ke-3 (0:05) → Mock ASR response
11:44 — ⚡ Interrupt otomatis setelah 5 menit (iterasi masih 1/90)
11:45 — Mock ASR response lagi untuk pesan terakhir
```

**Pattern:** Nova terjebak di stream timeout 150s → tidak kunjung dapat response → tetap di iterasi 1, tidak pernah maju → user kirim voice message lain yang semua jatuh ke mock ASR → Nova akhirnya di-interrupt paksa.

---

## Fix yang Diperlukan

### Fix #1 — Stream Timeout

**Langsung:**
```python
# Cek dulu apakah API key valid
import anthropic
client = anthropic.Anthropic(api_key=os.getenv("ANTHROPIC_API_KEY"))
# Test dengan request kecil dulu
response = client.messages.create(
    model="claude-haiku-4-5",
    max_tokens=10,
    messages=[{"role": "user", "content": "ping"}]
)
```

**Konfigurasi yang harus diperbaiki:**
```python
# stream_handler.py — tambahkan timeout + circuit breaker

MAX_STREAM_WAIT_SECONDS = 30       # bukan 150
MAX_ITERATIONS = 3                  # bukan 90 — fail fast
CIRCUIT_BREAKER_THRESHOLD = 2       # 2x gagal → stop, report ke user

async def stream_with_timeout(client, params, timeout=30):
    try:
        async with asyncio.timeout(timeout):
            async with client.messages.stream(**params) as stream:
                async for chunk in stream:
                    yield chunk
    except asyncio.TimeoutError:
        raise StreamTimeoutError(f"No response after {timeout}s — check API key and quota")
```

**Root fix:**
1. Turunkan `MAX_STREAM_WAIT` dari 150s → 30s
2. Turunkan `MAX_ITERATIONS` dari 90 → 3 (retry 3x cukup)
3. Tambah circuit breaker: kalau 2x timeout berturut-turut → stop loop, kirim error ke user
4. Tambah fallback ke weak model kalau strong model timeout
5. Log error ke audit trail tiap timeout (sesuai rekomendasi NOVA_AUDIT.md #S5)

---

### Fix #2 — ASR Provider

**Cek environment:**
```bash
# Cek apakah provider ASR sudah di-set
echo $ASR_PROVIDER          # harus: whisper / deepgram / google_stt / dll
echo $OPENAI_API_KEY        # kalau pakai Whisper via OpenAI
echo $DEEPGRAM_API_KEY      # kalau pakai Deepgram
```

**Konfigurasi yang harus diperbaiki:**
```python
# asr_config.py

ASR_PROVIDER = os.getenv("ASR_PROVIDER", "mock")  # ← INI MASALAHNYA
# Kalau env var tidak di-set, fallback ke mock

# Fix: raise error kalau provider tidak dikonfigurasi
ASR_PROVIDER = os.getenv("ASR_PROVIDER")
if not ASR_PROVIDER or ASR_PROVIDER == "mock":
    raise ConfigurationError(
        "ASR_PROVIDER tidak dikonfigurasi. "
        "Set env var: ASR_PROVIDER=whisper|deepgram|google_stt"
    )
```

**Opsi ASR yang bisa dipakai:**

| Provider | Setup | Kualitas | Harga |
|---|---|---|---|
| **OpenAI Whisper** (rekomendasi) | `OPENAI_API_KEY` sudah ada | Sangat baik, multi-bahasa | ~$0.006/menit |
| **Deepgram** | `DEEPGRAM_API_KEY` baru | Real-time, cepat | Free tier 200 jam |
| **Google STT** | GCP credentials | Bagus untuk Bahasa Indonesia | Pay per use |

**Quick fix pakai Whisper:**
```python
import openai

def transcribe_audio(audio_file_path: str) -> str:
    client = openai.OpenAI(api_key=os.getenv("OPENAI_API_KEY"))
    with open(audio_file_path, "rb") as f:
        transcript = client.audio.transcriptions.create(
            model="whisper-1",
            file=f,
            language="id"  # Bahasa Indonesia
        )
    return transcript.text
```

---

## Checklist Perbaikan

- [ ] **Cek API key** LLM provider (Anthropic / OpenAI) — minta quota atau rotate key kalau habis
- [ ] **Set `ASR_PROVIDER`** di environment (bukan mock)
- [ ] **Turunkan `MAX_STREAM_WAIT`** dari 150s → 30s
- [ ] **Turunkan `MAX_ITERATIONS`** dari 90 → 3
- [ ] **Tambah circuit breaker** — stop otomatis kalau 2x timeout, kirim notif ke user
- [ ] **Tambah fallback ke weak model** kalau strong model tidak response
- [ ] **Tambah audit log** untuk setiap timeout event (sesuai NOVA_AUDIT.md prioritas #4)
- [ ] **Test voice message** setelah ASR dikonfigurasi

---

## Dampak ke Pengguna

Selama dua error ini aktif:
- Nova tidak bisa baca voice message (semua jatuh ke mock → tidak ditranskrip)
- Nova akan hang 5 menit+ setiap ada request ke LLM sebelum di-interrupt
- User terpaksa kirim ulang pesan atau tunggu timeout — **UX sangat buruk**

**Priority:** Perbaiki Error #2 (ASR) lebih dulu karena lebih mudah — cukup set env var. Lalu perbaiki Error #1 (stream timeout) dengan turunkan limit dan tambah circuit breaker.

---

## Referensi

- Audit lengkap Nova → `NOVA_AUDIT.md` (branch `claude/nova-orchestrator-audit-ek6jn`)
- Risk S5 (tidak ada audit log) → relevan untuk debugging error ini
- Risk M1 (tidak ada memory architecture) → Nova reset context tiap sesi, perlu diaddress terpisah
