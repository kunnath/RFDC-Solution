#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 [--persistent TUNNEL_NAME [CONFIG_PATH]]"
  echo
  echo "Ephemeral mode (default): exposes frontend and backend as separate public URLs"
  echo "  $0"
  echo
  echo "Persistent mode: run a named tunnel using a config file"
  echo "  $0 --persistent my-tunnel .cloudflared/config.yml"
  exit 1
}

if ! command -v cloudflared >/dev/null 2>&1; then
  echo "cloudflared not found. Install with: brew install cloudflared"
  exit 1
fi

# parse optional --start-frontend flag
START_FRONTEND=0
for a in "$@"; do
  if [[ "$a" == "--start-frontend" ]]; then
    START_FRONTEND=1
    # remove this arg from the list by shifting later
  fi
done

# wait_for_port is used when starting the frontend; define it before use
wait_for_port() {
  local port=$1; local timeout=${2:-15}; local i=0
  while [[ $i -lt $timeout ]]; do
    if nc -z 127.0.0.1 $port >/dev/null 2>&1; then
      return 0
    fi
    sleep 1; i=$((i+1))
  done
  return 1
}

if [[ "${1:-}" == "--persistent" ]]; then
  if [[ -z "${2:-}" ]]; then
    usage
  fi
  TUNNEL_NAME="$2"
  CONFIG_PATH="${3:-.cloudflared/config.yml}"
  echo "Running persistent tunnel '$TUNNEL_NAME' using config '$CONFIG_PATH'..."
  cloudflared tunnel run "$TUNNEL_NAME" --config "$CONFIG_PATH"
else
  echo "Starting ephemeral tunnels for frontend (3000) and backend (5000)..."
  echo
  echo "This will start two quick tunnels and print their public URLs. Use --persistent for a named tunnel."

  tmpdir=$(mktemp -d)
  frontend_log="$tmpdir/frontend.log"
  backend_log="$tmpdir/backend.log"

  # if requested, start the frontend dev server (CRA)
  if [[ "$START_FRONTEND" == "1" ]]; then
    echo "Starting frontend dev server (start:public) ..."
    # prefer using the explicit npm script start:public which sets HOST and disables host check
    (cd frontend && npm --silent --prefix . run start:public) >"$tmpdir/frontend_node.log" 2>&1 &
    echo $! >"$tmpdir/frontend_node.pid"
    # wait a bit for CRA to boot
    sleep 2
    if ! wait_for_port 3000 20; then
      echo "Error: frontend did not start on 127.0.0.1:3000 within timeout. Check $tmpdir/frontend_node.log"
    else
      echo "Frontend started and listening on 127.0.0.1:3000"
    fi
  fi

  wait_for_port() {
    local port=$1; local timeout=${2:-15}; local i=0
    while [[ $i -lt $timeout ]]; do
      if nc -z 127.0.0.1 $port >/dev/null 2>&1; then
        return 0
      fi
      sleep 1; i=$((i+1))
    done
    return 1
  }

  start_quick() {
    local url="$1"; local out="$2"
    # run cloudflared in background, log to file
    cloudflared tunnel --url "$url" >"$out" 2>&1 &
    echo $! >"$out.pid"
  }

  extract_url() {
    local file="$1"; local timeout=${2:-20}; local i=0; local url=''
    while [[ $i -lt $timeout ]]; do
      if grep -Eo "https?://[a-z0-9.-]+trycloudflare.com" "$file" -m1 >/dev/null 2>&1; then
        url=$(grep -Eo "https?://[a-z0-9.-]+trycloudflare.com" "$file" -m1)
        echo "$url"
        return 0
      fi
      sleep 1; i=$((i+1))
    done
    return 1
  }

  # Ensure frontend/backend are listening locally before starting tunnels
  if ! wait_for_port 3000 12; then
    echo "Warning: nothing is listening on 127.0.0.1:3000 — start your frontend first."
  fi
  if ! wait_for_port 5000 8; then
    echo "Warning: nothing is listening on 127.0.0.1:5000 — start your backend first."
  fi

  start_quick http://127.0.0.1:3000 "$frontend_log"
  start_quick http://127.0.0.1:5000 "$backend_log"

  echo "Waiting for tunnels to become available (logs in $tmpdir) ..."
  FURL=''; BURL=''
  FURL=$(extract_url "$frontend_log" 30) || true
  BURL=$(extract_url "$backend_log" 30) || true

  echo
  if [[ -n "$FURL" ]]; then
    echo "Frontend URL: $FURL"
  else
    echo "Frontend URL: (not available yet) — see $frontend_log"
  fi
  if [[ -n "$BURL" ]]; then
    echo "Backend  URL: $BURL"
  else
    echo "Backend  URL: (not available yet) — see $backend_log"
  fi

  echo
  echo "Logs: $tmpdir"
  echo "To stop the tunnels, kill the PIDs in $tmpdir/*.pid or remove the temp dir."

  # Tail both logs so script stays in foreground and shows live output
  trap 'pkill -P $$ || true; exit 0' INT TERM
  tail -n +1 -f "$frontend_log" "$backend_log"
fi
