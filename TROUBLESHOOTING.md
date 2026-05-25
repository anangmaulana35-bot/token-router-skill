# Troubleshooting Nova Hermes — Voice Note & Visibility Hilang

Catatan diagnosa dari log/screenshot Nova Hermes saat:
- Voice note **tidak ter-transkrip** lagi (sebelumnya bisa).
- Proses internal Nova (tool call streaming) **tidak terlihat** di Telegram lagi.

Ringkasan: ini **satu bot saja** — `@Nova_hermes35bot` (Nova Hermes) — bukan dua bot terpisah. Tapi identitas internal & teks-teks hardcoded-nya rusak: display name muncul sebagai "Nova", `/help` ngaku "Nova Codex" route ke `@NovaCodex35Bot` (bot yang sudah deprecated). Plus ada 4 masalah runtime yang datang bareng. Yang paling urgent ada di #0 (LLM stream timeout) dan #0b (identitas bot rusak).

> **Koreksi diagnosa sebelumnya (dua kali salah arah):**
> 1. Awalnya aku kira ada delegasi inter-bot Nova → Codex. **Salah** — Codex bot udah deprecated, nggak ada delegasi.
> 2. Lalu aku kira ada dua bot terpisah (Nova Hermes vs Nova). **Juga salah** — cuma satu bot `@Nova_hermes35bot`, tapi identitas-nya broken karena display name & help text masih nyebut nama lama.
>
> Jadi stream timeout `waiting for stream response (332s, no chunks)` itu di **Nova Hermes ↔ LLM provider** (Claude/OpenAI langsung). Codex tidak ada di pipeline. Yang perlu dibetulkan: (a) LLM call hang, dan (b) identitas/teks bot yang masih bilang dia "Nova Codex".

---

## 0. Stream timeout di LLM provider utama Nova (PRIORITAS)

### Gejala
```
⏳ Still working... (9 min elapsed — iteration 3/90, waiting for stream response (150s, no chunks yet))
⏳ Still working... (12 min elapsed — iteration 3/90, waiting for stream response (332s, no chunks yet))
❌ Nova agent timeout. Aku sudah cek, belum ada file output aman yang bisa dikirim.
   Task sedang dicoba ulang otomatis (1/1) agar lanjut, bukan gagal total.
```

Nova kirim request streaming ke LLM provider (Claude / OpenAI / dst), **0 chunk balik dalam 332 detik** → Nova trigger timeout. Karena bot Codex sudah dihapus dari arsitektur, ini bukan masalah inter-bot — ini Nova ↔ LLM provider langsung.

### Cara membedakan dari error Nova-side lain
| Indikator | Penyebab | Langkah fix |
|---|---|---|
| `getUpdates conflict` di log Nova | Polling double instance | #1 |
| `provider=mock` di log ASR | ASR config | #2 |
| Tool call streaming hilang di Telegram | UI verbosity flag | #3 |
| `waiting for stream response (Ns, no chunks yet)` dengan `N` membesar | **LLM provider hang** | **#0 ini** |
| `iteration 1/90` stuck | Gagal sebelum first chunk (kemungkinan API key / model) |  |
| `iteration 3/90` stuck (kasus sekarang) | Gagal di tengah tool-loop (context overflow / tool schema) |  |

### Root cause umum

1. **API key expired / quota habis** — provider terima request, drop stream tanpa error chunk.
2. **Model ID di-deprecate** — provider hang 30–300s sebelum return error.
3. **Context window overflow** — prompt+history >> limit model, provider stuck di queue. Cocok dengan kasus `iteration 3/90` (sudah 2 iterasi tool call, context membengkak).
4. **Tool definition rusak** — JSON schema tool invalid, provider stuck retry internal.
5. **Provider rate limit / outage** — request diterima tapi nggak diproses, no error chunk.
6. **Network egress macet** — host Mac kena throttle / proxy putus, TCP open tapi nggak ada data.

### Diagnosa

#### Cek API key & model yang aktif
```bash
# Cari config LLM Nova
grep -RIn "api_key\|model\|provider" ~/.hermes ~/.nova ~/.config 2>/dev/null | head -30

# Cek env var (sembunyikan value)
env | grep -iE "openai|anthropic|api_key|model" | sed 's/=.*/=<REDACTED>/'
```

