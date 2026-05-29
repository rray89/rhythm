#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RELEASE_DIR="${1:-$ROOT_DIR/dist}"
APPCAST_PATH="${APPCAST_PATH:-$ROOT_DIR/appcast.xml}"
SPARKLE_GENERATE_APPCAST="${SPARKLE_GENERATE_APPCAST:-}"
DOWNLOAD_URL_PREFIX="${RHYTHM_DOWNLOAD_URL_PREFIX:-https://github.com/rray89/rhythm/releases/download}"

if [[ -z "$SPARKLE_GENERATE_APPCAST" ]]; then
  for candidate in \
    "$ROOT_DIR/.build/artifacts/sparkle/Sparkle/bin/generate_appcast" \
    "$ROOT_DIR/.build/artifacts/sparkle/Sparkle.artifactbundle/bin/generate_appcast"; do
    if [[ -x "$candidate" ]]; then
      SPARKLE_GENERATE_APPCAST="$candidate"
      break
    fi
  done
fi

if [[ -z "$SPARKLE_GENERATE_APPCAST" || ! -x "$SPARKLE_GENERATE_APPCAST" ]]; then
  cat >&2 <<'EOF'
Sparkle generate_appcast was not found.

Run a release build with RHYTHM_ENABLE_SPARKLE=1 or set:
  SPARKLE_GENERATE_APPCAST=/path/to/generate_appcast
EOF
  exit 1
fi

if [[ ! -d "$RELEASE_DIR" ]]; then
  echo "Release directory not found: $RELEASE_DIR" >&2
  exit 1
fi

"$SPARKLE_GENERATE_APPCAST" \
  --link "https://github.com/rray89/rhythm" \
  --download-url-prefix "$DOWNLOAD_URL_PREFIX" \
  --output "$APPCAST_PATH" \
  "$RELEASE_DIR"

echo "Updated: $APPCAST_PATH"
