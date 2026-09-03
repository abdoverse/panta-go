#!/bin/bash

# manage_loop.sh - Manage the Panta development loop orchestrator

PROJECT_ROOT=$(pwd)
ORCHESTRATOR_SCRIPT="$PROJECT_ROOT/langgraph_multi_agent.py"
LOG_FILE="$PROJECT_ROOT/.copilot/orchestrator.log"
PID_FILE="$PROJECT_ROOT/.copilot/orchestrator.pid"

check_status() {
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        if ps -p $PID > /dev/null; then
            echo "Orchestrator is running (PID: $PID)"
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
        echo "Orchestrator is running (PID: $PID)"
        echo "$PID" > "$PID_FILE"
        return 0
    fi
    
    echo "Orchestrator is not running."
    return 1
}

start_loop() {
    if check_status > /dev/null; then
        echo "Orchestrator is already running."
        return 0
    fi
    
    echo "Starting orchestrator..."
    mkdir -p "$(dirname "$LOG_FILE")"
    
    # Run in background
    "$PROJECT_ROOT/.venv/bin/python" "$ORCHESTRATOR_SCRIPT" --project-path "$PROJECT_ROOT" --watch --poll-interval 10 --run-tests > "$LOG_FILE" 2>&1 &
    
    NEW_PID=$!
    echo "$NEW_PID" > "$PID_FILE"
    echo "Orchestrator started with PID $NEW_PID. Logging to $LOG_FILE"
}

stop_loop() {
    if check_status > /dev/null; then
        PID=$(cat "$PID_FILE")
        echo "Stopping orchestrator (PID: $PID)..."
        kill $PID
        rm "$PID_FILE"
        echo "Orchestrator stopped."
    else
        echo "Nothing to stop."
    fi
}

recover() {
    echo "Running recovery..."
    "$PROJECT_ROOT/.venv/bin/python" "$ORCHESTRATOR_SCRIPT" --project-path "$PROJECT_ROOT" --recover-stalled --output /tmp/panta-agent-loop-state.json
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
    *)
        echo "Usage: $0 {start|stop|status|recover}"
        exit 1
        ;;
esac
