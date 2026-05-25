#!/bin/bash
# nova_fix.sh — Fix Nova: multiple instance + ASR mock + stream timeout
# Jalankan di Mac: bash nova_fix.sh

set -e
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log()  { echo -e "${GREEN}[FIX]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
err()  { echo -e "${RED}[ERROR]${NC} $1"; }

echo "================================================"
echo "  NOVA FIX SCRIPT — $(date)"
echo "================================================"

# ─── STEP 1: KILL SEMUA INSTANCE ────────────────────────────────────────────
echo ""
log "STEP 1: Menghentikan semua instance Nova..."

NOVA_PIDS=$(pgrep -f "nova\|bot_main\|telegram_bot\|multimodal" 2>/dev/null || true)
if [ -n "$NOVA_PIDS" ]; then
    echo "$NOVA_PIDS" | while read pid; do
        PROC=$(ps -p "$pid" -o comm= 2>/dev/null || echo "unknown")
        warn "  Killing PID $pid ($PROC)"
        kill -9 "$pid" 2>/dev/null || true
    done
    sleep 2
    log "  Semua instance dihentikan."
else
    log "  Tidak ada proses Nova yang berjalan."
fi

# Unload LaunchAgents
PLIST_COUNT=$(ls ~/Library/LaunchAgents/com.nova*.plist 2>/dev/null | wc -l | tr -d ' ')
if [ "$PLIST_COUNT" -gt "0" ]; then
    log "Unload $PLIST_COUNT LaunchAgent Nova..."
    for plist in ~/Library/LaunchAgents/com.nova*.plist; do
        launchctl unload "$plist" 2>/dev/null || true
        warn "  Unloaded: $plist"
    done
fi

# Bersihkan lock file stale
rm -f /tmp/nova_bot.lock 2>/dev/null || true
log "  Lock file stale dibersihkan."

# Verifikasi
REMAINING=$(pgrep -f "nova\|bot_main" 2>/dev/null | wc -l | tr -d ' ')
if [ "$REMAINING" -gt "0" ]; then
    err "Masih ada $REMAINING proses. Coba: sudo pkill -f nova"
else
    log "  OK — tidak ada instance Nova aktif."
fi

# ─── STEP 2: TEMUKAN DIREKTORI NOVA ─────────────────────────────────────────
echo ""
log "STEP 2: Mencari direktori Nova..."

NOVA_DIR=""
CANDIDATES=(
    "$HOME/Documents/nova"
    "$HOME/Documents/Nova"
    "$HOME/nova"
    "$HOME/Nova"
    "$HOME/projects/nova"
    "$HOME/Documents/New project"
    "$HOME/Documents/new-project"
)

for dir in "${CANDIDATES[@]}"; do
    if [ -d "$dir" ]; then
        NOVA_DIR="$dir"
        log "  Ditemukan: $NOVA_DIR"
        break
    fi
done

if [ -z "$NOVA_DIR" ]; then
    warn "  Direktori tidak ditemukan di lokasi umum. Mencari..."
    NOVA_DIR=$(find "$HOME/Documents" -maxdepth 3 -name "bot_main.py" -o -name "*telegram*bot*.py" 2>/dev/null | head -1 | xargs dirname 2>/dev/null || true)
    if [ -n "$NOVA_DIR" ]; then
        log "  Ditemukan via search: $NOVA_DIR"
    else
        err "  Tidak bisa temukan direktori Nova."
        echo ""
        echo "  Jalankan manual:"
        echo "  find ~ -name 'bot_main.py' 2>/dev/null"
        NOVA_DIR="TIDAK_DITEMUKAN"
    fi
fi

# ─── STEP 3: PATCH SINGLETON LOCK ───────────────────────────────────────────
echo ""
log "STEP 3: Menambahkan singleton lock..."

BOT_MAIN=""
if [ "$NOVA_DIR" != "TIDAK_DITEMUKAN" ]; then
    for candidate in "$NOVA_DIR/bot_main.py" "$NOVA_DIR/main.py" "$NOVA_DIR/bot.py" "$NOVA_DIR/nova_bot.py"; do
        if [ -f "$candidate" ]; then
            BOT_MAIN="$candidate"
            break
        fi
    done
fi

SINGLETON_CODE='import fcntl, sys, atexit as _atexit

def _acquire_singleton():
    _lf = open("/tmp/nova_bot.lock", "w")
    try:
        fcntl.flock(_lf, fcntl.LOCK_EX | fcntl.LOCK_NB)
        _atexit.register(lambda: (_lf.close(), __import__("os").remove("/tmp/nova_bot.lock") if __import__("os").path.exists("/tmp/nova_bot.lock") else None))
        return _lf
    except IOError:
        print("ERROR: Instance Nova lain sudah berjalan. Hentikan dulu dengan: pkill -f nova")
        sys.exit(1)

_singleton_lock = _acquire_singleton()
'

if [ -n "$BOT_MAIN" ]; then
    if grep -q "nova_bot.lock" "$BOT_MAIN"; then
        log "  Singleton lock sudah ada di $BOT_MAIN — skip."
    else
        # Backup dulu
        cp "$BOT_MAIN" "${BOT_MAIN}.bak.$(date +%Y%m%d_%H%M%S)"
        # Insert setelah baris pertama import
        FIRST_IMPORT_LINE=$(grep -n "^import\|^from" "$BOT_MAIN" | head -1 | cut -d: -f1)
        if [ -n "$FIRST_IMPORT_LINE" ]; then
            python3 - "$BOT_MAIN" "$FIRST_IMPORT_LINE" "$SINGLETON_CODE" <<'PYEOF'
import sys
filepath = sys.argv[1]
insert_after = int(sys.argv[2])
new_code = sys.argv[3]

with open(filepath, 'r') as f:
    lines = f.readlines()

# Insert setelah baris pertama import (baris ke insert_after)
lines.insert(insert_after, '\n# --- singleton lock (auto-inserted by nova_fix.sh) ---\n' + new_code + '# --- end singleton lock ---\n\n')

with open(filepath, 'w') as f:
    f.writelines(lines)
print("OK")
PYEOF
            log "  Singleton lock ditambahkan ke $BOT_MAIN"
        fi
    fi
else
    warn "  bot_main.py tidak ditemukan — singleton lock tidak bisa di-patch otomatis."
    echo ""
    echo "  Tambahkan kode ini manual di bagian ATAS file bot utama kamu:"
    echo "  ──────────────────────────────────────────────────────────────"
    echo "$SINGLETON_CODE"
    echo "  ──────────────────────────────────────────────────────────────"
fi

# ─── STEP 4: PATCH STREAM TIMEOUT ───────────────────────────────────────────
echo ""
log "STEP 4: Mencari dan patch stream timeout..."

if [ "$NOVA_DIR" != "TIDAK_DITEMUKAN" ]; then
    # Cari file yang punya MAX_ITERATIONS atau MAX_STREAM_WAIT atau iteration 1/90
    TIMEOUT_FILES=$(grep -rl "MAX_ITERATIONS\|MAX_STREAM_WAIT\|max_iterations\|max_retries.*90\|range(90)" "$NOVA_DIR" 2>/dev/null || true)

    if [ -n "$TIMEOUT_FILES" ]; then
        echo "$TIMEOUT_FILES" | while read f; do
            warn "  File timeout ditemukan: $f"
            cp "$f" "${f}.bak.$(date +%Y%m%d_%H%M%S)"
            # Patch nilai 90 → 3 dan 150 → 30
            sed -i '' \
                's/MAX_ITERATIONS\s*=\s*90/MAX_ITERATIONS = 3/g' \
                's/MAX_STREAM_WAIT\s*=\s*150/MAX_STREAM_WAIT = 30/g' \
                's/max_iterations\s*=\s*90/max_iterations = 3/g' \
                's/range(90)/range(3)/g' \
                "$f" 2>/dev/null || true
            log "  Patched: $f"
        done
    else
        warn "  File timeout tidak ditemukan via grep. Cari manual:"
        echo "  grep -rn 'MAX_ITERATIONS\|range(90)\|150' $NOVA_DIR"
    fi
fi

# ─── STEP 5: PATCH ASR PROVIDER ─────────────────────────────────────────────
echo ""
log "STEP 5: Cek dan fix ASR provider..."

if [ "$NOVA_DIR" != "TIDAK_DITEMUKAN" ]; then
    ASR_FILES=$(grep -rl "ASR_PROVIDER\|provider.*mock\|mock.*asr\|asr_provider" "$NOVA_DIR" 2>/dev/null || true)

    if [ -n "$ASR_FILES" ]; then
        echo "$ASR_FILES" | while read f; do
            warn "  File ASR ditemukan: $f"
            # Cek apakah fallback ke mock
            if grep -q '"mock"\|'\''mock'\''' "$f"; then
                cp "$f" "${f}.bak.$(date +%Y%m%d_%H%M%S)"
                sed -i '' \
                    's/ASR_PROVIDER.*=.*os\.getenv.*"ASR_PROVIDER".*,.*"mock"/ASR_PROVIDER = os.getenv("ASR_PROVIDER", "whisper")/g' \
                    "$f" 2>/dev/null || true
                log "  Default ASR diubah dari mock → whisper di: $f"
            fi
        done
    else
        warn "  File ASR tidak ditemukan via grep."
    fi

    # Cek env var
    if [ -z "$OPENAI_API_KEY" ]; then
        warn "  OPENAI_API_KEY tidak di-set di environment."
        echo ""
        echo "  Tambahkan ke ~/.zshrc atau ~/.bashrc:"
        echo "  export OPENAI_API_KEY='sk-...'"
        echo "  export ASR_PROVIDER='whisper'"
        echo ""
        echo "  Atau tambahkan ke LaunchAgent plist kamu:"
        echo "  <key>EnvironmentVariables</key>"
        echo "  <dict>"
        echo "    <key>OPENAI_API_KEY</key>"
        echo "    <string>sk-YOUR_KEY</string>"
        echo "    <key>ASR_PROVIDER</key>"
        echo "    <string>whisper</string>"
        echo "  </dict>"
    else
        log "  OPENAI_API_KEY sudah di-set."
    fi
fi

# ─── STEP 6: RESTART SATU INSTANCE ──────────────────────────────────────────
echo ""
log "STEP 6: Restart Nova (1 instance)..."

if [ "$PLIST_COUNT" -gt "0" ]; then
    MAIN_PLIST=$(ls ~/Library/LaunchAgents/com.nova*.plist 2>/dev/null | head -1)
    if [ -n "$MAIN_PLIST" ]; then
        launchctl load "$MAIN_PLIST"
        log "  Loaded: $MAIN_PLIST"
        sleep 2
        RUNNING=$(pgrep -f "nova\|bot_main" 2>/dev/null | wc -l | tr -d ' ')
        log "  Instance berjalan sekarang: $RUNNING"
        if [ "$RUNNING" -eq "1" ]; then
            log "  ✓ Berhasil — hanya 1 instance aktif."
        elif [ "$RUNNING" -gt "1" ]; then
            err "  Masih $RUNNING instance. Kill manual dulu lalu load plist-nya."
        fi
    fi
else
    warn "  Tidak ada LaunchAgent ditemukan."
    echo ""
    echo "  Jalankan Nova manual:"
    if [ -n "$BOT_MAIN" ]; then
        echo "  cd $(dirname $BOT_MAIN) && python3 $(basename $BOT_MAIN)"
    else
        echo "  cd /path/ke/nova && python3 bot_main.py"
    fi
fi

# ─── SUMMARY ────────────────────────────────────────────────────────────────
echo ""
echo "================================================"
echo "  SELESAI — $(date)"
echo "================================================"
echo ""
echo "  Verifikasi:"
echo "  1. ps aux | grep -i nova | grep -v grep   ← harus 1 baris"
echo "  2. Kirim voice message ke Nova            ← tidak boleh 'provider mock'"
echo "  3. Kirim pesan biasa                      ← tidak boleh timeout 150s"
echo ""
echo "  Kalau masih ada masalah, jalankan:"
echo "  ps aux | grep -i nova | grep -v grep"
echo "  dan share hasilnya."
echo ""
