#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RUN_LOCAL="$PROJECT_ROOT/panta-dev-loop/scripts/run_local.sh"
last_commit=""
while true; do
  current_commit="$(git -C "$PROJECT_ROOT" rev-parse HEAD 2>/dev/null || true)"
  if [[ -n "$current_commit" && -n "$last_commit" && "$current_commit" != "$last_commit" ]]; then
    echo "New commit detected ($current_commit); rebuilding local stack."
    "$RUN_LOCAL" restart || echo "Local rebuild failed; will retry on the next commit."
  fi
  last_commit="$current_commit"
  sleep 5
done
