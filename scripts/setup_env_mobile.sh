#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

exec "$ROOT_DIR/scripts/setup_env.sh" mobile

# After Python deps are ensured, try to ensure Appium server is available
if command -v npm >/dev/null 2>&1; then
  if ! command -v appium >/dev/null 2>&1; then
    echo "Appium not found. Attempting to install globally (may require sudo)..."
    if npm install -g appium; then
      echo "Appium installed successfully."
    else
      echo "Global Appium install failed. Install manually: npm install -g appium" >&2
    fi
  else
    echo "Appium server found." 
  fi
else
  echo "npm not found — install Node.js to run Appium server (https://nodejs.org/)" >&2
fi

if ! command -v adb >/dev/null 2>&1; then
  echo "adb not found. Install Android SDK platform-tools and ensure 'adb' is in PATH." >&2
fi

if ! command -v emulator >/dev/null 2>&1; then
  if [ -n "${ANDROID_SDK_ROOT:-}" ] && [ -x "$ANDROID_SDK_ROOT/emulator/emulator" ]; then
    echo "emulator found under ANDROID_SDK_ROOT." 
  else
    echo "Android emulator command not found. Install Android SDK emulator or use Android Studio AVD Manager." >&2
  fi
fi

echo "Mobile environment setup complete."
