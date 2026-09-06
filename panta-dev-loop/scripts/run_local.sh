#!/usr/bin/env bash
# run_local.sh - Orchestrate the full Panta local application stack (Backend + Frontend + Demo Seed)

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BACKEND_DIR="$PROJECT_ROOT/my-app/backend/cmd/api"
FRONTEND_DIR="$PROJECT_ROOT/my-app/mobile"
LOG_DIR="$PROJECT_ROOT/.agents/logs/local-run"

BACKEND_PID_FILE="$LOG_DIR/backend.pid"
FRONTEND_PID_FILE="$LOG_DIR/frontend.pid"
BACKEND_LOG="$LOG_DIR/backend.log"
FRONTEND_LOG="$LOG_DIR/frontend.log"

BACKEND_PORT=8080
FRONTEND_PORT=3000

mkdir -p "$LOG_DIR"

is_backend_running() {
    if [ -f "$BACKEND_PID_FILE" ]; then
        local pid
        pid=$(cat "$BACKEND_PID_FILE")
        if ps -p "$pid" > /dev/null 2>&1; then
            return 0
        fi
    fi
    if lsof -i :"$BACKEND_PORT" -sTCP:LISTEN > /dev/null 2>&1; then
        return 0
    fi
    return 1
}

is_frontend_running() {
    if [ -f "$FRONTEND_PID_FILE" ]; then
        local pid
        pid=$(cat "$FRONTEND_PID_FILE")
        if ps -p "$pid" > /dev/null 2>&1; then
            return 0
        fi
    fi
    if lsof -i :"$FRONTEND_PORT" -sTCP:LISTEN > /dev/null 2>&1; then
        return 0
    fi
    return 1
}

check_backend_health() {
    local attempts=0
    local max_attempts=20
    echo -n "⏳ Waiting for backend to respond on port $BACKEND_PORT..."
    while [ $attempts -lt $max_attempts ]; do
        if curl -s "http://localhost:$BACKEND_PORT/api/v1/requests" > /dev/null 2>&1 || \
           curl -s -X POST "http://localhost:$BACKEND_PORT/api/v1/login" -H "Content-Type: application/json" -d '{"role":"user"}' > /dev/null 2>&1; then
            echo " ✅ Backend is healthy!"
            return 0
        fi
        sleep 1
        attempts=$((attempts + 1))
        echo -n "."
    done
    echo " ❌ Backend health check timed out."
    return 1
}

check_frontend_health() {
    local attempts=0
    local max_attempts=30
    echo -n "⏳ Waiting for Flutter web to respond on port $FRONTEND_PORT..."
    while [ $attempts -lt $max_attempts ]; do
        if curl -s "http://localhost:$FRONTEND_PORT" | grep -q "flutter" 2>/dev/null || \
           curl -s "http://localhost:$FRONTEND_PORT" | grep -q "html" 2>/dev/null; then
            echo " ✅ Flutter web is ready!"
            return 0
        fi
        sleep 2
        attempts=$((attempts + 1))
        echo -n "."
    done
    echo " ❌ Flutter web server check timed out."
    return 1
}

seed_demo_data() {
    echo "🌱 Seeding realistic test requests into local backend..."
    if [ -f "$PROJECT_ROOT/seed.js" ]; then
        API_BASE_URL="http://localhost:$BACKEND_PORT" node "$PROJECT_ROOT/seed.js"
    else
        curl -s -X POST "http://localhost:$BACKEND_PORT/api/v1/demo/seed" > /dev/null 2>&1 || true
        echo "✅ Seed endpoint triggered via curl"
    fi
}

start_backend() {
    if is_backend_running; then
        echo "ℹ️  Backend already running on port $BACKEND_PORT."
        return 0
    fi

    echo "🚀 Starting Go backend on port $BACKEND_PORT..."
    cd "$BACKEND_DIR"
    TABLE_NAME=panta-go-requests \
    IMAGE_BUCKET_NAME=panta-go-request-images \
    AWS_REGION=eu-north-1 \
    COGNITO_USER_POOL_ID=eu-north-1_Rg7i36e8Q \
    PORT="$BACKEND_PORT" \
    nohup go run . > "$BACKEND_LOG" 2>&1 &

    local b_pid=$!
    echo "$b_pid" > "$BACKEND_PID_FILE"
    echo "Backend started with PID $b_pid (logs: $BACKEND_LOG)"
    cd "$PROJECT_ROOT"
}

