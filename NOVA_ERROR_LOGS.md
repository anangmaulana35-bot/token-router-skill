# NOVA — Error Log & Diagnosis

**Tanggal:** 2026-05-25
**Branch:** claude/nova-error-logs-H7IGB
**Sumber:** Screenshot chat Telegram Nova (11:39–11:49) — update v2

---

## Error yang Terdeteksi

### ERROR #1 — Stream Timeout + Multiple Instance Conflict (CRITICAL)

```
⌛ 11:42 — Still working... (3 min elapsed — iteration 1/90, waiting for stream response (150s, no chunks yet))
⌛ 11:45 — Still working... (6 min elapsed — iteration 1/90, waiting for provider response (streaming))
⌛ 11:47 — Still working... (3 min elapsed — iteration 1/90, waiting for stream response (150s, no chunks yet))
⌛ 11:48 — Still working... (9 min elapsed — iteration 1/90, waiting for stream response (181s, no chunks yet))
```

**Artinya:** Nova mengirim request ke LLM, tapi tidak ada satu chunk pun yang balik. Yang kritis: timeout **makin naik** (150s → 181s) dan tidak pernah keluar dari iteration 1 — ini bukan sekedar lambat, ini **hang dan tidak recovery**.

**Root cause UTAMA yang sudah dikonfirmasi Nova sendiri:**

**→ Telegram polling conflict: multiple instance Nova berjalan bersamaan**

Nova melaporkan 12+ warning `Conflict: terminated by other getUpdates request`. Ini terjadi karena lebih dari satu proses Nova aktif sekaligus — semua saling rebut Telegram update, dan semua mencoba call LLM secara paralel. Akibatnya:
- LLM provider dibanjiri request dari instance yang sama
- Tiap instance tidak dapat response karena instance lain "mencuri" context atau slot
- Timeout terus naik karena request menumpuk di antrian provider

**Nova berjalan di macOS lokal** via LaunchAgents (`launchctl`) — hanya 3 LaunchAgent terdaftar, tapi kemungkinan ada zombie process dari restart/crash sebelumnya yang tidak ter-kill bersih.

**Root cause sekunder:**

| # | Kemungkinan | Indikasi |
|---|---|---|
| 1 | **Multiple bot instance** | 12+ polling conflict warning — **TERKONFIRMASI** |
| 2 | **Zombie process dari crash** | LaunchAgent restart tidak kill process lama |
| 3 | **API key / rate limit** | Kemungkinan provider throttle karena banjir request |
| 4 | **Network issue** | Mungkin tapi bukan penyebab utama |

**Catatan penting — Patch v5:**
Nova menjelaskan bahwa **patch v5** (`progress_reply di-skip`) adalah **bukan bug** — ini efek yang disengaja. Sebelum patch v5, Nova kirim "Task diterima... iteration 24/90" sebagai feedback progres. Setelah patch v5, Nova langsung eksekusi tanpa intro. Ini membuat user lihat "typing" lama lalu tiba-tiba hasil, yang terasa seperti hang padahal Nova sedang bekerja.

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
11:42 — Nova still working — 3 min elapsed, iteration 1/90, stream timeout 150s (no chunks)
11:44 — Nova menerima voice message ke-2 (0:03) → Mock ASR response
11:44 — Nova menerima voice message ke-3 (0:05) → Mock ASR response
11:44 — ⚡ Interrupt otomatis setelah 5 menit (iterasi masih 1/90)
11:45 — Mock ASR response lagi untuk pesan terakhir
11:45 — Still working — 6 min elapsed, iteration 1/90, waiting for provider response (streaming)
11:47 — Still working — 3 min elapsed lagi, iteration 1/90, stream timeout 150s (no chunks)
11:48 — Still working — 9 min elapsed, iteration 1/90, stream timeout 181s (no chunks) ← MAKIN PARAH
```

**Pattern:** Multiple instance saling konflik → semua stuck di iteration 1 → timeout naik terus → user kirim voice message baru tapi semua masuk mock ASR → Nova tidak pernah resolve task apapun selama 10+ menit.

**Mengapa timeout naik (150s → 181s)?** Karena request dari instance-instance sebelumnya menumpuk di antrian LLM provider. Semakin lama, semakin banyak request pending, semakin lama tunggu slot.

---

## Fix yang Diperlukan

### Fix #1 — Hentikan Multiple Instance (PRIORITAS PERTAMA)

**Ini harus dilakukan sebelum fix lain apapun.** Selama ada multiple instance, semua fix lain tidak akan efektif.

```bash
# 1. Cek semua proses Nova yang berjalan
ps aux | grep -i nova | grep -v grep
ps aux | grep -i telegram | grep -v grep
ps aux | grep -i bot | grep -v grep

