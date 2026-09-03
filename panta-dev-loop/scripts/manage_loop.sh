#!/bin/bash

# manage_loop.sh - Manage the Panta development loop orchestrator (PantaSwarm)

PROJECT_ROOT=$(pwd)
ORCHESTRATOR_SCRIPT="$PROJECT_ROOT/langgraph_multi_agent.py"
LOG_FILE="$PROJECT_ROOT/.copilot/orchestrator.log"
PID_FILE="$PROJECT_ROOT/.copilot/orchestrator.pid"

# Select Python binary (prefer repo venv)
if [ -x "$PROJECT_ROOT/.venv/bin/python3" ]; then
    PYTHON_BIN="$PROJECT_ROOT/.venv/bin/python3"
else
    PYTHON_BIN="python3"
fi

# Load .env if present
if [ -f "$PROJECT_ROOT/.env" ]; then
    export $(grep -v '^#' "$PROJECT_ROOT/.env" | xargs -d '\n')
fi

check_status() {
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        if ps -p $PID > /dev/null 2>&1; then
            echo "PantaSwarm orchestrator is running (PID: $PID)"
            return 0
        else
            echo "Orchestrator PID file exists but process is not running."
            rm "$PID_FILE"
            return 1
        fi
    fi
    
    # Fallback to ps check
    PID=$(ps aux | grep langgraph_multi_agent.py | grep -v grep | awk '{print $2}')
    if [ -n "$PID" ]; then
        echo "PantaSwarm orchestrator is running (PID: $PID)"
        echo "$PID" > "$PID_FILE"
        return 0
    fi
    
    echo "PantaSwarm orchestrator is NOT running."
    return 1
}

start_loop() {
    if check_status > /dev/null 2>&1; then
        echo "Orchestrator is already running."
        return 0
    fi
    
    echo "Starting PantaSwarm orchestrator..."
    mkdir -p "$(dirname "$LOG_FILE")"
    
    # Run in background
    nohup "$PYTHON_BIN" "$ORCHESTRATOR_SCRIPT" --project-path "$PROJECT_ROOT" --watch --poll-interval 10 --run-tests > "$LOG_FILE" 2>&1 &
    
    NEW_PID=$!
    echo "$NEW_PID" > "$PID_FILE"
    echo "PantaSwarm orchestrator started with PID $NEW_PID. Logging to $LOG_FILE"
}

stop_loop() {
    if check_status > /dev/null 2>&1; then
        PID=$(cat "$PID_FILE")
        echo "Stopping orchestrator (PID: $PID)..."
        kill $PID
        rm -f "$PID_FILE"
        echo "Orchestrator stopped."
    else
        echo "Nothing to stop."
    fi
}

recover() {
    echo "Running recovery..."
    "$PYTHON_BIN" "$ORCHESTRATOR_SCRIPT" --project-path "$PROJECT_ROOT" --recover-stalled --output /tmp/panta-agent-loop-state.json
}

diagnose() {
    echo "Running diagnostics..."
    "$PYTHON_BIN" "$ORCHESTRATOR_SCRIPT" --project-path "$PROJECT_ROOT" --diagnose
}

show_logs() {
    if [ -f "$LOG_FILE" ]; then
        tail -n 50 -f "$LOG_FILE"
    else
        echo "No log file found at $LOG_FILE"
    fi
}

case "$1" in
    start)
        start_loop
        ;;
    stop)
        stop_loop
        ;;
    status)
        check_status
        ;;
    recover)
        recover
        ;;
    diagnose)
        diagnose
        ;;
    logs)
        show_logs
        ;;
    *)
        echo "Usage: $0 {start|stop|status|recover|diagnose|logs}"
        exit 1
        ;;
esac
