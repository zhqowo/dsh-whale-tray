#!/bin/zsh
# Build 大肥鱼 (macOS menu-bar launcher for DSH) and install it to the Desktop.
#
# Self-contained: reads main.swift / icon_compose.swift / whale256.png from this
# script's own directory, so it can be re-run any time:
#     zsh ~/DeepSeekHarness/migration/menubar/build.sh
#
# ⚠️⚠️ READ THIS BEFORE RUNNING ON A MACHINE THAT ALREADY HAS 大肥鱼 INSTALLED
#
# The default run REPLACES ~/Desktop/大肥鱼.app and then launches it. Both halves
# are destructive on a machine where that app already holds TCC grants (Screen
# Recording / Accessibility / Full Disk Access): ad-hoc signatures bind grants to
# the binary's cdhash, so a rebuild silently invalidates all of them, and
# launching the new copy changes the "responsible process" that permissions are
# matched against. See README.md's TCC section.
#
# To build WITHOUT touching the installed app (e.g. to produce a distributable
# zip, or to try a change safely), override the output path:
#
#     WHALE_APP_OUT=/tmp/whale-staging/大肥鱼.app zsh build.sh
#
# In that mode the script never overwrites the Desktop app, never kills a running
# WhaleLauncher, and never launches the result.
#
# Three macOS gotchas this script works around:
#  1. xcrun defaults to MacOSX27.0.sdk (built by Swift 6.4) which the installed
#     Swift 6.3.3 compiler cannot read -> pass -sdk MacOSX26.x.sdk explicitly.
#  2. `SetFile -a C` marks a bundle as "has a custom icon"; with no such resource
#     Finder draws a generic folder icon instead of CFBundleIconFile.
#  3. `cp -R src dst` NESTS when dst exists -> always remove the destination first.
export PATH="$HOME/.local/node/bin:/usr/bin:/bin:/usr/sbin:/sbin"
set -e

HERE="$(cd "$(dirname "$0")" && pwd)"
BUILD="$HOME/whale-menubar-build"
DEFAULT_APP="$HOME/Desktop/大肥鱼.app"
APP="${WHALE_APP_OUT:-$DEFAULT_APP}"
STAGING=0
[ "$APP" != "$DEFAULT_APP" ] && STAGING=1
LSREG=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

# icon framing (tuned by eye)
ICON_SCALE=0.92      # character size as a fraction of the canvas
ICON_OFFSET_Y=0.05   # vertical offset, fraction of canvas (0 = flush to bottom)
ICON_FADE=0.20       # bottom fade height, so the crop's edge dissolves

rm -rf "$BUILD"; mkdir -p "$BUILD/assets"

echo "=== 0. source files ==="
for f in main.swift icon_compose.swift whale256.png; do
  [ -f "$HERE/$f" ] || { echo "missing $HERE/$f"; exit 1; }
done
cp "$HERE/main.swift" "$BUILD/main.swift"
cp "$HERE/icon_compose.swift" "$BUILD/icon_compose.swift"
cp "$HERE/whale256.png" "$BUILD/assets/whale256.png"

SDK=$(/bin/ls -d /Library/Developer/CommandLineTools/SDKs/MacOSX26*.sdk 2>/dev/null | /usr/bin/head -1)
[ -z "$SDK" ] && SDK=$(/bin/ls -d /Library/Developer/CommandLineTools/SDKs/MacOSX*.sdk 2>/dev/null | /usr/bin/grep -v 27 | /usr/bin/head -1)
echo "  SDK: $SDK"

echo "=== 1. menu-bar icon (22pt @1x/@2x, transparent bg) ==="
/usr/bin/sips -z 22 22 "$BUILD/assets/whale256.png" --out "$BUILD/assets/menubar.png" >/dev/null
/usr/bin/sips -z 44 44 "$BUILD/assets/whale256.png" --out "$BUILD/assets/menubar@2x.png" >/dev/null

echo "=== 2. compose the app icon base (gradient + character) ==="
/usr/bin/swiftc -sdk "$SDK" -swift-version 5 -o "$BUILD/icon_compose" "$BUILD/icon_compose.swift" -framework AppKit
"$BUILD/icon_compose" "$BUILD/assets/whale256.png" "$BUILD/assets/icon_base.png" 1024 "$ICON_SCALE" "$ICON_OFFSET_Y" "$ICON_FADE"

echo "=== 3. icns from the composed base ==="
ICONSET="$BUILD/assets/whale.iconset"
rm -rf "$ICONSET"; mkdir -p "$ICONSET"
for s in 16 32 128 256 512; do
  /usr/bin/sips -z $s $s "$BUILD/assets/icon_base.png" --out "$ICONSET/icon_${s}x${s}.png" >/dev/null 2>&1
  /usr/bin/sips -z $((s*2)) $((s*2)) "$BUILD/assets/icon_base.png" --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null 2>&1
