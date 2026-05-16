#!/usr/bin/env bash
# Step 06 — guide the user through the macOS privacy permissions the host needs.
# These CANNOT be granted from a script (TCC requires manual user action);
# this opens the right panels and explains exactly what to toggle.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
. ./lib.sh

step "06 Izin macOS (manual — wajib)"
require_macos

APP_PATH="$(cat "$HOME/.config/mac-monitor-app-path" 2>/dev/null || true)"
TARGET_DESC="${APP_PATH:-binary host Lumen}"

cat <<EOF

  Host yang harus diberi izin: ${TARGET_DESC}

  Berikan 3 izin ini di System Settings > Privacy & Security:

   1. Screen Recording   -> WAJIB. Tanpa ini iPhone hanya melihat layar hitam.
   2. Accessibility      -> WAJIB untuk kontrol (klik/ketik dari iPhone).
   3. Input Monitoring   -> diperlukan sebagian versi macOS untuk keyboard.

  Cara: di tiap panel, klik "+", tambahkan host di atas, lalu AKTIFKAN toggle-nya.
  Setelah menambah Screen Recording, macOS minta keluar/buka ulang host — itu normal.

EOF

info "Membuka panel Screen Recording..."
open "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture" || true
read -r -p "  Tekan ENTER setelah Screen Recording diaktifkan... " _

info "Membuka panel Accessibility..."
open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility" || true
read -r -p "  Tekan ENTER setelah Accessibility diaktifkan... " _

info "Membuka panel Input Monitoring..."
open "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent" || true
read -r -p "  Tekan ENTER setelah Input Monitoring diaktifkan... " _

cat <<'EOF'

  (Opsional) Audio sistem ke iPhone:
    macOS tidak mengizinkan capture audio sistem langsung. Untuk ikut
    streaming audio, pasang BlackHole:  brew install blackhole-2ch
    lalu set sebagai output di System Settings > Sound. (Lewati bila
    hanya butuh lihat + kontrol.)

EOF
ok "Izin selesai. Lanjut: scripts/07-autostart.sh (opsional) lalu docs/PAIRING.md"
