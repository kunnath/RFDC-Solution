#!/usr/bin/env bash
set -euo pipefail

# Wrapper to run Robot Framework using .venv if available, or system python/robot
# Usage: run_robot.sh [robot args...]

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VENV_PY="$ROOT_DIR/.venv/bin/python"

if [ -x "$VENV_PY" ]; then
  exec "$VENV_PY" -m robot "$@"
fi

if command -v robot >/dev/null 2>&1; then
  exec robot "$@"
fi

if command -v python3 >/dev/null 2>&1; then
  exec python3 -m robot "$@"
fi

if command -v python >/dev/null 2>&1; then
  exec python -m robot "$@"
fi

echo "robot CLI not found" >&2
exit 127
