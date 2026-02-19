#!/usr/bin/env bash
set -euo pipefail

# Creates a Python venv in .venv, installs requirements and Playwright browsers.
PYTHON=${PYTHON:-python3}
VENV_DIR=.venv

echo "Creating venv in ${VENV_DIR} using ${PYTHON}..."
$PYTHON -m venv ${VENV_DIR}
source ${VENV_DIR}/bin/activate
pip install --upgrade pip
pip install -r requirements.txt

echo "Installing Playwright browsers (this may take a while)..."
python -m playwright install

echo "Setup complete. Activate with: source ${VENV_DIR}/bin/activate"
