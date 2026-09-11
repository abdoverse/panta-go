#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
AWS_PROFILE_NAME="${AWS_PROFILE_NAME:-panta-local-dev}"
FLUTTER_BIN="${FLUTTER_BIN:-$(dirname "$(command -v flutter 2>/dev/null || printf '%s' /usr/bin/flutter)")}"
HOME_BIN="${HOME_BIN:-$HOME/.local/bin}"
UNIT_DIR="$HOME/.config/systemd/user"
UNIT_PATH="$UNIT_DIR/panta-local.service"
TEMPLATE="$PROJECT_ROOT/panta-dev-loop/systemd/panta-local.service.in"

if ! command -v systemctl >/dev/null 2>&1; then
  echo "systemd is required to install the persistent local service." >&2
  exit 1
fi
if ! command -v aws >/dev/null 2>&1; then
  echo "AWS CLI is required for cloud-backed local testing." >&2
  exit 1
fi
if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter is required. Set FLUTTER_BIN=/path/to/flutter/bin and retry." >&2
  exit 1
fi
if ! AWS_PROFILE="$AWS_PROFILE_NAME" aws sts get-caller-identity --region eu-north-1 >/dev/null 2>&1; then
  echo "AWS profile '$AWS_PROFILE_NAME' is unavailable. Configure it before installing." >&2
  exit 1
fi

mkdir -p "$UNIT_DIR"
sed \
  -e "s|__PROJECT_ROOT__|${PROJECT_ROOT//|/\\|}|g" \
  -e "s|__AWS_PROFILE__|${AWS_PROFILE_NAME//|/\\|}|g" \
  -e "s|__FLUTTER_BIN__|${FLUTTER_BIN//|/\\|}|g" \
  -e "s|__HOME_BIN__|${HOME_BIN//|/\\|}|g" \
  "$TEMPLATE" > "$UNIT_PATH"

if command -v loginctl >/dev/null 2>&1 && command -v sudo >/dev/null 2>&1; then
  sudo -n loginctl enable-linger "$USER" 2>/dev/null || true
fi
systemctl --user daemon-reload
systemctl --user enable --now panta-local.service
systemctl --user --no-pager --full status panta-local.service

echo "Panta local service installed using AWS profile '$AWS_PROFILE_NAME'."
echo "LAN URL: http://$(ip route get 1.1.1.1 2>/dev/null | awk '{for (i=1; i<=NF; i++) if ($i == "src") {print $(i+1); exit}}'):3000"
