#!/usr/bin/env bash
set -euo pipefail

# Runner for mobile Robot tests. Starts Appium server if available and
# runs tests/mobile_test.robot, passing tests/data/mobile.json as TEST_DATA.

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DATA_FILE="$ROOT_DIR/tests/data/mobile.json"
TEST_FILE="$ROOT_DIR/tests/mobile_test.robot"
DEVICE=${1:-${DEVICE:-}}

if [ ! -f "$TEST_FILE" ]; then
  echo "Test file not found: $TEST_FILE" >&2
  exit 2
fi

# Prepare TEST_DATA variable
TEST_DATA_ARG=""
if [ -f "$DATA_FILE" ]; then
  TEST_DATA_ESC=$(python3 - <<PY
import json,shlex
data = json.load(open('${DATA_FILE}'))
print(shlex.quote(json.dumps(data)))
PY
)
  TEST_DATA_ARG=(--variable "TEST_DATA:${TEST_DATA_ESC}")
fi

# If Appium available, start it in background and ensure it's cleaned up
APPIUM_PID=""
if command -v appium >/dev/null 2>&1; then
  echo "Starting Appium server (logs -> $ROOT_DIR/reports/appium.log)"
  mkdir -p "$ROOT_DIR/reports"
  appium --log-level error >"$ROOT_DIR/reports/appium.log" 2>&1 &
  APPIUM_PID=$!
  trap 'echo "Stopping Appium..."; kill "$APPIUM_PID" 2>/dev/null || true' EXIT
  sleep 2
else
  echo "Appium CLI not found; ensure Appium server is running for real device/emulator tests." >&2
fi

# Build robot args
ROBOT_ARGS=()
if [ -n "${TEST_DATA_ARG:-}" ]; then
  ROBOT_ARGS+=("${TEST_DATA_ARG[@]}")
fi
if [ -n "$DEVICE" ]; then
  ROBOT_ARGS+=(--variable "DEVICE:${DEVICE}")
fi

exec "$ROOT_DIR/scripts/run_robot.sh" "${ROBOT_ARGS[@]}" "$TEST_FILE"
