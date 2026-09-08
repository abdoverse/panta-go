#!/usr/bin/env bash
# run_dev.sh - Starts the ideal local development setup with Hot Reload
# This script sets up the Go backend and Flutter web server for testing on your phone.

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKEND_DIR="$PROJECT_ROOT/backend"
FRONTEND_DIR="$PROJECT_ROOT/mobile"

# Dynamically get the local Wi-Fi IP address so the phone can connect
LOCAL_IP=$(ip route get 1.1.1.1 | awk '{print $7}')
if [ -z "$LOCAL_IP" ]; then
    LOCAL_IP="127.0.0.1"
fi

echo "============================================================"
echo "🚀 STARTING IDEAL LOCAL DEV ENVIRONMENT"
echo "============================================================"
echo "Local IP detected: $LOCAL_IP"
echo "Phone Test URL: http://$LOCAL_IP:3000"
echo "============================================================"

# Stop existing processes on these ports if they exist
fuser -k 8080/tcp 2>/dev/null || true
fuser -k 3000/tcp 2>/dev/null || true

echo "Starting Go Backend on port 8080..."
cd "$BACKEND_DIR"
TABLE_NAME=panta-go-requests \
IMAGE_BUCKET_NAME=panta-go-request-images \
AWS_REGION=eu-north-1 \
COGNITO_USER_POOL_ID=eu-north-1_Rg7i36e8Q \
PORT=8080 \
go run ./cmd/api &
BACKEND_PID=$!

echo "Starting Flutter Hot-Reload Server on port 3000..."
cd "$FRONTEND_DIR"
# The --dart-define forces the phone to send API requests to the Go backend's local IP
flutter run -d web-server \
    --web-hostname 0.0.0.0 \
    --web-port 3000 \
    --dart-define=API_BASE_URL="http://$LOCAL_IP:8080" &
FLUTTER_PID=$!

# Trap Ctrl+C to kill both servers cleanly
trap "echo '🛑 Stopping servers...'; kill $BACKEND_PID $FLUTTER_PID; exit" INT TERM

wait $BACKEND_PID $FLUTTER_PID