# 2. Kill semua instance
pkill -f "nova"
pkill -f "telegram"

# 3. Cek LaunchAgents yang aktif
launchctl list | grep -i nova

# 4. Unload semua LaunchAgent Nova
launchctl unload ~/Library/LaunchAgents/com.nova*.plist

# 5. Tunggu 5 detik, lalu load ulang SATU instance saja
sleep 5
launchctl load ~/Library/LaunchAgents/com.nova.main.plist  # atau nama yang benar

# 6. Verifikasi hanya 1 instance berjalan
ps aux | grep -i nova | grep -v grep
```

**Perbaikan permanen — singleton lock:**
```python
# bot_main.py — tambahkan di awal startup

import fcntl
import sys

LOCK_FILE = "/tmp/nova_bot.lock"

def acquire_singleton_lock():
    lock = open(LOCK_FILE, "w")
    try:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        return lock
    except IOError:
        print("ERROR: Nova bot sudah berjalan. Hentikan instance lama dulu.")
        sys.exit(1)

lock = acquire_singleton_lock()  # panggil sebelum polling dimulai
```

---

### Fix #2 — Stream Timeout Config

Setelah instance dibersihkan, turunkan batas timeout agar recovery lebih cepat:

```python
# stream_handler.py

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
        raise StreamTimeoutError(f"No response after {timeout}s")
```

**Langkah tambahan:**
1. Turunkan `MAX_STREAM_WAIT` dari 150s → 30s
2. Turunkan `MAX_ITERATIONS` dari 90 → 3
3. Tambah circuit breaker: 2x timeout → stop, kirim pesan error ke user
4. Tambah fallback ke weak model kalau strong model timeout
5. Log setiap timeout ke audit trail (sesuai NOVA_AUDIT.md #S5)

---

### Fix #3 — Watchdog Script (untuk LaunchAgent)

Nova sendiri sudah mendeteksi perlu dibuat watchdog script. Ini mencegah zombie process saat restart:

```bash
#!/bin/bash
# nova_watchdog.sh — jalankan via LaunchAgent terpisah

BOT_SCRIPT="/Users/anangmaulana/Documents/nova/bot_main.py"
LOCK_FILE="/tmp/nova_bot.lock"
LOG_FILE="/tmp/nova_watchdog.log"

while true; do
    # Cek apakah bot berjalan
    if ! pgrep -f "bot_main.py" > /dev/null; then
        echo "$(date): Nova tidak berjalan, restart..." >> "$LOG_FILE"
        # Bersihkan lock file stale
        rm -f "$LOCK_FILE"
        # Start bot
        cd /Users/anangmaulana/Documents/nova
        python3 "$BOT_SCRIPT" &
    fi
    sleep 30
done
```

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

## Checklist Perbaikan (urut prioritas)

### Langsung sekarang (< 5 menit)
- [ ] **Kill semua instance Nova** — `pkill -f nova` lalu `launchctl unload` semua plist
- [ ] **Start ulang SATU instance** — verifikasi hanya 1 proses berjalan
- [ ] **Cek Telegram polling conflict hilang** — tidak ada lagi `Conflict: terminated by other getUpdates request`

### Hari ini
- [ ] **Set `ASR_PROVIDER`** di environment — `whisper` + `OPENAI_API_KEY`
- [ ] **Test voice message** — kirim voice singkat, pastikan ditranskrip bukan mock
- [ ] **Tambah singleton lock** di `bot_main.py` — cegah multiple instance
- [ ] **Turunkan `MAX_STREAM_WAIT`** dari 150s → 30s
- [ ] **Turunkan `MAX_ITERATIONS`** dari 90 → 3

### Sprint berikutnya
- [ ] **Buat watchdog script** yang kill zombie + restart bersih
- [ ] **Tambah circuit breaker** — 2x timeout → kirim notif error ke user
- [ ] **Tambah fallback ke weak model** kalau strong model tidak response
- [ ] **Tambah audit log** untuk setiap timeout + instance conflict event

### Catatan patch v5
- [ ] **Evaluasi ulang `progress_reply di-skip`** — pertimbangkan tambahkan minimal 1 pesan "sedang memproses..." untuk task panjang (>30 detik) agar user tidak menganggap Nova hang

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
