#!/usr/bin/env bash
# Step 01 — verify prerequisites and install Homebrew if missing.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
. ./lib.sh

step "01 Prasyarat"
require_macos

# --- Apple Silicon check (Lumen is ARM64-only) ---
arch="$(uname -m)"
if [ "$arch" != "arm64" ]; then
  warn "Arsitektur terdeteksi: $arch (bukan Apple Silicon)."
  warn "Lumen hanya untuk Apple Silicon (M1/M2/M3/M4)."
  warn "Fallback Intel: pakai upstream Sunshine (lebih banyak kendala izin) — lihat docs/TROUBLESHOOTING.md."
  die  "Hentikan: butuh Mac Apple Silicon."
fi
ok "Apple Silicon ($arch)"

# --- macOS version >= 14 (Lumen butuh CGVirtualDisplay API) ---
prod="$(sw_vers -productVersion)"
major="${prod%%.*}"
if [ "$major" -lt 14 ]; then
  warn "macOS $prod terdeteksi. Lumen butuh macOS 14 (Sonoma) atau lebih baru."
  die  "Hentikan: upgrade macOS dulu (atau lihat fallback di docs/TROUBLESHOOTING.md)."
fi
ok "macOS $prod (>= 14)"

# --- Homebrew ---
if ! have brew; then
  info "Homebrew belum ada. Memasang Homebrew (akan minta password sudo)..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  # Make brew available in the current shell for subsequent steps.
  if [ -x /opt/homebrew/bin/brew ]; then eval "$(/opt/homebrew/bin/brew shellenv)"; fi
fi
have brew || die "Homebrew tetap tidak tersedia. Pasang manual: https://brew.sh"
ok "Homebrew: $(brew --version | head -1)"

# --- git (biasanya sudah ada via Command Line Tools) ---
if ! have git; then
  info "Memasang git via Homebrew..."
  brew install git
fi
ok "git: $(git --version)"

ok "Semua prasyarat terpenuhi. Lanjut: scripts/02-tailscale.sh"
