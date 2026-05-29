#!/bin/zsh
set -euo pipefail

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  cat <<'EOF'
Usage: ./scripts/package_dmg.sh [version]

Builds a local ad-hoc signed Rhythm.app bundle under dist/.
By default it also creates a DMG beside the app bundle.

Environment variables:
  SKIP_BUILD=1   Reuse the existing release build output
  SKIP_DMG=1     Build/update dist/Rhythm.app without creating a DMG
  BUILD_NUMBER   Override CFBundleVersion (defaults to git commit count or 1)
  RHYTHM_RELEASE=1
                 Build a direct-release bundle with Developer ID signing metadata
  RHYTHM_SIGNING_IDENTITY
                 Developer ID Application identity for RHYTHM_RELEASE=1
  RHYTHM_SPARKLE_PUBLIC_ED_KEY
                 Sparkle EdDSA public key for RHYTHM_RELEASE=1
  CREATE_ZIP=1   Also create dist/Rhythm-macos-universal-<version>.zip for Sparkle
EOF
  exit 0
fi

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${1:-$(git -C "$ROOT_DIR" describe --tags --abbrev=0 2>/dev/null || echo 0.0.0)}"
BUILD_NUMBER="${BUILD_NUMBER:-$(git -C "$ROOT_DIR" rev-list --count HEAD 2>/dev/null || echo 1)}"
SKIP_BUILD="${SKIP_BUILD:-0}"
SKIP_DMG="${SKIP_DMG:-0}"
RHYTHM_RELEASE="${RHYTHM_RELEASE:-0}"
CREATE_ZIP="${CREATE_ZIP:-$RHYTHM_RELEASE}"
APP_NAME="Rhythm"
BUNDLE_ID="com.xiao2dou.rhythm"
ICON_BASENAME="Rhythm"
FEED_URL="${RHYTHM_FEED_URL:-https://raw.githubusercontent.com/rray89/rhythm/main/appcast.xml}"
SPARKLE_PUBLIC_ED_KEY="${RHYTHM_SPARKLE_PUBLIC_ED_KEY:-}"
SIGNING_IDENTITY="${RHYTHM_SIGNING_IDENTITY:-}"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/${APP_NAME}.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
FRAMEWORKS_DIR="$CONTENTS_DIR/Frameworks"
ICON_PATH="$ROOT_DIR/assets/${ICON_BASENAME}.icns"
DMG_ROOT="$DIST_DIR/dmg-root"
DMG_PATH="$DIST_DIR/${APP_NAME}-${VERSION}.dmg"
ZIP_PATH="$DIST_DIR/${APP_NAME}-macos-universal-${VERSION}.zip"
BUILD_TIMESTAMP="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
GIT_COMMIT="$(git -C "$ROOT_DIR" rev-parse --short HEAD 2>/dev/null || echo unknown)"

if [[ "$RHYTHM_RELEASE" == "1" ]]; then
  if [[ -z "$SIGNING_IDENTITY" ]]; then
    echo "RHYTHM_RELEASE=1 requires RHYTHM_SIGNING_IDENTITY."
    exit 1
  fi
  if [[ -z "$SPARKLE_PUBLIC_ED_KEY" ]]; then
    echo "RHYTHM_RELEASE=1 requires RHYTHM_SPARKLE_PUBLIC_ED_KEY."
    exit 1
  fi
fi

if [[ "$SKIP_BUILD" != "1" ]]; then
  echo "[1/5] Building release binary..."
  if [[ "$RHYTHM_RELEASE" == "1" ]]; then
    RHYTHM_ENABLE_SPARKLE=1 swift build -c release --product "$APP_NAME" --package-path "$ROOT_DIR"
  else
    swift build -c release --product "$APP_NAME" --package-path "$ROOT_DIR"
  fi
else
  echo "[1/5] Skipping build (SKIP_BUILD=1)..."
fi

if [[ "$RHYTHM_RELEASE" == "1" ]]; then
  BIN_DIR="$(RHYTHM_ENABLE_SPARKLE=1 swift build -c release --show-bin-path --package-path "$ROOT_DIR")"
else
  BIN_DIR="$(swift build -c release --show-bin-path --package-path "$ROOT_DIR")"
fi
EXEC_PATH="$BIN_DIR/$APP_NAME"
if [[ -z "$EXEC_PATH" ]]; then
  echo "Release executable not found."
  exit 1
fi
if [[ ! -x "$EXEC_PATH" ]]; then
  echo "Release executable not found at $EXEC_PATH."
  exit 1
fi

echo "[2/5] Preparing app bundle..."
rm -rf "$APP_DIR" "$DMG_ROOT" "$DMG_PATH" "$ZIP_PATH"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR" "$FRAMEWORKS_DIR" "$DMG_ROOT"
cp "$EXEC_PATH" "$MACOS_DIR/$APP_NAME"
chmod +x "$MACOS_DIR/$APP_NAME"

if [[ -f "$ICON_PATH" ]]; then
  cp "$ICON_PATH" "$RESOURCES_DIR/${ICON_BASENAME}.icns"
else
  echo "Warning: $ICON_PATH not found, app icon will fallback to default."
fi

