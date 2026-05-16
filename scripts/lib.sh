#!/usr/bin/env bash
# Shared helpers for the mac-monitor setup scripts. Sourced by every step.
set -euo pipefail

c_reset=$'\033[0m'; c_red=$'\033[31m'; c_grn=$'\033[32m'; c_ylw=$'\033[33m'; c_blu=$'\033[34m'

info()  { printf '%s[*]%s %s\n' "$c_blu" "$c_reset" "$*"; }
ok()    { printf '%s[ok]%s %s\n' "$c_grn" "$c_reset" "$*"; }
warn()  { printf '%s[!]%s %s\n' "$c_ylw" "$c_reset" "$*" >&2; }
die()   { printf '%s[x]%s %s\n' "$c_red" "$c_reset" "$*" >&2; exit 1; }
step()  { printf '\n%s=== %s ===%s\n' "$c_blu" "$*" "$c_reset"; }

have()  { command -v "$1" >/dev/null 2>&1; }

# Resolve the tailscale CLI whether it came from the brew formula or the GUI app.
tailscale_bin() {
  if have tailscale; then echo tailscale; return 0; fi
  local app="/Applications/Tailscale.app/Contents/MacOS/Tailscale"
  [ -x "$app" ] && { echo "$app"; return 0; }
  return 1
}

# Resolve the lumen/sunshine host binary installed by Lumen's install.sh.
lumen_bin() {
  local cands=(
    "$HOME/.local/bin/lumen"
    "$HOME/.local/share/lumen/bin/sunshine"
    "$HOME/.local/share/lumen/sunshine"
  )
  local p
  for p in "${cands[@]}"; do [ -x "$p" ] && { echo "$p"; return 0; }; done
  if have lumen; then command -v lumen; return 0; fi
  return 1
}

require_macos() {
  [ "$(uname -s)" = "Darwin" ] || die "Skrip ini hanya untuk macOS. OS terdeteksi: $(uname -s)."
}
