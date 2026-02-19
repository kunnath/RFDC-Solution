#!/usr/bin/env bash
set -euo pipefail

# Run DB Robot tests. Initializes SQLite DB from tests/data/db.sql (if present)
# and then executes the Robot test `tests/db_test.robot` using the project's runner.

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DATA_FILE="$ROOT_DIR/tests/data/db.sql"
TEST_FILE="$ROOT_DIR/tests/db_test.robot"
DB_FILE="$ROOT_DIR/test.db"

if [ ! -f "$TEST_FILE" ]; then
  echo "Test file not found: $TEST_FILE" >&2
  exit 2
fi

if [ -f "$DATA_FILE" ]; then
  echo "Initializing SQLite DB at $DB_FILE using $DATA_FILE"
  python3 - <<PY
import sqlite3
db = '${DB_FILE}'
sqlf = '${DATA_FILE}'
conn = sqlite3.connect(db)
with open(sqlf, 'r') as f:
    conn.executescript(f.read())
conn.close()
print('OK')
PY
else
  echo "Data file not found: $DATA_FILE; running tests without initializing DB"
fi

exec "$ROOT_DIR/scripts/run_robot.sh" "$TEST_FILE"