done
/usr/bin/iconutil -c icns "$ICONSET" -o "$BUILD/assets/AppIcon.icns"

echo "=== 4. compile the app ==="
cd "$BUILD"
/usr/bin/swiftc -sdk "$SDK" -O -swift-version 5 -o "$BUILD/WhaleLauncher" "$BUILD/main.swift" -framework Cocoa

echo "=== 5. assemble bundle ==="
BUNDLE="$BUILD/大肥鱼.app"
rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources"
cp "$BUILD/WhaleLauncher" "$BUNDLE/Contents/MacOS/WhaleLauncher"
cp "$BUILD/assets/menubar.png" "$BUNDLE/Contents/Resources/whale.png"
cp "$BUILD/assets/menubar@2x.png" "$BUNDLE/Contents/Resources/whale@2x.png"
cp "$BUILD/assets/AppIcon.icns" "$BUNDLE/Contents/Resources/AppIcon.icns"
printf 'APPL????' > "$BUNDLE/Contents/PkgInfo"
cat > "$BUNDLE/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>大肥鱼</string>
    <key>CFBundleDisplayName</key><string>大肥鱼</string>
    <key>CFBundleExecutable</key><string>WhaleLauncher</string>
    <key>CFBundleIdentifier</key><string>local.dsh.whale.menubar</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleSignature</key><string>????</string>
    <key>CFBundleShortVersionString</key><string>2.2</string>
    <key>CFBundleVersion</key><string>4</string>
    <key>LSUIElement</key><true/>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

echo "=== 6. ad-hoc sign ==="
/usr/bin/codesign --force --sign - "$BUNDLE" 2>&1 | tail -1 || true

echo "=== 7. install ==="
if [ "$STAGING" = "1" ]; then
  rm -rf "$APP"
  mkdir -p "$(dirname "$APP")"
  cp -R "$BUNDLE" "$APP"
  echo "  staged at: $APP"
  echo "  (skipped: killing a running WhaleLauncher, replacing the Desktop app, launching)"
  echo "  ⚠️  Do NOT run this build while ~/Desktop/大肥鱼.app is your live install —"
  echo "      two bundles sharing bundle id local.dsh.whale.menubar confuse TCC."
  echo "DONE (staging build, Desktop app untouched)"
  exit 0
fi

pkill -f "WhaleLauncher" 2>/dev/null || true
sleep 1
mkdir -p "$HOME/DeepSeekHarness/migration/old-launcher"
if [ -d "$APP" ]; then
  if [ ! -d "$HOME/DeepSeekHarness/migration/old-launcher/大肥鱼-applescript.app" ]; then
    mv "$APP" "$HOME/DeepSeekHarness/migration/old-launcher/大肥鱼-applescript.app"
  else
    rm -rf "$APP"
  fi
fi
cp -R "$BUNDLE" "$APP"

echo "=== 8. attributes + LaunchServices + Finder refresh ==="
/usr/bin/SetFile -a c "$APP" 2>/dev/null || true
/usr/bin/xattr -c "$APP" 2>/dev/null || true
"$LSREG" -f "$APP" 2>/dev/null || true
/usr/bin/touch "$APP"
/usr/bin/killall iconservicesagent 2>/dev/null || true
rm -rf "$HOME/Library/Caches/com.apple.iconservices" 2>/dev/null || true
/usr/bin/killall Finder 2>/dev/null || true
sleep 3

echo "=== 9. launch ==="
open "$APP"
sleep 3
pgrep -f WhaleLauncher >/dev/null && echo "  ✅ running (pid $(pgrep -f WhaleLauncher | head -1))" || echo "  ❌ not running"

echo "=== 10. verify ==="
echo "  kind : $(/usr/bin/mdls -name kMDItemKind "$APP" 2>/dev/null | cut -d= -f2)"
echo "  icon : $(/usr/libexec/PlistBuddy -c 'Print :CFBundleIconFile' "$APP/Contents/Info.plist").icns"
if [ -f "$HERE/icon_dump.swift" ]; then
  /usr/bin/swiftc -sdk "$SDK" -swift-version 5 -o "$BUILD/icon_dump" "$HERE/icon_dump.swift" -framework AppKit 2>/dev/null \
    && "$BUILD/icon_dump" "$APP" /tmp/icon_final.png 2>/dev/null | grep -E "^wrote" || true
fi
echo "  rendered preview: /tmp/icon_final.png"
echo "DONE"
