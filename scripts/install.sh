#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
INSTALL_DIR="$HOME/Applications"
APP_NAME="Headroom.app"

"$ROOT_DIR/scripts/build-app.sh" >/dev/null

mkdir -p "$INSTALL_DIR"
pkill -f '/Headroom.app/Contents/MacOS/Headroom' 2>/dev/null || true
rm -rf "$INSTALL_DIR/$APP_NAME"
cp -R "$ROOT_DIR/dist/$APP_NAME" "$INSTALL_DIR/$APP_NAME"
open "$INSTALL_DIR/$APP_NAME"

echo "Installed and launched: $INSTALL_DIR/$APP_NAME"
