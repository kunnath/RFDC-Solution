#!/usr/bin/env bash
set -euo pipefail

# Generic environment setup for a test layer.
# Usage: setup_env.sh <layer>

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VENV_DIR="$ROOT_DIR/.venv"
LAYER=${1:-}

if [ -z "$LAYER" ]; then
  echo "Usage: $0 <layer>"
  exit 2
fi

if [ ! -x "$VENV_DIR/bin/python" ]; then
  echo "Virtualenv not found at $VENV_DIR. Run scripts/setup_venv.sh first or it will be created now."
  python3 -m venv "$VENV_DIR"
fi

source "$VENV_DIR/bin/activate"
pip install --upgrade pip

# Install common requirements
if [ -f "$ROOT_DIR/requirements.txt" ]; then
  pip install -r "$ROOT_DIR/requirements.txt"
fi

case "$LAYER" in
  mqtt)
    echo "Installing MQTT packages"
    pip install paho-mqtt
    ;;
  kafka)
    echo "Installing Kafka packages"
    pip install confluent-kafka
    ;;
  rest)
    echo "Installing REST packages"
    pip install requests
    ;;
  db)
    echo "Installing DB packages"
    pip install sqlalchemy psycopg2-binary
    ;;
  ui)
    echo "UI layer (playwright/robot) already covered by requirements.txt"
    ;;
  mobile)
    echo "Installing Mobile (Appium) packages"
    pip install Appium-Python-Client
    ;;
  firmware)
    echo "Installing Firmware (serial) packages"
    pip install pyserial
    ;;
  *)
    echo "Unknown layer: $LAYER"
    exit 3
    ;;
esac

echo "Environment setup for layer '$LAYER' complete. Activate with: source $VENV_DIR/bin/activate"
