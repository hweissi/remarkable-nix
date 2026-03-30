#!/usr/bin/env bash
set -euo pipefail
# Placeholders for substitution: @notify@

DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
DEFAULT_PREFIX="${DATA_HOME}/remarkable/wine"
export WINEPREFIX="${REMARKABLE_WINEPREFIX:-${WINEPREFIX:-$DEFAULT_PREFIX}}"

if [ ! -d "$WINEPREFIX" ]; then
  export WINEARCH=win64
  mkdir -p "$WINEPREFIX"
fi

APP_DIR="@app@/share/remarkable/app"
APP_EXE_DEFAULT="${APP_DIR}/reMarkable.exe"
APP_EXE="${REMARKABLE_EXE:-$APP_EXE_DEFAULT}"

if [ ! -d "$APP_DIR" ]; then
  echo "App payload missing at: $APP_DIR" >&2
  exit 1
fi

if [ ! -d "$WINEPREFIX/drive_c" ]; then
  echo "Initializing Wine prefix..." >&2
  "@wine@"/bin/wineboot -u
fi

if [ ! -f "$APP_EXE" ]; then
  echo "Expected app not found at: $APP_EXE" >&2
  echo "Set REMARKABLE_EXE to the correct path and re-run." >&2
  exit 1
fi

cd "$APP_DIR"
if [ -x "@notify@/bin/notify-send" ]; then
  "@notify@/bin/notify-send" -a "reMarkable Desktop" "Starting reMarkable..."
fi
exec "@wine@"/bin/wine "$APP_EXE" "$@"
