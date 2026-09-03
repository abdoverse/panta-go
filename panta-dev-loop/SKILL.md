---
name: panta-dev-loop
description: Orchestrates the multi-agent development loop for the Panta project. Use when the user says "start the development loop" or needs to manage the background agent orchestrator.
---

# Panta Development Loop

This skill manages the `langgraph_multi_agent.py` orchestrator which coordinates backend, frontend, and tester agents.

## Workflows

### Starting the Loop

When the user requests to "start the development loop":
1. Check if the orchestrator is already running using `scripts/manage_loop.sh status`.
2. If not running, start it using `scripts/manage_loop.sh start`.
3. Verify liveness by checking the heartbeat in `.copilot/agent-backlog.txt`.

### Recovery

If the loop seems stuck or backlog items are stalled:
1. Run `scripts/manage_loop.sh recover`.
2. This moves stale claimed work back to an actionable approval state.

### Configuration

Configure the active model provider in `.env` (copy from `.env.example`):
- `AI_PROVIDER=ollama` (default, free local models like `qwen2.5-coder:7b`)
- `AI_PROVIDER=openrouter` (free cloud models: `qwen/qwen-2.5-coder-32b-instruct:free`, `llama-3.3-70b:free`)
- `AI_PROVIDER=gemini` (Gemini API via Google AI Studio free tier: `gemini-2.5-flash`)

### Diagnostics

Before starting the loop, test provider connectivity and toolchains:
```bash
scripts/manage_loop.sh diagnose
```

### Monitoring

- **Live Logs**: `scripts/manage_loop.sh logs` or tail `.copilot/orchestrator.log`.
- **Agent Logs**: Individual agent activity is logged in `.copilot/agent-logs/`.
- **Backlog**: Check `.copilot/agent-backlog.txt` for task states and heartbeat.

## Constraints

- Ensure exactly **one** watcher process is running for this repository.
- Do not stop the watcher while there are `in_progress` tasks unless explicitly requested.
- After starting or recovering, confirm the heartbeat is moving.