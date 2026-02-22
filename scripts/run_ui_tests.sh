#!/usr/bin/env bash
set -euo pipefail

# Runner for UI Robot tests. Uses run_robot.sh wrapper and points at
# tests/ui_test.robot. Additional arguments may be passed on the command
# line and are forwarded to Robot Framework.

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEST_FILE="$ROOT_DIR/tests/ui_test.robot"

if [ ! -f "$TEST_FILE" ]; then
  echo "Test file not found: $TEST_FILE" >&2
  exit 2
fi

exec "$ROOT_DIR/scripts/run_robot.sh" "$@" "$TEST_FILE"
