#!/usr/bin/env bash
set -euo pipefail
systemctl --user disable --now panta-local.service 2>/dev/null || true
rm -f "$HOME/.config/systemd/user/panta-local.service"
systemctl --user daemon-reload
systemctl --user reset-failed panta-local.service 2>/dev/null || true
echo "Panta local service removed."
