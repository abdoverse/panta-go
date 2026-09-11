#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RUN_LOCAL="$PROJECT_ROOT/panta-dev-loop/scripts/run_local.sh"
last_commit=""
play_sound() {
  local sound="$1"
  if command -v canberra-gtk-play >/dev/null 2>&1; then
    canberra-gtk-play -i "$sound" >/dev/null 2>&1 || true
  elif command -v paplay >/dev/null 2>&1; then
    paplay "/usr/share/sounds/freedesktop/stereo/${sound}.oga" >/dev/null 2>&1 || true
  elif command -v aplay >/dev/null 2>&1; then
    aplay -q /usr/share/sounds/alsa/Front_Center.wav >/dev/null 2>&1 || true
  fi
}

while true; do
  current_commit="$(git -C "$PROJECT_ROOT" rev-parse HEAD 2>/dev/null || true)"
  if [[ -n "$current_commit" && -n "$last_commit" && "$current_commit" != "$last_commit" ]]; then
    echo "New commit detected ($current_commit); rebuilding local stack."
    play_sound message-new-instant
    if "$RUN_LOCAL" restart; then
      echo "Local stack is running with the latest commit."
      play_sound complete
    else
      echo "Local rebuild failed; will retry on the next commit."
    fi
  fi
  last_commit="$current_commit"
  sleep 5
done
