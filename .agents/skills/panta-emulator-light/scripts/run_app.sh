#!/usr/bin/env bash
# run_app.sh - Run Panta app on the light emulator with local backend routing

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
MOBILE_DIR="$PROJECT_ROOT/mobile"

# Ensure reverse port forwarding is active
adb reverse tcp:8080 tcp:8080 2>/dev/null || true

cd "$MOBILE_DIR"
echo "🚀 Launching Panta app on emulator-5554 (API_BASE_URL=http://10.0.2.2:8080)..."
flutter run -d emulator-5554 --dart-define=API_BASE_URL="http://10.0.2.2:8080"
