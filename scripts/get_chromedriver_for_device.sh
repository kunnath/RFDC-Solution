#!/usr/bin/env bash
set -euo pipefail

# Usage: get_chromedriver_for_device.sh [DEVICE_ID] [OUT_DIR]
DEVICE=${1:-emulator-5554}
OUT_DIR=${2:-$HOME/.appium/chromedrivers}
mkdir -p "$OUT_DIR"

echo "Detecting Chrome version on device $DEVICE..." >&2
VER=$(adb -s "$DEVICE" shell dumpsys package com.android.chrome 2>/dev/null | grep versionName | head -n1 | sed -E 's/.*versionName=([^ ]+).*/\1/' | tr -d '\r' || true)
if [ -z "$VER" ]; then
  echo "Could not determine Chrome version on device $DEVICE" >&2
  exit 2
fi
echo "Chrome version on device: $VER" >&2

MAJOR=$(echo "$VER" | cut -d. -f1)
if [ -z "$MAJOR" ]; then
  echo "Could not parse major version from $VER" >&2
  exit 3
fi

echo "Looking up chromedriver for major version $MAJOR..." >&2
LATEST=$(curl -fsS "https://chromedriver.storage.googleapis.com/LATEST_RELEASE_${MAJOR}" || true)
if [ -z "$LATEST" ]; then
  echo "No specific chromedriver for major $MAJOR; falling back to latest" >&2
  LATEST=$(curl -fsS "https://chromedriver.storage.googleapis.com/LATEST_RELEASE")
fi

if [ -z "$LATEST" ]; then
  echo "Could not obtain chromedriver version" >&2
  exit 4
fi

echo "Resolved chromedriver version: $LATEST" >&2
ZIP_URL="https://chromedriver.storage.googleapis.com/${LATEST}/chromedriver_mac64.zip"
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

echo "Downloading $ZIP_URL..." >&2
curl -fsSL -o "$TMPDIR/chromedriver.zip" "$ZIP_URL"
unzip -q -o "$TMPDIR/chromedriver.zip" -d "$TMPDIR"

if [ ! -f "$TMPDIR/chromedriver" ]; then
  echo "Downloaded archive did not contain chromedriver" >&2
  exit 5
fi

OUTPATH="$OUT_DIR/chromedriver_${LATEST}"
mv "$TMPDIR/chromedriver" "$OUTPATH"
chmod +x "$OUTPATH"

echo "$OUTPATH"
exit 0
