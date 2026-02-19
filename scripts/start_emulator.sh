#!/usr/bin/env bash
set -euo pipefail

# Start an Android emulator by AVD name and wait for it to boot.
# Usage: start_emulator.sh <AVD_NAME> [timeout_seconds]

AVD=${1:-}
TIMEOUT=${2:-120}

# If no AVD provided, try to pick the first available AVD from the SDK
if [ -z "$AVD" ]; then
  if command -v emulator >/dev/null 2>&1; then
    LISTED=$(emulator -list-avds 2>/dev/null | head -n 1 || true)
    if [ -n "$LISTED" ]; then
      AVD="$LISTED"
      echo "No AVD specified — using first available AVD: $AVD"
    fi
  fi
fi

if [ -z "$AVD" ]; then
  echo "Usage: $0 <AVD_NAME> [timeout_seconds]" >&2
  exit 2
fi

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# Locate emulator binary
EMULATOR_CMD=$(command -v emulator || true)
if [ -z "$EMULATOR_CMD" ] && [ -n "${ANDROID_SDK_ROOT:-}" ] && [ -x "$ANDROID_SDK_ROOT/emulator/emulator" ]; then
  EMULATOR_CMD="$ANDROID_SDK_ROOT/emulator/emulator"
fi

if [ -z "$EMULATOR_CMD" ]; then
  echo "Android emulator command not found. Attempting to install SDK components (this may take time)..."
  if [ -x "$PROJECT_ROOT/scripts/setup_android_sdk.sh" ]; then
    bash "$PROJECT_ROOT/scripts/setup_android_sdk.sh" || true
    # re-detect
    EMULATOR_CMD=$(command -v emulator || true)
    if [ -z "$EMULATOR_CMD" ] && [ -n "${ANDROID_SDK_ROOT:-}" ] && [ -x "$ANDROID_SDK_ROOT/emulator/emulator" ]; then
      EMULATOR_CMD="$ANDROID_SDK_ROOT/emulator/emulator"
    fi
  fi
fi

if [ -z "$EMULATOR_CMD" ]; then
  echo "Android emulator command still not found. Install Android SDK/emulator and ensure 'emulator' is in PATH or set ANDROID_SDK_ROOT." >&2
  exit 3
fi

echo "Starting emulator $AVD ... (logs -> $PROJECT_ROOT/reports/emulator-${AVD}.log)"
mkdir -p "$PROJECT_ROOT/reports"
"$EMULATOR_CMD" -avd "$AVD" -no-audio -no-window > "$PROJECT_ROOT/reports/emulator-${AVD}.log" 2>&1 &
EMU_PID=$!

# If Appium CLI exists, start Appium server in background for mobile tests
if command -v appium >/dev/null 2>&1; then
  # check whether Appium (or any process) is already listening on default port 4723
  APPIUM_PORT=4723
  PORT_IN_USE=1
  if command -v lsof >/dev/null 2>&1; then
    if lsof -iTCP:${APPIUM_PORT} -sTCP:LISTEN -n -P >/dev/null 2>&1; then
      PORT_IN_USE=0
    fi
  elif command -v nc >/dev/null 2>&1; then
    if nc -z localhost ${APPIUM_PORT} >/dev/null 2>&1; then
      PORT_IN_USE=0
    fi
  fi

    if [ "$PORT_IN_USE" -eq 0 ]; then
    echo "Appium appears to already be running on port ${APPIUM_PORT}; skipping start."
  else
    echo "Appium CLI found — starting Appium server with chromedriver-autodownload (logs -> $PROJECT_ROOT/reports/appium.log)"
    # Use Appium v3+ allow-insecure full feature name format
    appium --allow-insecure='*:chromedriver_autodownload' --log-level error >"$PROJECT_ROOT/reports/appium.log" 2>&1 &
    APPIUM_PID=$!
    trap 'echo "Stopping Appium and emulator..."; kill "$APPIUM_PID" 2>/dev/null || true; kill "$EMU_PID" 2>/dev/null || true' EXIT

    # Wait for Appium to start listening on the default port
    echo "Waiting for Appium to listen on port ${APPIUM_PORT}..."
    APPIUM_WAIT_SECS=30
    APPIUM_STARTED=0
    for i in $(seq 1 $APPIUM_WAIT_SECS); do
      if command -v lsof >/dev/null 2>&1; then
        if lsof -iTCP:${APPIUM_PORT} -sTCP:LISTEN -n -P >/dev/null 2>&1; then
          APPIUM_STARTED=1
          break
        fi
      elif command -v nc >/dev/null 2>&1; then
        if nc -z localhost ${APPIUM_PORT} >/dev/null 2>&1; then
          APPIUM_STARTED=1
          break
        fi
      fi
      sleep 1
    done
    if [ "$APPIUM_STARTED" -eq 1 ]; then
      echo "Appium is listening on ${APPIUM_PORT}."
    else
      echo "Warning: Appium did not start listening on ${APPIUM_PORT} within ${APPIUM_WAIT_SECS}s" >&2
    fi
  fi
else
  echo "Appium CLI not found. To run Appium-based tests start Appium server manually or install via: npm install -g appium" >&2
fi

echo "Waiting for device to appear (timeout ${TIMEOUT}s)..."
SECONDS=0
while [ $SECONDS -lt $TIMEOUT ]; do
  if command -v adb >/dev/null 2>&1; then
    if adb devices | grep -E "^emulator-" >/dev/null 2>&1; then
      # check boot complete
      if adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r' | grep -q '^1$'; then
        echo "Emulator booted." 
        exit 0
      fi
    fi
  fi
  sleep 2
done

echo "Emulator did not boot within ${TIMEOUT}s." >&2
exit 4