#### Test endpoint LLM langsung (bypass Nova)
```bash
# Claude:
curl -sS -m 30 https://api.anthropic.com/v1/messages \
  -H "x-api-key: $ANTHROPIC_API_KEY" \
  -H "anthropic-version: 2023-06-01" \
  -H "content-type: application/json" \
  -d '{"model":"<model-nova>","max_tokens":10,"stream":true,"messages":[{"role":"user","content":"ping"}]}'

# OpenAI:
curl -sS -m 30 https://api.openai.com/v1/chat/completions \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"model":"<model-nova>","messages":[{"role":"user","content":"ping"}],"max_tokens":5,"stream":true}'
```
- Curl hang / no chunks → masalah **provider/API key/network**, bukan kode Nova.
- Curl jalan normal → masalah di cara Nova bikin request (context overflow / tool schema / wrapper bug).

#### Tail log LLM call di Nova
```bash
tail -n 500 ~/.nova/logs/*.log ~/.hermes/logs/*.log 2>/dev/null \
  | grep -iE "stream|chunk|timeout|context|rate|error" | tail -50
```
Pattern penting:
- `stream aborted` / `connection reset` → network/provider drop
- `context_length_exceeded` → prompt kepanjangan → aktifkan compaction
- `invalid_request_error` → tool schema atau model name salah
- `rate_limit_exceeded` → quota habis
- log kosong walau Nova kirim request → API key ditolak silent

### Quick mitigation kalau urgent
Turunkan timeout & retry biar nggak nunggu 12 menit:
```yaml
agent:
  stream_timeout_s: 30        # dari default 150s
  max_iterations: 30          # dari 90
  abort_on_no_chunks_s: 45
```
Sibling branch `claude/nova-error-logs-H7IGB` punya `nova_fix.sh` yang sudah mencakup patch ini — bisa cherry-pick.

---

## 0b. Identitas Nova Hermes rusak — display name & /help masih ngaku "Nova Codex"

### Gejala
Bot dengan username `@Nova_hermes35bot` (yang seharusnya **Nova Hermes**) menampilkan:

- **Header chat:** "Nova" (bukan "Nova Hermes")
- **`/help` output:**
  ```
  Nova Codex official route: @NovaCodex35Bot
  Kirim pesan biasa untuk Full Agent lokal.
  Nova diperlakukan sebagai assistant engineering utama...
  ```
- Padahal `@NovaCodex35Bot` sudah **deprecated** dan bukan bagian dari arsitektur lagi.

Ini bikin confusing: user mengira sedang chat dengan bot lain (Nova Codex), padahal sama saja Nova Hermes — cuma identitas hardcoded-nya belum di-update.

### Lokasi yang harus dicek di repo Nova Hermes (di Mac)
```bash
cd <path-ke-repo-nova-hermes>

# Cari semua string identitas
grep -RIn "NovaCodex35Bot\|Nova Codex\|@NovaCodex\|Codex official route" \
  --include="*.py" --include="*.ts" --include="*.js" \
  --include="*.yaml" --include="*.yml" --include="*.json" \
  --include="*.toml" --include="*.md" --include="*.txt" .

# Cari display name / bot description yang mungkin masih "Nova" doang
grep -RIn "\"Nova\"\|name.*Nova\|display_name\|bot_name" \
  --include="*.py" --include="*.yaml" --include="*.json" .
```

Kandidat file:
- `handlers/help.py` / `commands/help.*` — handler command `/help`
- `templates/help.{txt,md,yaml}` / `messages/id/*.yaml` — template Bahasa Indonesia
- `config/bot.yaml` / `config/identity.yaml` — display name & branding
- `prompts/system_prompt.*` — kalau bot self-identify lewat LLM, system prompt mungkin masih nyebut "Nova Codex"
- `setMyName` / `setMyDescription` BotFather calls — kalau identitas di-set programatik via Telegram API

### Fix yang perlu dilakukan
1. **Ganti display name di BotFather** → "Nova Hermes" (atau via API: `setMyName`).
2. **Hapus blok `/help` yang nyebut Nova Codex / @NovaCodex35Bot**. Ganti dengan deskripsi Nova Hermes yang benar.
3. **Cek system prompt LLM** — kalau ada `"You are Nova Codex..."` ganti ke `"You are Nova Hermes..."`.
4. **Hapus dead-code routing** — kalau ada fungsi `route_to_codex_bot()` / `forward_to_nova_codex()` yang nggak pernah dipanggil, hapus juga.

### Test setelah fix
```
User: /help
Nova Hermes: <output baru — identitas Nova Hermes, tanpa mention NovaCodex>
```
Header chat juga harus berubah jadi "Nova Hermes" (mungkin perlu clear cache Telegram client).

### Kenapa ini bikin diagnosa salah arah (catatan)
Stale string "Nova Codex official route" bikin orang (termasuk aku) ngira ada bot Codex aktif di pipeline. Padahal itu cuma label zombie. Sekali identitas dibetulin, debugging future jadi nggak akan kemana-mana lagi.

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
