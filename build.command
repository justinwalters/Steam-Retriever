#!/bin/bash
# Builds Steam Retriever (native Swift app), installs it to ~/Applications, replaces the old Steam Hub.
set -e
SRC="$(cd "$(dirname "$0")" && pwd)"
exec > >(tee "$SRC/build.log") 2>&1
APP="$HOME/Applications/Steam Retriever.app"

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
BUILD="$(mktemp -d)"

if ! xcrun --find swiftc >/dev/null 2>&1; then
  echo "Swift compiler not found. Run:  xcode-select --install   then run this again."
  exit 1
fi

echo "--- toolchain"
xcode-select -p || true
swiftc --version || true
xcrun --show-sdk-path || true
SDK="$(xcrun --show-sdk-path)"
PLUGDIRS=""
for d in "$(xcode-select -p)/usr/lib/swift/host/plugins" "$(xcode-select -p)/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/host/plugins" \
         "$SDK/usr/lib/swift/host/plugins" "/Library/Developer/CommandLineTools/usr/lib/swift/host/plugins" ; do
  if [ -d "$d" ]; then echo "plugin dir: $d"; ls "$d" | head -20; fi
done
echo "--- SwiftUIMacros on this Mac:"
find /Applications/Xcode*.app /Library/Developer "$SDK" -iname "*SwiftUIMacros*" 2>/dev/null | head -10
echo "---"

echo "Retiring the old Python hub..."
launchctl bootout "gui/$(id -u)/net.steamhub.launcher" 2>/dev/null || true
rm -f "$HOME/Library/LaunchAgents/net.steamhub.launcher.plist"
pkill -f steamhub.py 2>/dev/null || true
rm -rf "$HOME/Library/Application Support/SteamHub/Steam Hub Server.app" \
       "$HOME/Library/Application Support/SteamHub/steamhub.py" \
       "$HOME/Library/Application Support/SteamHub/index.html" \
       "$HOME/Library/Application Support/SteamHub/config.json" \
       "$HOME/Desktop/Steam Hub.app"

echo "Compiling..."
mkdir -p "$HOME/Applications"
pkill -x SteamHub 2>/dev/null || true
pkill -x SteamRetriever 2>/dev/null || true
rm -rf "$HOME/Applications/Steam Hub.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
swiftc -O -swift-version 5 -parse-as-library \
  -target "$(uname -m)-apple-macos14.0" \
  -o "$APP/Contents/MacOS/SteamRetriever" "$SRC"/Sources/*.swift

echo "Copying the pup art..."
for f in "$SRC"/Art/*.png "$SRC"/Art/*.jpg; do
  [ -f "$f" ] && [ "$(basename "$f")" != "icon1024.png" ] && cp "$f" "$APP/Contents/Resources/"
done

echo "Making the icon..."
ICONSET="$BUILD/AppIcon.iconset"
mkdir -p "$ICONSET"
for s in 16 32 128 256 512; do
  sips -z $s $s "$SRC/Art/icon1024.png" --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
  d=$((s*2))
  sips -z $d $d "$SRC/Art/icon1024.png" --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>net.steamretriever.app</string>
  <key>CFBundleName</key><string>Steam Retriever</string>
  <key>CFBundleDisplayName</key><string>Steam Retriever</string>
  <key>CFBundleExecutable</key><string>SteamRetriever</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.games</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSLocalNetworkUsageDescription</key><string>Steam Retriever lets your Apple TV see your games and start them.</string>
  <key>NSBonjourServices</key><array><string>_steamretriever._tcp</string></array>
  <key>NSRemovableVolumesUsageDescription</key><string>Steam Retriever reads your game libraries on the STEAM drive.</string>
</dict></plist>
EOF
sign_app "$APP"
rm -rf "$BUILD"

# Desktop shortcut (Finder alias, falls back to a symlink).
rm -rf "$HOME/Desktop/Steam Hub" "$HOME/Desktop/Steam Hub alias" "$HOME/Desktop/Steam Retriever" "$HOME/Desktop/Steam Retriever alias"
osascript -e "tell application \"Finder\" to make new alias file to POSIX file \"$APP\" at desktop with properties {name:\"Steam Retriever\"}" >/dev/null 2>&1 \
  || ln -sf "$APP" "$HOME/Desktop/Steam Retriever"

echo
echo "Steam Retriever installed: $APP"
echo "If macOS asks to let Steam Retriever access a removable volume, click Allow."
open "$APP"
