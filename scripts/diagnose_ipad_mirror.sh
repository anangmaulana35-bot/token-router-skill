#!/usr/bin/env bash
# Diagnose iPad mirroring errors (Lumen/Sunshine + Moonlight + Tailscale)
# Run on Mac: bash scripts/diagnose_ipad_mirror.sh

set -euo pipefail

RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'; NC='\033[0m'

pass() { echo -e "${GREEN}[OK]${NC}  $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
fail() { echo -e "${RED}[FAIL]${NC} $*"; }
section() { echo -e "\n=== $* ==="; }

LOG_FILE="$HOME/.cache/ipad_mirror_diag_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "iPad Mirroring Diagnostic — $(date)"
echo "Log: $LOG_FILE"

# ── 1. Lumen/Sunshine process ──────────────────────────────────────────────
section "Lumen / Sunshine Host Service"

LUMEN_PIDS=$(pgrep -x "lumen" 2>/dev/null || pgrep -x "sunshine" 2>/dev/null || true)
if [[ -z "$LUMEN_PIDS" ]]; then
    fail "Lumen/Sunshine tidak berjalan → Moonlight tidak bisa connect"
    echo "  Fix: open Lumen.app atau jalankan:"
    echo "       launchctl start com.lumen.lumen 2>/dev/null || open /Applications/Lumen.app"
elif [[ $(echo "$LUMEN_PIDS" | wc -l) -gt 1 ]]; then
    warn "Lebih dari 1 instance berjalan (PIDs: $LUMEN_PIDS) → duplikat host di Moonlight"
    echo "  Fix: pkill -x lumen; sleep 2; open /Applications/Lumen.app"
else
    pass "Lumen berjalan (PID: $LUMEN_PIDS)"
fi

# ── 2. Port Lumen ──────────────────────────────────────────────────────────
section "Port Lumen (47984/47989 TCP, 47998 UDP)"

for port in 47984 47989; do
    if lsof -iTCP:$port -sTCP:LISTEN -n -P 2>/dev/null | grep -q .; then
        pass "TCP $port terbuka"
    else
        fail "TCP $port tidak terbuka — Lumen mungkin belum siap atau crash"
    fi
done

if lsof -iUDP:47998 -n -P 2>/dev/null | grep -q .; then
    pass "UDP 47998 terbuka"
else
    warn "UDP 47998 tidak terbuka (stream video mungkin gagal)"
fi

# ── 3. Tailscale ───────────────────────────────────────────────────────────
section "Tailscale VPN"

if ! command -v tailscale &>/dev/null; then
    warn "Tailscale CLI tidak ditemukan — pastikan Tailscale.app terinstall"
else
    TS_STATUS=$(tailscale status 2>&1 || true)
    if echo "$TS_STATUS" | grep -q "^This device"; then
        pass "Tailscale aktif"
        TS_IP=$(tailscale ip -4 2>/dev/null || echo "unknown")
        echo "  Tailscale IP Mac ini: $TS_IP"
        echo "  Pastikan iPad pakai IP ini ($TS_IP) di Moonlight Add Host"
    elif echo "$TS_STATUS" | grep -qi "not logged in\|Logged out"; then
        fail "Tailscale belum login → iPad tidak bisa reach Mac"
        echo "  Fix: tailscale up"
    else
        warn "Status Tailscale tidak dikenali: $TS_STATUS"
    fi
fi

# ── 4. Screen Recording Permission ────────────────────────────────────────
section "Izin Screen Recording (macOS)"

LUMEN_BUNDLE="com.lumen.lumen"
if tccutil query ScreenCapture 2>/dev/null | grep -qi "$LUMEN_BUNDLE.*allow\|kTCCService.*1"; then
    pass "Screen Recording sudah diizinkan untuk Lumen"
else
    warn "Screen Recording untuk Lumen tidak terdeteksi via CLI"
    echo "  Cek manual: System Settings → Privacy & Security → Screen Recording"
    echo "  Pastikan Lumen (atau Sunshine) dicentang"
fi

# ── 5. Firewall Mac ────────────────────────────────────────────────────────
section "Firewall macOS"

FW_STATE=$(defaults read /Library/Preferences/com.apple.alf globalstate 2>/dev/null || echo "0")
if [[ "$FW_STATE" == "0" ]]; then
    pass "Firewall macOS nonaktif (port terbuka)"
else
    warn "Firewall aktif (state=$FW_STATE) — pastikan Lumen ada di whitelist"
    echo "  Tambahkan: /usr/libexec/ApplicationFirewall/socketfilterfw --add /Applications/Lumen.app"
    echo "             /usr/libexec/ApplicationFirewall/socketfilterfw --unblockapp /Applications/Lumen.app"
fi

# ── 6. Log Lumen/Sunshine ─────────────────────────────────────────────────
section "Log Lumen (50 baris terakhir)"

LUMEN_LOG_PATHS=(
    "$HOME/.cache/sunshine/sunshine.log"
    "$HOME/Library/Logs/lumen.log"
    "$HOME/.config/sunshine/sunshine.log"
    "/tmp/lumen.log"
)

FOUND_LOG=""
for p in "${LUMEN_LOG_PATHS[@]}"; do
    if [[ -f "$p" ]]; then
        FOUND_LOG="$p"
        break
    fi
done

if [[ -n "$FOUND_LOG" ]]; then
    pass "Log ditemukan: $FOUND_LOG"
    echo "--- 50 baris terakhir ---"
    tail -50 "$FOUND_LOG"
    echo "--- end ---"

    # Analisis error umum
    echo ""
    echo "-- Error patterns --"
    grep -iE "error|fail|refused|timeout|denied" "$FOUND_LOG" | tail -20 || echo "(tidak ada error di log)"
else
    warn "Log Lumen tidak ditemukan di lokasi default"
    echo "  Cari dengan: find \$HOME -name '*.log' -newer /tmp -size +0c 2>/dev/null | head -20"
fi

# ── 7. Hostname Mac ────────────────────────────────────────────────────────
section "Hostname Mac (nama yang muncul di Moonlight)"

HOSTNAME=$(scutil --get ComputerName 2>/dev/null || hostname)
LOCAL_HOSTNAME=$(scutil --get LocalHostName 2>/dev/null || echo "unknown")
echo "  ComputerName  : $HOSTNAME"
echo "  LocalHostName : $LOCAL_HOSTNAME"

if echo "$HOSTNAME $LOCAL_HOSTNAME" | grep -qi "macmonitor"; then
    pass "Nama sesuai: 'MacMonitor' (cocok dengan screenshot)"
else
    warn "Nama Mac bukan 'MacMonitor' — mungkin ada config lama yang tersimpan di Moonlight"
fi

# ── 8. Duplikat host di Moonlight ─────────────────────────────────────────
section "Kemungkinan Penyebab Duplikat Host"

echo "  Moonlight menyimpan host berdasarkan UUID + IP."
echo "  Dua entry 'MacMonitor' biasanya terjadi karena:"
echo "   1. IP Tailscale berubah → entry baru dibuat, entry lama stuck dengan error"
echo "   2. Lumen direstart → UUID baru di-generate"
echo "   3. mDNS + Tailscale keduanya aktif → dua jalur discovery"
echo ""
echo "  Fix di iPad:"
echo "   → Tekan lama entry dengan ikon error → Delete"
echo "   → Pastikan hanya 1 entry (Tailscale IP) yang aktif"

# ── Summary ────────────────────────────────────────────────────────────────
section "Ringkasan & Langkah Fix"

cat <<'EOF'
Urutan perbaikan yang direkomendasikan:

1. Di Mac — restart Lumen (bersih):
     pkill -x lumen 2>/dev/null || pkill -x sunshine 2>/dev/null; sleep 2
     open /Applications/Lumen.app

2. Di Mac — pastikan Tailscale aktif dan ambil IP:
     tailscale up
     tailscale ip -4

3. Di iPad (Moonlight):
     a. Hapus SEMUA entry "MacMonitor" yang ada
     b. Ketuk "+ Add Host"
     c. Masukkan IP Tailscale Mac (dari langkah 2)
     d. Pair ulang dengan PIN yang muncul di Mac

4. Kalau masih error:
     - Cek log Lumen (bagian "Log" di atas)
     - Pastikan izin Screen Recording sudah aktif untuk Lumen
     - Nonaktifkan firewall sementara untuk test

EOF

echo "Log lengkap disimpan di: $LOG_FILE"
