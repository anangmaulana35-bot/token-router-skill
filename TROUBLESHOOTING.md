# Troubleshooting Nova Hermes — Voice Note & Visibility Hilang

Catatan diagnosa dari log/screenshot Nova Hermes saat:
- Voice note **tidak ter-transkrip** lagi (sebelumnya bisa).
- Proses internal Nova (tool call streaming) **tidak terlihat** di Telegram lagi.

Ringkasan: bukan model-nya yang berubah, ada **3 hal terpisah** yang kebetulan datang bareng.

---

## 1. Telegram polling konflik (penyebab utama voice note nyangkut)

### Gejala di log host Mac
```
Conflict: terminated by other getUpdates request
```
muncul 12+ kali dalam 6 menit terakhir.

### Artinya
Ada **>1 proses bot Nova** yang sama-sama menarik `getUpdates` dari Telegram. Setiap kali instance A baru pegang voice note, instance B rebut → pesan delay atau hilang. Voice note paling rentan karena payload-nya lebih besar (download dari Telegram CDN dulu) dan timing-nya lebih ketat dari teks.

### Cek instance ganda

```bash
# lihat semua proses Nova/Hermes dengan command line lengkap
pgrep -fa "nova|hermes|telegram"

# atau
ps aux | grep -E "nova|hermes|telegram" | grep -v grep
```

Cari yang dobel: dua PID dengan command serupa (mis. dua kali `python -m nova_bot` atau `hermes serve`).

### Matikan yang dobel, sisakan 1

```bash
# Identifikasi PID yang lebih lama (kolom STARTED di ps), kill yang lebih baru
kill <PID_yang_dobel>

# Atau, kalau aman matiin semua dulu lalu start ulang fresh:
pkill -f nova_bot
pkill -f hermes

# Tunggu Telegram release polling slot (~30 detik)
sleep 30

# Start 1 instance saja
cd ~/.hermes && hermes serve   # sesuaikan dengan launcher kamu
```

### Cegah dobel di masa depan

Gunakan **PID file lock** atau `launchd`/`systemd` service supaya cuma 1 instance hidup. Contoh wrapper sederhana:

```bash
#!/usr/bin/env bash
# ~/.hermes/run.sh
LOCK=/tmp/nova-hermes.pid
if [ -f "$LOCK" ] && kill -0 "$(cat $LOCK)" 2>/dev/null; then
  echo "Nova Hermes sudah jalan dengan PID $(cat $LOCK), exit."
  exit 1
fi
echo $$ > "$LOCK"
trap "rm -f $LOCK" EXIT
exec hermes serve
```

---

## 2. ASR provider masih `mock` (penyebab voice note nyampe tapi nggak ter-transkrip)

### Gejala
Pesan terakhir Nova:
> *"Audio diterima oleh provider mock. Transkrip penuh membutuhkan provider ASR yang diaktifkan, tetapi file sudah tervalidasi dan siap diproses."*

Artinya **audio sampai ke server**, tapi pipeline transkripsi pakai provider dummy. Mock cuma validasi format file, nggak menghasilkan teks.

### Aktifkan provider ASR yang asli

Cek config Hermes (biasanya salah satu dari):
- `~/.hermes/config.yaml`
- `~/.hermes/config.json`
- `~/.hermes/config.toml`
- `~/.config/hermes/config.*`

Ubah section `asr:` dari `mock` ke provider beneran:

#### Opsi A — OpenAI Whisper (cloud, paling gampang)
```yaml
asr:
  provider: openai_whisper
  model: whisper-1
  api_key: ${OPENAI_API_KEY}   # set di env, jangan hardcode
  language: id                  # opsional, untuk Bahasa Indonesia
```

#### Opsi B — Faster-Whisper (lokal, gratis, butuh GPU/CPU lumayan)
```yaml
asr:
  provider: faster_whisper
  model: large-v3              # atau medium / small kalau resource terbatas
  device: auto                  # cuda / cpu / mps (Mac M-series)
  compute_type: int8            # hemat RAM
  language: id
```

#### Opsi C — Groq Whisper (cloud, super cepat & murah)
```yaml
asr:
  provider: groq
  model: whisper-large-v3
  api_key: ${GROQ_API_KEY}
  language: id
```

### Restart Hermes setelah ubah config
```bash
pkill -f hermes && sleep 5 && hermes serve
```

### Verifikasi
Kirim voice note pendek (~3 detik) ke Nova. Di log host harus muncul baris bertipe:
```
asr.transcribe provider=openai_whisper duration=2.8s text="..."
```
Bukan lagi `provider=mock`.

---

## 3. Restore visibility proses Nova (tool call streaming)

### Gejala
Sebelumnya (jam 17:58) Nova streaming setiap tool call ke Telegram:
```
🐍 execute_code: "from hermes_tools import terminal r =..."
📖 read_file: "/Users/anangmaulana/Documents/New pro..."
🔧 patch: "/Users/anangmaulana/Documents/New pro..."
⏳ Still working... (15 min elapsed — iteration 24/90)
```

Sekarang (jam 18:18) cuma muncul:
> *"Task diterima. Dipahami sebagai: task umum. Aku jalankan lewat agent lokal dan kirim hasilnya setelah selesai."*

Streaming intermediate steps **dimatikan**.

### Cari setting di config Hermes

Salah satu (atau kombinasi) flag berikut yang berubah:

```yaml
ui:
  stream_tool_calls: true       # tampilkan tool call satu per satu
  show_intermediate_steps: true # tampilkan reasoning step
  verbose: true                 # log lengkap
  progress_updates: true        # update "Still working… iteration N/M"
  send_thinking_to_telegram: true
```

Atau via env var (cek `~/.hermes/.env` atau startup script):
```bash
export HERMES_VERBOSE=1
export HERMES_STREAM_TOOLS=1
export HERMES_SHOW_PROGRESS=1
```

### Kalau settings di atas nggak ketemu

Cek git log di repo Nova-mu di Mac:
```bash
cd <path-ke-repo-nova>
git log --oneline --since="2 days ago"
git diff HEAD~5 HEAD -- '*config*' '*telegram*' '*stream*'
```
Cari commit yang menyentuh handler Telegram atau output formatter. Kemungkinan ada perubahan dari `await bot.send_message(tool_call_summary)` jadi cuma kirim hasil akhir.

Revert atau aktifkan ulang feature flag yang relevan.

---

## Urutan eksekusi yang disarankan

1. **Matikan instance dobel dulu** (langkah #1) — ini bikin pipeline stabil.
2. **Aktifkan ASR provider** (langkah #2) — sekarang voice note akan ter-transkrip.
3. **Restore verbose streaming** (langkah #3) — visibility balik seperti semula.

Setelah ketiganya, test:
- Kirim voice note 5 detik → harus muncul transkrip + tool call streaming.
- Kirim screenshot → vision pipeline harus output deskripsi (sudah ✅ di screenshot terbaru).
- Kirim task panjang → harus muncul `⏳ Still working… iteration N/M`.

---

## Kalau masih stuck

Kumpulkan log ini sebelum minta bantuan lanjutan:
```bash
# 200 baris terakhir host log
tail -n 200 ~/.hermes/logs/hermes.log > /tmp/hermes-tail.log

# Daftar proses aktif
pgrep -fa "nova|hermes|telegram" > /tmp/nova-procs.txt

# Config aktif (redact API keys dulu!)
cat ~/.hermes/config.yaml | sed 's/\(api_key:\).*/\1 <REDACTED>/' > /tmp/nova-config.txt
```

Push ketiganya ke repo Nova (private) atau gist, dan tunjukkan link-nya ke Claude di sesi berikutnya.
