#!/bin/bash
# deploy_to_mac.sh — Copy nova_agent.py yang sudah difix ke Mac dan restart
# Jalankan dari folder token-router-skill: bash nova/deploy_to_mac.sh

set -e
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
ok()   { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err()  { echo -e "${RED}[ERR]${NC} $1"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==========================================="
echo "  NOVA DEPLOY — $(date)"
echo "==========================================="

# ── 1. Temukan Nova di Mac ───────────────────────────────────────────────────
warn "Mencari Nova di Mac..."
NOVA_DIR=""
for d in \
    "$HOME/Documents/nova" "$HOME/Documents/Nova" \
    "$HOME/Documents/hermes" "$HOME/Documents/Hermes" \
    "$HOME/nova" "$HOME/hermes" "$HOME/projects/nova" "$HOME/Desktop/nova"; do
    if [ -d "$d" ] && ls "$d"/*.py &>/dev/null 2>&1; then
        NOVA_DIR="$d"; break
    fi
done

if [ -z "$NOVA_DIR" ]; then
    NOVA_DIR=$(find "$HOME" -maxdepth 5 -name "nova_agent.py" 2>/dev/null | head -1 | xargs dirname 2>/dev/null || true)
fi

if [ -z "$NOVA_DIR" ]; then
    err "Nova tidak ditemukan. Set path manual:"
    echo "  export NOVA_DIR=/path/ke/nova && bash nova/deploy_to_mac.sh"
    exit 1
fi
ok "Nova ditemukan: $NOVA_DIR"

# ── 2. Stop semua instance ───────────────────────────────────────────────────
warn "Stop semua instance Nova..."
pkill -f "nova_agent\|nova_bot\|bot_main\|hermes" 2>/dev/null || true
sleep 1
rm -f /tmp/nova*.lock 2>/dev/null || true
ok "Instance dihentikan."

# ── 3. Backup + copy nova_agent.py yang difix ───────────────────────────────
warn "Backup dan deploy nova_agent.py yang sudah difix..."

TARGET="$NOVA_DIR/nova_agent.py"
if [ -f "$TARGET" ]; then
    cp "$TARGET" "${TARGET}.bak_$(date +%Y%m%d_%H%M%S)"
    ok "  Backup: ${TARGET}.bak_*"
fi

cp "$SCRIPT_DIR/nova_agent.py" "$TARGET"
ok "  nova_agent.py diupdate."

# Copy nova_fixes juga
cp -r "$SCRIPT_DIR/../nova_fixes" "$NOVA_DIR/nova_fixes"
ok "  nova_fixes/ dicopy."

# ── 4. Update system prompt (versi lean) ────────────────────────────────────
warn "Update system prompt ke versi lean..."
SYS_TARGET="$NOVA_DIR/system_prompt.txt"
if [ -f "$SYS_TARGET" ]; then
    cp "$SYS_TARGET" "${SYS_TARGET}.bak_$(date +%Y%m%d_%H%M%S)"
fi
cp "$SCRIPT_DIR/system_prompt.txt" "$SYS_TARGET"
ok "  system_prompt.txt diupdate (versi kompres)."

# ── 5. Cek env vars ──────────────────────────────────────────────────────────
warn "Cek environment variables..."
MISSING_VARS=0
for var in ANTHROPIC_API_KEY; do
    if [ -z "${!var}" ]; then
        err "  $var tidak di-set!"
        MISSING_VARS=$((MISSING_VARS + 1))
    else
        ok "  $var sudah di-set."
    fi
done

if [ "$MISSING_VARS" -gt 0 ]; then
    echo ""
    echo "  Tambahkan ke ~/.zshrc:"
    echo "  export ANTHROPIC_API_KEY='sk-ant-...'"
    echo "  source ~/.zshrc"
    echo ""
fi

# ── 6. Test cepat ────────────────────────────────────────────────────────────
warn "Test nova_agent.py (syntax check)..."
python3 -c "import ast; ast.parse(open('$TARGET').read()); print('Syntax OK')" && ok "  Syntax valid."

# ── 7. Restart ───────────────────────────────────────────────────────────────
warn "Restart Nova..."
cd "$NOVA_DIR"

# Kalau ada Telegram bot wrapper, cari itu dulu
for entry in telegram_bot.py bot_main.py bot.py hermes_bot.py nova_bot.py; do
    if [ -f "$NOVA_DIR/$entry" ]; then
        ENTRY="$NOVA_DIR/$entry"
        break
    fi
done

# Fallback ke nova_agent langsung
ENTRY="${ENTRY:-$TARGET}"

nohup python3 "$ENTRY" > "$NOVA_DIR/nova.log" 2>&1 &
sleep 2
RUNNING=$(pgrep -f "nova_agent\|nova_bot\|bot_main\|hermes" 2>/dev/null | wc -l | tr -d ' ')
ok "Nova direstart. Proses aktif: $RUNNING"
echo "  Log: tail -f $NOVA_DIR/nova.log"

# ── Summary ──────────────────────────────────────────────────────────────────
echo ""
echo "==========================================="
echo "  SELESAI"
echo "==========================================="
echo ""
echo "  Yang difix:"
echo "  [1] Context overflow  — compact history otomatis sebelum kirim ke API"
echo "  [2] System prompt     — dikompres ke versi lean"
echo "  [3] Auto-recovery     — kalau masih overflow, history di-reset minimal"
echo "  [4] Perintah /clear   — reset history manual dari chat"
echo "  [5] Perintah /status  — cek token usage"
echo ""
echo "  Test: kirim 'Halo' ke Nova di Telegram"
echo "        kalau mau reset: kirim '/clear' ke Nova"
echo ""
