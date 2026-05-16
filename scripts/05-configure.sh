#!/usr/bin/env bash
# Step 05 — install host config (apps.json + sunshine.conf) with a display mode.
# Usage: scripts/05-configure.sh [--mode monitor|virtual]   (default: monitor)
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
. ./lib.sh

step "05 Konfigurasi host"
require_macos

MODE="monitor"
while [ $# -gt 0 ]; do
  case "$1" in
    --mode) MODE="${2:-}"; shift 2 ;;
    --mode=*) MODE="${1#*=}"; shift ;;
    *) die "Argumen tak dikenal: $1 (pakai: --mode monitor|virtual)" ;;
  esac
done
case "$MODE" in
  monitor|virtual) ;;
  *) die "Mode tidak valid: '$MODE'. Pilih: monitor | virtual." ;;
esac
info "Mode tampilan: $MODE"

CFG_DIR="$HOME/.config/sunshine"
mkdir -p "$CFG_DIR"
REPO_ROOT="$(cd .. && pwd)"

# apps.json — entri "Desktop" (stream tanpa command).
cp "$REPO_ROOT/config/apps.json" "$CFG_DIR/apps.json"
ok "apps.json -> $CFG_DIR/apps.json"

# sunshine.conf dari template, ganti placeholder __MODE__.
sed "s/__MODE__/$MODE/g" "$REPO_ROOT/config/sunshine.conf.tmpl" > "$CFG_DIR/sunshine.conf"
ok "sunshine.conf -> $CFG_DIR/sunshine.conf (mode=$MODE)"

cat <<EOF

  Catatan mode:
   - monitor : iPhone melihat layar Mac yang SEDANG dipakai (pemantauan nyata).
               Untuk memilih display tertentu pada Mac multi-monitor, atur
               'Output Name' di web UI https://localhost:47990 (tab Configuration).
   - virtual : Lumen membuat virtual display seukuran resolusi iPhone saat
               koneksi (sesi kerja terpisah, layar Mac tidak terganggu).

  Bitrate/FPS/Resolusi diatur dari sisi iPhone di app Moonlight
  (Settings) dan diikuti server secara adaptif.
EOF

ok "Selesai. Lanjut: scripts/06-permissions.sh"
