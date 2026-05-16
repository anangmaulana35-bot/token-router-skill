#!/usr/bin/env bash
# Orchestrator — runs steps 01..07 in order. Steps with manual prompts
# (02, 06) will pause for input. Re-runnable (idempotent).
# Usage: scripts/run-all.sh [--mode monitor|virtual] [--no-autostart]
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
. ./lib.sh

MODE="monitor"; DO_AUTOSTART=1
while [ $# -gt 0 ]; do
  case "$1" in
    --mode) MODE="${2:-}"; shift 2 ;;
    --mode=*) MODE="${1#*=}"; shift ;;
    --no-autostart) DO_AUTOSTART=0; shift ;;
    *) die "Argumen tak dikenal: $1" ;;
  esac
done

step "RUN-ALL (mode=$MODE, autostart=$DO_AUTOSTART)"
bash ./01-prereqs.sh
bash ./02-tailscale.sh
bash ./03-install-lumen.sh
bash ./04-app-bundle-wrap.sh
bash ./05-configure.sh --mode "$MODE"
bash ./06-permissions.sh
if [ "$DO_AUTOSTART" -eq 1 ]; then
  bash ./07-autostart.sh
else
  warn "Lewati autostart (--no-autostart). Jalankan host manual: open \"\$(cat ~/.config/mac-monitor-app-path)\""
fi

cat <<'EOF'

  ============================================================
  SETUP SELESAI. Langkah pairing terakhir (lihat docs/PAIRING.md):
   1. Buka https://localhost:47990 di Mac -> set username/password.
   2. iPhone: Tailscale ON + Moonlight terpasang.
   3. Moonlight -> "+" Add PC -> ketik Tailscale IP Mac
      (cat ~/.config/mac-monitor-tailscale-ip).
   4. Moonlight tampilkan PIN -> masukkan di web UI -> Pair.
   5. Pilih "Desktop" -> mulai streaming + kontrol.
  ============================================================
EOF