cat > "$CONTENTS_DIR/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDisplayName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleIconFile</key>
    <string>${ICON_BASENAME}</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${BUILD_NUMBER}</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>© 2026 Rhythm. MIT License.</string>
    <key>RhythmBuildTimestamp</key>
    <string>${BUILD_TIMESTAMP}</string>
    <key>RhythmGitCommit</key>
    <string>${GIT_COMMIT}</string>
EOF

if [[ "$RHYTHM_RELEASE" == "1" ]]; then
  cat >> "$CONTENTS_DIR/Info.plist" <<EOF
    <key>SUFeedURL</key>
    <string>${FEED_URL}</string>
    <key>SUPublicEDKey</key>
    <string>${SPARKLE_PUBLIC_ED_KEY}</string>
    <key>SUAutomaticallyUpdate</key>
    <false/>
EOF
fi

cat >> "$CONTENTS_DIR/Info.plist" <<EOF
</dict>
</plist>
EOF

SPARKLE_FRAMEWORK="$BIN_DIR/Sparkle.framework"
if [[ -d "$SPARKLE_FRAMEWORK" ]]; then
  echo "[3/5] Embedding Sparkle.framework..."
  ditto "$SPARKLE_FRAMEWORK" "$FRAMEWORKS_DIR/Sparkle.framework"
  chmod -R a+rX "$FRAMEWORKS_DIR/Sparkle.framework"
  install_name_tool -delete_rpath "@executable_path/../Frameworks" "$MACOS_DIR/$APP_NAME" 2>/dev/null || true
  install_name_tool -add_rpath "@executable_path/../Frameworks" "$MACOS_DIR/$APP_NAME"
else
  echo "[3/5] Sparkle.framework not found beside build output; continuing without embedded framework..."
fi

if [[ "$RHYTHM_RELEASE" == "1" ]]; then
  CODESIGN_ARGS=(--force --timestamp --options runtime --sign "$SIGNING_IDENTITY")
else
  CODESIGN_ARGS=(--force --sign -)
fi

sign_if_exists() {
  local path="$1"
  [[ -e "$path" ]] || return 0
  codesign "${CODESIGN_ARGS[@]}" "$path"
}

echo "[4/5] Applying code signatures..."
if [[ -d "$FRAMEWORKS_DIR/Sparkle.framework" ]]; then
  SPARKLE="$FRAMEWORKS_DIR/Sparkle.framework"
  sign_if_exists "$SPARKLE/Versions/B/Sparkle"
  sign_if_exists "$SPARKLE/Versions/B/Autoupdate"
  sign_if_exists "$SPARKLE/Versions/B/Updater.app/Contents/MacOS/Updater"
  sign_if_exists "$SPARKLE/Versions/B/Updater.app"
  sign_if_exists "$SPARKLE/Versions/B/XPCServices/Downloader.xpc/Contents/MacOS/Downloader"
  sign_if_exists "$SPARKLE/Versions/B/XPCServices/Downloader.xpc"
  sign_if_exists "$SPARKLE/Versions/B/XPCServices/Installer.xpc/Contents/MacOS/Installer"
  sign_if_exists "$SPARKLE/Versions/B/XPCServices/Installer.xpc"
  sign_if_exists "$SPARKLE/Versions/B"
  sign_if_exists "$SPARKLE"
fi
codesign "${CODESIGN_ARGS[@]}" "$APP_DIR"

if [[ "$SKIP_DMG" == "1" ]]; then
  rm -rf "$DMG_ROOT"
  if [[ "$CREATE_ZIP" == "1" ]]; then
    echo "Creating Sparkle ZIP..."
    (cd "$DIST_DIR" && ditto -c -k --sequesterRsrc --keepParent "${APP_NAME}.app" "$ZIP_PATH")
  fi
  echo "Done: $APP_DIR"
  if [[ "$RHYTHM_RELEASE" == "1" ]]; then
    echo "Release note: notarize $APP_DIR and sign the update archive for appcast.xml before publishing."
  else
    echo "Local note: this app bundle is ad-hoc signed for convenience, not notarized."
  fi
  exit 0
fi

echo "[5/5] Creating DMG layout..."
cp -R "$APP_DIR" "$DMG_ROOT/"
ln -s /Applications "$DMG_ROOT/Applications"

echo "Building DMG..."
hdiutil create \
  -volname "${APP_NAME} ${VERSION}" \
  -srcfolder "$DMG_ROOT" \
  -ov \
  -format UDZO \
  "$DMG_PATH" >/dev/null

rm -rf "$DMG_ROOT"

if [[ "$CREATE_ZIP" == "1" ]]; then
  echo "Creating Sparkle ZIP..."
  (cd "$DIST_DIR" && ditto -c -k --sequesterRsrc --keepParent "${APP_NAME}.app" "$ZIP_PATH")
fi

echo "Done: $DMG_PATH"
if [[ "$CREATE_ZIP" == "1" ]]; then
  echo "Sparkle ZIP: $ZIP_PATH"
fi
echo "App bundle: $APP_DIR"
if [[ "$RHYTHM_RELEASE" == "1" ]]; then
  echo "Release note: notarize the DMG/ZIP and update appcast.xml before publishing."
else
  echo "Local note: this DMG is ad-hoc signed for convenience, not notarized."
fi
