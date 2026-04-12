# Copilot instructions for Panta

## Local app runs

- When asked to run the app locally, prefer the Flutter app in `my-app/mobile`.
- Default to the web workflow instead of Android emulators or Linux desktop unless the user explicitly asks for a different target.
- Start the app with:

  ```bash
  cd /home/abdo/Desktop/abdoverse/panta-go/my-app/mobile
  flutter run -d web-server --web-hostname 127.0.0.1 --web-port 3000
  ```

- If the client supports a built-in or embedded browser, open `http://127.0.0.1:3000` there after the server starts.
- If a built-in browser is not available, give the user the local URL directly.

## Target selection notes

- Avoid Android emulators by default on this project because they are heavy on this machine.
- Avoid the Linux desktop target unless the local linker/toolchain issue has been resolved.

## Agent backlog workflow

- The project backlog lives in `.copilot/agent-backlog.txt`.
- Completed work moves to `.copilot/agent-done.txt`.
- The current roadmap/plan lives in `.copilot/agent-plan.md`.
- The plan is the **first gate**. Users approve an item for backlog intake by marking that plan item `approved`.
- Every plan item must declare **priority**, **complexity** (`small`, `medium`, `large`), and **dependencies** before it is approved into backlog.
- When a plan item is marked `approved`, the agent must move it into `.copilot/agent-backlog.txt` as `pending` and remove it from `.copilot/agent-plan.md`.
- The backlog is the **second gate**. Users approve actual execution by marking a backlog item `approved`.
- For automatic pickup, run `python langgraph_multi_agent.py --project-path . --watch --poll-interval 10` from the repo root.
- In watch mode, approved plan items are moved to backlog automatically, and approved backlog items are claimed automatically by switching them to `in_progress`.
- The loop may work on up to **3 non-colliding in-progress items at a time**.
- Use declared dependencies to prevent conflicting work, and mention relevant dependencies explicitly in the task instruction when they matter.
- When one in-progress item finishes, the loop should pick the next ready **highest-priority** approved item whose dependencies are already satisfied.
- Every `in_progress` item must record the **owner agent**, **started-at time**, **last progress time**, and a short **progress note**.
- Every `in_progress` item must also record a **last heartbeat time** plus explicit **agent activity** entries so the backlog shows what each agent is doing right now.
- Working agents must refresh their progress note whenever they complete a meaningful step and whenever they become blocked.
- Heartbeats and progress are different: heartbeat proves the watcher and agent loop are alive, while progress only moves when the active step meaningfully changes.
- Agent activity entries should say the current phase and the next command or action, for example analysis, editing, validating, deploying, or blocked.
- If an item is blocked, record the blocker explicitly so the watcher can surface it instead of looking passively healthy.
- The live status snapshot must classify each active item as `claimed_no_checkpoint`, `progressing`, `blocked`, or `stale`.
- The live status snapshot must show stale tasks when the watcher heartbeat is current but task progress has not moved for too long.
- If a task stays `claimed_no_checkpoint` beyond the claim timeout, it should be considered recoverable rather than trusted as active execution.
- Recovery path: run `python langgraph_multi_agent.py --project-path . --recover-stalled --output /tmp/panta-agent-loop-state.json` to move stale claimed work back to an actionable approval state.
- Recovered work that remains `approved` should be auto-claimed like any other approved backlog item.
- Never clear, demote, or remove an `in_progress` task from the backlog just because the workflow instructions changed.
- Never kill or restart active agent/watch processes while they still own `in_progress` work. Wait for the ongoing task set to finish first, then apply workflow/WoW changes.
- The agent must read `.copilot/agent-plan.md` before continuing work and keep it updated as work progresses.
- When approved work is completed, remove it from `.copilot/agent-backlog.txt`, append it to `.copilot/agent-done.txt`, and remove or mark it complete in `.copilot/agent-plan.md`.

## Agent delivery workflow

- After an approved feature is implemented and validated, the agent must create a git commit and push it to the remote `main` branch.
