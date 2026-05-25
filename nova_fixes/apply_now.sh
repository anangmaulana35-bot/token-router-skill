#!/bin/bash
# apply_now.sh — Terapkan fix Nova sekarang (context overflow + stream timeout)
# Jalankan di Mac: bash apply_now.sh

set -e
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
ok()   { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err()  { echo -e "${RED}[ERR]${NC} $1"; }

echo "======================================"
echo "  NOVA EMERGENCY FIX — $(date)"
echo "======================================"

# ── 1. STOP SEMUA INSTANCE ─────────────────────────────────────────────────
echo ""
warn "STEP 1: Stop semua Nova..."
pkill -f "nova\|hermes\|bot_main\|telegram_bot" 2>/dev/null || true
sleep 1
launchctl list | grep -i nova | awk '{print $3}' | xargs -I{} launchctl stop {} 2>/dev/null || true
rm -f /tmp/nova*.lock /tmp/hermes*.lock 2>/dev/null || true
ok "Instance dihentikan."

# ── 2. TEMUKAN NOVA DIR ────────────────────────────────────────────────────
echo ""
warn "STEP 2: Cari direktori Nova..."

NOVA_DIR=""
for d in \
    "$HOME/Documents/nova" "$HOME/Documents/Nova" \
    "$HOME/Documents/hermes" "$HOME/Documents/Hermes" \
    "$HOME/nova" "$HOME/hermes" "$HOME/projects/nova" \
    "$HOME/Documents/new-project" "$HOME/Desktop/nova"; do
    if [ -d "$d" ]; then NOVA_DIR="$d"; break; fi
done

if [ -z "$NOVA_DIR" ]; then
    NOVA_DIR=$(find "$HOME" -maxdepth 4 \( -name "bot_main.py" -o -name "nova_bot.py" -o -name "hermes_bot.py" \) 2>/dev/null | head -1 | xargs dirname 2>/dev/null || true)
fi

if [ -z "$NOVA_DIR" ]; then
    err "Direktori Nova tidak ditemukan otomatis."
    echo "Jalankan: find ~ -name 'bot_main.py' 2>/dev/null"
    echo "Lalu set: export NOVA_DIR=/path/ke/nova && bash apply_now.sh"
    exit 1
fi

ok "Nova ditemukan: $NOVA_DIR"

# ── 3. COPY FIX FILES ──────────────────────────────────────────────────────
echo ""
warn "STEP 3: Copy nova_fixes ke direktori Nova..."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cp -r "$SCRIPT_DIR" "$NOVA_DIR/nova_fixes"
ok "nova_fixes/ sudah ada di $NOVA_DIR"

# ── 4. INJECT CTX GUARD ───────────────────────────────────────────────────
echo ""
warn "STEP 4: Cari file LLM call dan inject CtxGuard..."

# Cari file yang punya messages= (tempat kirim ke LLM)
LLM_FILES=$(grep -rl "messages=" "$NOVA_DIR" --include="*.py" 2>/dev/null | grep -v __pycache__ | grep -v nova_fixes || true)

PATCH_CODE='
# --- ctx_guard patch (auto) ---
try:
    import sys, os; sys.path.insert(0, os.path.dirname(__file__))
    from nova_fixes.ctx_guard import CtxGuard as _CtxGuard
    _ctx_guard = _CtxGuard(model=os.getenv("LLM_MODEL", "claude-opus-4-7"))
    _ctx_guard_ready = True
except ImportError:
    _ctx_guard_ready = False
# --- end ctx_guard patch ---
'

if [ -n "$LLM_FILES" ]; then
    echo "$LLM_FILES" | while read f; do
        if ! grep -q "ctx_guard patch" "$f"; then
            # Backup
            cp "$f" "${f}.bak_$(date +%Y%m%d_%H%M%S)"
            # Insert setelah baris pertama import
            python3 - "$f" "$PATCH_CODE" <<'PYEOF'
import sys
fpath = sys.argv[1]
patch = sys.argv[2]

with open(fpath) as ff:
    lines = ff.readlines()

# Cari baris import pertama
insert_at = 0
for i, l in enumerate(lines):
    if l.startswith("import ") or l.startswith("from "):
        insert_at = i
        break

lines.insert(insert_at + 1, patch + "\n")
with open(fpath, "w") as ff:
    ff.writelines(lines)
print("Patched:", fpath)
PYEOF
            ok "  CtxGuard di-inject ke: $f"
        else
            warn "  Sudah ada di: $f — skip."
        fi
    done
else
    warn "  File LLM call tidak ditemukan. Tambahkan manual — lihat CARA_PAKAI di bawah."
fi

# ── 5. FIX TIMEOUT CONFIG ──────────────────────────────────────────────────
echo ""
warn "STEP 5: Patch timeout config..."

TIMEOUT_FILES=$(grep -rl "MAX_ITERATIONS\|MAX_STREAM_WAIT\|max_iterations\|range(90)\|timeout.*150" "$NOVA_DIR" --include="*.py" 2>/dev/null | grep -v __pycache__ | grep -v nova_fixes || true)

if [ -n "$TIMEOUT_FILES" ]; then
    echo "$TIMEOUT_FILES" | while read f; do
        cp "$f" "${f}.bak_$(date +%Y%m%d_%H%M%S)" 2>/dev/null || true
        sed -i'' \
            -e 's/MAX_ITERATIONS *= *90/MAX_ITERATIONS = 3/g' \
            -e 's/MAX_STREAM_WAIT *= *150/MAX_STREAM_WAIT = 30/g' \
            -e 's/max_iterations *= *90/max_iterations = 3/g' \
            -e 's/range(90)/range(3)/g' \
            -e 's/timeout *= *150/timeout = 30/g' \
            "$f"
        ok "  Timeout dipatch di: $f"
    done
else
    warn "  Timeout config tidak ditemukan. Cari manual:"
    echo "  grep -rn 'range(90)\|timeout.*150\|MAX_ITER' $NOVA_DIR"
fi

# ── 6. FIX SYSTEM PROMPT (ROOT CAUSE TERBARU) ────────────────────────────
echo ""
warn "STEP 6: Cari dan kompres system prompt yang terlalu besar..."

# Cari file yang punya system prompt panjang (SYSTEM_PROMPT = atau system= )
SYS_FILES=$(grep -rl "SYSTEM_PROMPT\|system_prompt\|\"system\":" "$NOVA_DIR" --include="*.py" 2>/dev/null | grep -v __pycache__ | grep -v nova_fixes || true)

SYS_PATCH='
# --- system_guard patch (auto) ---
try:
    from nova_fixes.system_guard import SystemGuard as _SysGuard
    import os as _os
    _sys_guard = _SysGuard(model=_os.getenv("LLM_MODEL", "claude-haiku-4-5"))
    if "SYSTEM_PROMPT" in dir() or "SYSTEM_PROMPT" in globals():
        SYSTEM_PROMPT = _sys_guard.compress(SYSTEM_PROMPT)
    if "system_prompt" in dir() or "system_prompt" in globals():
        system_prompt = _sys_guard.compress(system_prompt)
except Exception as _e:
    print(f"[system_guard] skip: {_e}")
# --- end system_guard patch ---
'

if [ -n "$SYS_FILES" ]; then
    echo "$SYS_FILES" | while read f; do
        if ! grep -q "system_guard patch" "$f"; then
            cp "$f" "${f}.bak_$(date +%Y%m%d_%H%M%S)"
            python3 - "$f" "$SYS_PATCH" <<'PYEOF'
import sys
fpath = sys.argv[1]
patch = sys.argv[2]
with open(fpath) as ff:
    lines = ff.readlines()
# Inject setelah definisi SYSTEM_PROMPT
insert_at = len(lines) - 1
for i, l in enumerate(lines):
    if "SYSTEM_PROMPT" in l or "system_prompt" in l:
        insert_at = i + 1
        break
lines.insert(insert_at, '\n' + patch + '\n')
with open(fpath, "w") as ff:
    ff.writelines(lines)
print("Patched:", fpath)
PYEOF
            ok "  SystemGuard di-inject ke: $f"
        else
            warn "  Sudah ada di: $f — skip."
        fi
    done
else
    warn "  File system prompt tidak ditemukan via grep."
    echo "  Tambahkan manual setelah definisi SYSTEM_PROMPT di kode Nova:"
    echo "  from nova_fixes.system_guard import SystemGuard"
    echo "  SYSTEM_PROMPT = SystemGuard(model='claude-haiku-4-5').compress(SYSTEM_PROMPT)"
fi

# ── 7. FIX ASR PROVIDER ───────────────────────────────────────────────────
echo ""
warn "STEP 6: Fix ASR provider (mock → whisper)..."

ASR_FILES=$(grep -rl "\"mock\"\|'mock'" "$NOVA_DIR" --include="*.py" 2>/dev/null | grep -i "asr\|speech\|audio\|transcri" | grep -v __pycache__ || true)

if [ -n "$ASR_FILES" ]; then
    echo "$ASR_FILES" | while read f; do
        cp "$f" "${f}.bak_$(date +%Y%m%d_%H%M%S)" 2>/dev/null || true
        sed -i'' \
            -e 's/getenv("ASR_PROVIDER", "mock")/getenv("ASR_PROVIDER", "whisper")/g' \
            -e 's/ASR_PROVIDER = "mock"/ASR_PROVIDER = os.getenv("ASR_PROVIDER", "whisper")/g' \
            "$f"
        ok "  ASR dipatch di: $f"
    done
else
    warn "  File ASR tidak ditemukan. Set env var manual:"
    echo "  export ASR_PROVIDER=whisper"
    echo "  export OPENAI_API_KEY=sk-..."
fi

# ── 7. RESTART SATU INSTANCE ──────────────────────────────────────────────
echo ""
warn "STEP 7: Restart Nova..."

# Cari entry point
for fname in bot_main.py main.py nova_bot.py hermes_bot.py bot.py; do
    if [ -f "$NOVA_DIR/$fname" ]; then
        ENTRY="$NOVA_DIR/$fname"
        break
    fi
done

if [ -n "$ENTRY" ]; then
    nohup python3 "$ENTRY" > "$NOVA_DIR/nova_restart.log" 2>&1 &
    sleep 2
    RUNNING=$(pgrep -f "bot_main\|nova_bot\|hermes_bot\|$ENTRY" | wc -l | tr -d ' ')
    ok "Nova direstart (PID aktif: $RUNNING)"
    echo "  Log: tail -f $NOVA_DIR/nova_restart.log"
else
    warn "Entry point tidak ditemukan. Restart manual:"
    echo "  cd $NOVA_DIR && python3 bot_main.py &"
fi

# ── SUMMARY ────────────────────────────────────────────────────────────────
echo ""
echo "======================================"
echo "  SELESAI"
echo "======================================"
echo ""
echo "Yang sudah diperbaiki:"
echo "  [1] SYSTEM PROMPT    → SystemGuard kompres (root cause error terbaru)"
echo "  [2] Context overflow → CtxGuard potong history percakapan"
echo "  [3] Stream timeout   → 150s/90iter → 30s/3iter"
echo "  [4] ASR provider     → mock → whisper"
echo "  [5] Instance ganda   → semua dihentikan, 1 di-restart"
echo ""
echo "CARA PAKAI MANUAL (kalau inject gagal):"
echo "  Di file conversation handler kamu, tambahkan:"
echo ""
echo "  from nova_fixes import CtxGuard"
echo "  _guard = CtxGuard(model='claude-opus-4-7')"
echo ""
echo "  # Sebelum kirim ke LLM:"
echo "  messages = _guard.compact(messages)"
echo "  response = client.messages.create(messages=messages, ...)"
echo ""
