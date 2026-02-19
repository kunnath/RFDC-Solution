#!/usr/bin/env bash
set -euo pipefail

# Run the REST Robot tests using the project's runner. This script will
# read tests/data/rest.json and pass it as the Robot variable TEST_DATA.

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DATA_FILE="$ROOT_DIR/tests/data/rest.json"
TEST_FILE="$ROOT_DIR/tests/rest_test.robot"

if [ ! -f "$TEST_FILE" ]; then
  echo "Test file not found: $TEST_FILE" >&2
  exit 2
fi

if [ ! -f "$DATA_FILE" ]; then
  echo "Data file not found: $DATA_FILE" >&2
  echo "Running tests without TEST_DATA variable..."
  exec "$ROOT_DIR/scripts/run_robot.sh" "$TEST_FILE"
fi

# Safely produce a single-quoted JSON string for shell-safe passing
TEST_DATA_ESC=$(python3 - <<PY
import json,shlex
data = json.load(open('${DATA_FILE}'))
print(shlex.quote(json.dumps(data)))
PY
)

exec "$ROOT_DIR/scripts/run_robot.sh" --variable "TEST_DATA:${TEST_DATA_ESC}" "$TEST_FILE"
