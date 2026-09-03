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

### Monitoring

- **Logs**: Monitor `.copilot/orchestrator.log` for orchestration events.
- **Agent Logs**: Individual agent activity is logged in `.copilot/agent-logs/`. These logs explain what is going on in detail.
- **Backlog**: Check `.copilot/agent-backlog.txt` for the current state of tasks and the "Loop status".

## Constraints

- Ensure exactly **one** watcher process is running for this repository.
- Do not stop the watcher while there are `in_progress` tasks unless explicitly requested.
- After starting or recovering, confirm the heartbeat is moving.