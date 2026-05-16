#!/usr/bin/env bash
# Step 04 — wrap the host binary in a native .app bundle.
#
# WHY: macOS Sequoia/Tahoe ignore Screen Recording requests from a raw CLI
# binary entirely — no prompt, and it never appears under System Settings >
# Privacy & Security > Screen Recording. The fix proven by the community
# ("Native Wrapper Method") is to run the binary from inside a proper .app
# bundle with an Info.plist + bundle identifier so TCC treats it as an app.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
. ./lib.sh

step "04 Native .app wrapper (fix izin Screen Recording macOS modern)"
require_macos

BIN="$(lumen_bin)" || die "Binary host tak ditemukan. Jalankan scripts/03-install-lumen.sh dulu."
real_bin="$(cd "$(dirname "$BIN")" && pwd)/$(basename "$BIN")"

# Already running from inside a .app? Then nothing to do.
case "$real_bin" in
  *.app/Contents/MacOS/*)
    ok "Host sudah berjalan dari dalam .app bundle: $real_bin"
    ok "Tidak perlu wrapper. Lanjut: scripts/05-configure.sh"
    exit 0
    ;;
esac

APP_DIR="${MACMON_APP:-$HOME/Applications/MacMonitorHost.app}"
BUNDLE_ID="com.tokenrouter.macmonitor.host"
info "Membuat wrapper: $APP_DIR"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"

# Launcher: exec the real host binary, forwarding all args.
cat > "$APP_DIR/Contents/MacOS/MacMonitorHost" <<EOF
#!/bin/bash
exec "$real_bin" "\$@"
EOF
chmod +x "$APP_DIR/Contents/MacOS/MacMonitorHost"

cat > "$APP_DIR/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>MacMonitorHost</string>
  <key>CFBundleDisplayName</key><string>Mac Monitor Host</string>
  <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
  <key>CFBundleExecutable</key><string>MacMonitorHost</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleVersion</key><string>1.0</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>NSScreenCaptureUsageDescription</key>
  <string>Streaming layar Mac ke iPhone (monitoring jarak jauh).</string>
  <key>NSAccessibilityUsageDescription</key>
  <string>Mengendalikan mouse/keyboard Mac dari iPhone.</string>
</dict>
</plist>
EOF

# Re-sign ad-hoc so the bundle has a stable code identity for TCC.
if have codesign; then
  if codesign --force --deep --sign - "$APP_DIR" 2>/dev/null; then
    ok "Ad-hoc code signed."
  else
    warn "codesign gagal (ad-hoc). Biasanya tetap jalan; lihat docs/TROUBLESHOOTING.md bila izin bermasalah."
  fi
fi

echo "$APP_DIR" > "$HOME/.config/mac-monitor-app-path"
ok "Wrapper dibuat. JALANKAN HOST LEWAT: open \"$APP_DIR\""
ok "Path disimpan di ~/.config/mac-monitor-app-path"
ok "Lanjut: scripts/05-configure.sh"
