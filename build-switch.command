#!/bin/bash
# Builds the Sunshine Switch menu-bar app, and makes Sunshine run as a login service (brew services).
set -e
SRC="$(cd "$(dirname "$0")" && pwd)"
exec > >(tee "$SRC/build-switch.log") 2>&1
APP="$HOME/Applications/Sunshine Switch.app"

# Signing: use your Apple developer certificate from the login keychain so macOS permissions
# (Accessibility, Screen Recording...) survive rebuilds. Override with SIGN_IDENTITY="<hash or name>".
pick_identity() {
  local ids kind h
  ids=$(security find-identity -v -p codesigning 2>/dev/null); echo "$ids" | grep -q "Apple\|Developer" || ids=$(security find-identity -p codesigning 2>/dev/null)
  for kind in "Developer ID Application" "Apple Development" "Mac Developer" "Apple Distribution" "3rd Party Mac Developer Application" "iPhone Developer" "Developer ID"; do
    h=$(echo "$ids" | grep "$kind" | head -1 | awk '{print $2}')
    if [ -n "$h" ]; then echo "$h"; return; fi
  done
}
sign_app() {
  local app="$1" id
  id="${SIGN_IDENTITY:-$(pick_identity)}"
  if [ -n "$id" ]; then
    echo "Signing with certificate $id"
    if codesign --force --deep --timestamp=none --sign "$id" "$app"; then
      codesign -dv "$app" 2>&1 | grep -E "Authority=|TeamIdentifier|Identifier=" | head -5
      return
    fi
    echo "Certificate signing failed; falling back to an ad-hoc signature."
  else
    echo "No signing certificate found; using an ad-hoc signature."
  fi
  codesign --force --deep --sign - "$app"
}
if ! xcrun --find swiftc >/dev/null 2>&1; then echo "Swift compiler not found. Run: xcode-select --install"; exit 1; fi

pkill -x SunshineSwitch 2>/dev/null || true
rm -rf "$APP"
mkdir -p "$HOME/Applications" "$APP/Contents/MacOS"
echo "Compiling Sunshine Switch..."
swiftc -O -swift-version 5 -target "$(uname -m)-apple-macos14.0" \
  -o "$APP/Contents/MacOS/SunshineSwitch" "$SRC/Switch/SunshineSwitch.swift"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>net.steamretriever.sunshineswitch</string>
  <key>CFBundleName</key><string>Sunshine Switch</string>
  <key>CFBundleExecutable</key><string>SunshineSwitch</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>NSRemovableVolumesUsageDescription</key><string>Sunshine Switch writes a small log on the STEAM drive.</string>
</dict></plist>
PLIST
sign_app "$APP"

BREW="$(ls /opt/homebrew/bin/brew /usr/local/bin/brew 2>/dev/null | head -1)"
if [ -n "$BREW" ]; then
  echo "Starting Sunshine as a login service (use the menu-bar icon to pause it)..."
  pkill -x sunshine 2>/dev/null || true
  sleep 1
  HOMEBREW_NO_AUTO_UPDATE=1 "$BREW" services start lizardbyte/homebrew/sunshine || echo "brew services start failed; use the menu-bar icon's Resume item to retry."
fi
open "$APP"
echo
echo "Done. Look for the sun icon in the menu bar."
