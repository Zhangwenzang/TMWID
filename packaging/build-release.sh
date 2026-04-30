#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_NAME="Tmwid"
DISPLAY_NAME="Tell Me When It's Done"
VERSION="${1:-1.0.0}"
BUILD_DIR="$PROJECT_DIR/.build/release"
DIST_DIR="$PROJECT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
DMG_NAME="$APP_NAME-$VERSION.dmg"

echo "=== Building $APP_NAME v$VERSION ==="

# 1. Build release binary (universal: arm64 + x86_64)
echo "[1/5] Building release binary (universal)..."
cd "$PROJECT_DIR"
swift build -c release --arch arm64 --arch x86_64 2>&1

# SPM universal build places output under .build/apple/Products/Release
UNIVERSAL_BUILD_DIR="$PROJECT_DIR/.build/apple/Products/Release"
if [ -f "$UNIVERSAL_BUILD_DIR/$APP_NAME" ]; then
    BUILD_DIR="$UNIVERSAL_BUILD_DIR"
fi

# 2. Create .iconset from animation frame
echo "[2/5] Creating app icon..."
ICON_SOURCE="$PROJECT_DIR/assets/frames/working/001.png"
ICONSET_DIR="$DIST_DIR/AppIcon.iconset"
rm -rf "$ICONSET_DIR"
mkdir -p "$ICONSET_DIR"

# Generate all required icon sizes from 640x640 source
for size in 16 32 128 256 512; do
    sips -z $size $size "$ICON_SOURCE" --out "$ICONSET_DIR/icon_${size}x${size}.png" >/dev/null 2>&1
done
# @2x variants
for size in 16 32 128 256; do
    double=$((size * 2))
    sips -z $double $double "$ICON_SOURCE" --out "$ICONSET_DIR/icon_${size}x${size}@2x.png" >/dev/null 2>&1
done
# 512@2x = 1024 (upscale from 640)
sips -z 1024 1024 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_512x512@2x.png" >/dev/null 2>&1

# Convert to .icns
iconutil -c icns "$ICONSET_DIR" -o "$DIST_DIR/AppIcon.icns"
rm -rf "$ICONSET_DIR"

# 3. Assemble .app bundle
echo "[3/5] Assembling .app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy executable
cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

# Copy resource bundle next to executable (matching FrameAnimator.resourceBundle() lookup)
if [ -d "$BUILD_DIR/Tmwid_Tmwid.bundle" ]; then
    cp -R "$BUILD_DIR/Tmwid_Tmwid.bundle" "$APP_BUNDLE/Contents/MacOS/"
fi

# Copy Info.plist and patch version
cp "$SCRIPT_DIR/Info.plist" "$APP_BUNDLE/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $VERSION" "$APP_BUNDLE/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP_BUNDLE/Contents/Info.plist"

# Copy icon
cp "$DIST_DIR/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"

# Write PkgInfo
echo -n "APPL????" > "$APP_BUNDLE/Contents/PkgInfo"

echo "    .app bundle created at: $APP_BUNDLE"

# 4. Create DMG
echo "[4/5] Creating DMG..."
DMG_PATH="$DIST_DIR/$DMG_NAME"
DMG_TMP="$DIST_DIR/tmp-dmg"
rm -rf "$DMG_TMP" "$DMG_PATH"
mkdir -p "$DMG_TMP"

# Copy .app into DMG staging area
cp -R "$APP_BUNDLE" "$DMG_TMP/"

# Create symlink to /Applications for drag-install
ln -s /Applications "$DMG_TMP/Applications"

# Create DMG
hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$DMG_TMP" \
    -ov \
    -format UDZO \
    "$DMG_PATH" >/dev/null 2>&1

rm -rf "$DMG_TMP"

echo "    DMG created at: $DMG_PATH"

# 5. Summary
echo ""
echo "[5/5] Done!"
DMG_SIZE=$(du -sh "$DMG_PATH" | cut -f1)
APP_SIZE=$(du -sh "$APP_BUNDLE" | cut -f1)
echo "    App:     $APP_BUNDLE ($APP_SIZE)"
echo "    DMG:     $DMG_PATH ($DMG_SIZE)"
echo "    Version: $VERSION"
echo ""
echo "To install: open $DMG_PATH, drag $APP_NAME to Applications."