start_frontend() {
    if is_frontend_running; then
        echo "ℹ️  Flutter web server already running on port $FRONTEND_PORT."
        return 0
    fi

    echo "🚀 Starting Flutter web server on port $FRONTEND_PORT..."
    cd "$FRONTEND_DIR"
    nohup flutter run -d web-server \
        --web-port="$FRONTEND_PORT" \
        --web-hostname=0.0.0.0 \
        --dart-define=API_BASE_URL="http://localhost:$BACKEND_PORT" \
        > "$FRONTEND_LOG" 2>&1 &

    local f_pid=$!
    echo "$f_pid" > "$FRONTEND_PID_FILE"
    echo "Flutter web started with PID $f_pid (logs: $FRONTEND_LOG)"
    cd "$PROJECT_ROOT"
}

stop_all() {
    echo "🛑 Stopping Panta local stack..."
    if [ -f "$BACKEND_PID_FILE" ]; then
        local b_pid
        b_pid=$(cat "$BACKEND_PID_FILE")
        echo "Killing backend PID $b_pid..."
        kill "$b_pid" 2>/dev/null || true
        rm -f "$BACKEND_PID_FILE"
    fi
    # Also free port if still held
    fuser -k "${BACKEND_PORT}/tcp" 2>/dev/null || true

    if [ -f "$FRONTEND_PID_FILE" ]; then
        local f_pid
        f_pid=$(cat "$FRONTEND_PID_FILE")
        echo "Killing frontend PID $f_pid..."
        kill "$f_pid" 2>/dev/null || true
        rm -f "$FRONTEND_PID_FILE"
    fi
    fuser -k "${FRONTEND_PORT}/tcp" 2>/dev/null || true

    echo "✅ All local services stopped."
}

show_status() {
    echo "=== Panta Local Stack Status ==="
    if is_backend_running; then
        echo "  Backend (Go):     RUNNING on http://localhost:$BACKEND_PORT"
    else
        echo "  Backend (Go):     STOPPED"
    fi

    if is_frontend_running; then
        echo "  Frontend (Web):   RUNNING on http://localhost:$FRONTEND_PORT"
    else
        echo "  Frontend (Web):   STOPPED"
    fi
}

show_instructions() {
    echo ""
    echo "=================================================================="
    echo "  🎉 PANTA APPLICATION IS LIVE LOCALLY!"
    echo "=================================================================="
    echo "  Browser Test URL:  http://localhost:3000"
    echo "  Backend API:       http://localhost:8080"
    echo "------------------------------------------------------------------"
    echo "  HOW TO TEST THE FULL APPLICATION (NO CREDENTIALS NEEDED):"
    echo "  1. Open http://localhost:3000 in your browser."
    echo "  2. Look at the green 'Local Testing / 1-Click Demo' box:"
    echo "     - Tap 'Anna (Recycler)' to test Recycler Dashboard:"
    echo "       • View active pickups with live ETA and distance"
    echo "       • In-app chat with helper Erik"
    echo "       • BankID Verified badge & Profile modal"
    echo "       • Sustainability Impact Dashboard (CO2, streaks, badges)"
    echo "       • Create new pickup requests"
    echo "     - Tap 'Erik (Helper)' to test Helper Dashboard:"
    echo "       • Browse available jobs sorted by proximity"
    echo "       • Tap 'Accept Pickup'"
    echo "       • Tap 'I am at the door' arrival alert"
    echo "       • Scan receipt & split pant payout (70/30)"
    echo "       • Confirm contactless dropoff with photo proof"
    echo "  3. Need to switch roles while testing? Go to Profile and tap"
    echo "     'Switch to Helper' or 'Switch to Recycler' instantly!"
    echo "=================================================================="
}

case "$1" in
    start)
        start_backend
        check_backend_health
        seed_demo_data
        start_frontend
        check_frontend_health
        show_instructions
        ;;
    stop)
        stop_all
        ;;
    restart)
        stop_all
        sleep 2
        "$0" start
        ;;
    status)
        show_status
        ;;
    seed)
        seed_demo_data
        ;;
    browse)
        show_instructions
        ;;
    logs)
        tail -f "$BACKEND_LOG" "$FRONTEND_LOG"
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|seed|browse|logs}"
        exit 1
        ;;
esac
