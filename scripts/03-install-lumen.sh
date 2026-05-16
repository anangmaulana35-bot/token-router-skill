#!/usr/bin/env bash
# Step 03 — clone and build Lumen (Sunshine fork for macOS Apple Silicon).
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
. ./lib.sh

step "03 Install Lumen (ScreenCaptureKit + VideoToolbox HEVC host)"
require_macos
have brew || die "Homebrew belum ada. Jalankan scripts/01-prereqs.sh dulu."

SRC="${LUMEN_SRC:-$HOME/.local/src/Lumen}"
mkdir -p "$(dirname "$SRC")"

if [ -d "$SRC/.git" ]; then
  info "Repo Lumen sudah ada di $SRC — update (git pull)..."
  git -C "$SRC" pull --ff-only || warn "git pull gagal, melanjutkan dengan kode yang ada."
else
  info "Clone Lumen ke $SRC ..."
  git clone https://github.com/trollzem/Lumen.git "$SRC"
fi

info "Menjalankan install.sh Lumen (build dari source: cmake, boost, openssl@3, opus, llvm, node, icu4c, miniupnpc)."
info "Ini bisa lama (beberapa menit) tergantung mesin."
( cd "$SRC" && chmod +x ./install.sh && ./install.sh )

if BIN="$(lumen_bin)"; then
  ok "Host terpasang: $BIN"
else
  warn "Build selesai tapi binary host tak terdeteksi di lokasi umum."
  warn "Cek output install.sh di atas; sesuaikan lumen_bin() di scripts/lib.sh bila path beda."
  die  "Hentikan: binary host tidak ditemukan."
fi

ok "Selesai. Lanjut: scripts/04-app-bundle-wrap.sh"
