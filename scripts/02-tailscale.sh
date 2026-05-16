#!/usr/bin/env bash
# Step 02 — install Tailscale on the Mac and bring it online.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
. ./lib.sh

step "02 Tailscale (transport gratis, dari mana saja)"
require_macos
have brew || die "Homebrew belum ada. Jalankan scripts/01-prereqs.sh dulu."

if ! tailscale_bin >/dev/null 2>&1; then
  info "Memasang Tailscale (cask GUI)..."
  brew install --cask tailscale
fi

TS="$(tailscale_bin)" || die "Tailscale terpasang tapi CLI tidak ditemukan. Buka app Tailscale dari Launchpad lalu login."
ok "Tailscale CLI: $TS"

info "Membuka app Tailscale — login dengan akun (Google/GitHub/email)."
open -a Tailscale 2>/dev/null || warn "Tidak bisa auto-open. Buka 'Tailscale' dari Launchpad secara manual."

cat <<'EOF'

  >> LAKUKAN SEKARANG:
     1. Di menu bar Mac, klik ikon Tailscale -> Log in -> selesaikan login di browser.
     2. Di iPhone: install app "Tailscale" dari App Store -> login dengan AKUN YANG SAMA.

  Setelah Mac sudah login, tekan ENTER untuk menampilkan Tailscale IP-nya.
EOF
read -r _

# Bring the node up (no-op if already up); ignore failure if GUI already handled it.
"$TS" up 2>/dev/null || true

ip4="$("$TS" ip -4 2>/dev/null | head -1 || true)"
if [ -z "${ip4:-}" ]; then
  warn "Tailscale IP belum terbaca. Pastikan sudah login (ikon menu bar hijau), lalu jalankan: $TS ip -4"
else
  ok "Tailscale IP Mac ini: $ip4"
  echo "$ip4" > "$HOME/.config/mac-monitor-tailscale-ip" 2>/dev/null || \
    { mkdir -p "$HOME/.config" && echo "$ip4" > "$HOME/.config/mac-monitor-tailscale-ip"; }
  info "IP disimpan di ~/.config/mac-monitor-tailscale-ip (dipakai saat pairing di iPhone)."
fi

ok "Selesai. Lanjut: scripts/03-install-lumen.sh"
