#!/usr/bin/env bash
# Step 07 (opsional) — start the host automatically at login via LaunchAgent.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
. ./lib.sh

step "07 Autostart saat login (opsional)"
require_macos

APP_PATH="$(cat "$HOME/.config/mac-monitor-app-path" 2>/dev/null || true)"
if [ -n "$APP_PATH" ] && [ -x "$APP_PATH/Contents/MacOS/MacMonitorHost" ]; then
  PROG="$APP_PATH/Contents/MacOS/MacMonitorHost"   # keep the .app TCC identity
else
  PROG="$(lumen_bin)" || die "Binary host tak ditemukan. Jalankan 03 & 04 dulu."
fi
ok "Program autostart: $PROG"

LA_DIR="$HOME/Library/LaunchAgents"
LABEL="com.tokenrouter.macmonitor.host"
PLIST="$LA_DIR/$LABEL.plist"
LOG_DIR="$HOME/Library/Logs/MacMonitor"
mkdir -p "$LA_DIR" "$LOG_DIR"

cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key>
  <array><string>$PROG</string></array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>StandardOutPath</key><string>$LOG_DIR/host.out.log</string>
  <key>StandardErrorPath</key><string>$LOG_DIR/host.err.log</string>
</dict>
</plist>
EOF
ok "LaunchAgent ditulis: $PLIST"

# Reload idempotently.
launchctl unload "$PLIST" 2>/dev/null || true
launchctl load "$PLIST"
ok "Host dimuat via launchctl. Log: $LOG_DIR/"

cat <<EOF

  Untuk menonaktifkan autostart nanti:
    launchctl unload "$PLIST" && rm "$PLIST"

EOF
ok "Selesai. Lakukan pairing: lihat docs/PAIRING.md"
