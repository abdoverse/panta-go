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
- For automatic pickup, run `python langgraph_multi_agent.py --project-path . --watch --poll-interval 10 --run-tests` from the repo root.
- In watch mode, approved plan items are moved to backlog automatically. The orchestrator must also launch real coding workers for ready approved backlog items by invoking the local `copilot` CLI non-interactively.
- Approved backlog items must **not** be switched to `in_progress` unless there is real execution evidence for the item, such as task-relevant repository edits from a launched worker.
- If `ready_approved > 0` and `active_agents = 0`, the loop itself must immediately launch a real coding worker for the highest-priority ready approved item. A ready item must not be left waiting indefinitely.
- Watcher invariant: if the workflow depends on automatic plan/backlog movement, the agent must leave **exactly one** `langgraph_multi_agent.py --watch` process running before it concludes.
- Watcher verification is mandatory after any loop change, recovery action, or process restart: check the live process list, confirm there is one watcher for this repo, and confirm the backlog heartbeat is moving.
- If no watcher is running, the agent must start one immediately. If multiple watchers are running, the agent must stop the extras and leave one current watcher.
- The detached Copilot worker is the source of truth for implementation activity. The orchestrator must not invent backend/frontend "working" activity for backlog display when no real worker for that item is running.
- Worker liveness must be judged from produced worker logs and process state, not minute-based timeout guesses. Backlog progress should mirror the latest meaningful worker log line whenever available.
- Keep one append-only log file per logical agent owner under `.copilot/agent-logs/` instead of per-task worker log files. Combined items may use a combined owner log such as `backend_dev+frontend_dev.log`.
- A newly launched worker must never surface a placeholder like "waiting for first task-relevant repository edits." Show either the latest worker log line or an explicit "worker process is running; awaiting its first per-agent log line" message until real output appears, and include the agent log path in the live backlog note.
- Workers must report back explicitly to the orchestrator through structured log lines. Each worker should emit `ORCH_REPORT|state=...|summary=...|next=...` checkpoints on assignment, meaningful progress changes, blockers, and before exit.
- Workers must also emit literal `ORCH_STEP|action=...|detail=...` lines for exact files, exact commands, exact tests, and exact failure lines. Their first real output after assignment must be an `ORCH_STEP` line, not vague prose.
- Silent waiting is forbidden. If a worker concludes there is no further useful work, no more task-relevant change is needed, or the task is already effectively complete, it must emit a final `ORCH_REPORT` with `state=done` immediately instead of idling or exiting quietly.
- If a worker believes its assigned task is implemented or effectively complete, it must emit a final `ORCH_REPORT` with `state=ready_for_validation` or `state=done` instead of silently exiting.
- Every worker session must end with a final structured report line: `ready_for_validation`, `done`, or `blocked`. Silent exits are always a worker failure.
- The orchestrator must honor those final worker reports: `ready_for_validation` should advance the item to validation, and `done` should close the item when no additional task-relevant changes are pending.
- If a worker exits repeatedly without any structured progress/completion report beyond the initial assignment checkpoint, the orchestrator must stop silent thrashing, record a clear worker-reporting failure, and pause automatic relaunches for that item until the failure is addressed.
- The loop may work on up to **3 non-colliding in-progress items at a time**.
- Use declared dependencies to prevent conflicting work, and mention relevant dependencies explicitly in the task instruction when they matter.
- When one in-progress item finishes, the loop should pick the next ready **highest-priority** approved item whose dependencies are already satisfied.
- Every `in_progress` item must record the **owner agent**, **started-at time**, **last progress time**, and a short **progress note**.
- Every `in_progress` item must also record a **last heartbeat time** plus explicit **agent activity** entries so the backlog shows what each agent is doing right now.
- Working agents must refresh their progress note whenever they complete a meaningful step and whenever they become blocked.
- Heartbeats and progress are different: heartbeat proves the watcher and agent loop are alive, while progress only moves when the active step meaningfully changes.
- Agent activity entries should say the current phase and the next command or action, for example analysis, editing, validating, deploying, or blocked.
- If an item is blocked, record the blocker explicitly so the watcher can surface it instead of looking passively healthy.
- An `in_progress` task with no task-relevant local code changes after a short grace period must be treated as a **synthetic claim**, returned to `approved`, and annotated as waiting for a real worker. The loop must never keep that state as healthy `in_progress`.
- The "waiting for a real worker" note is a short-lived launch state, not an acceptable steady state. The loop must respond by launching a real worker and then either claim the task once edits appear or surface that the worker exited without producing task-relevant changes.
- If a worker is still running but produces no new log activity across repeated watcher polls and no task-relevant edits appear, the loop should treat it as inactive and relaunch automatically.
- Tester work must not start until task-relevant implementation changes exist for the item being validated.
- Heartbeat-only watcher passes must not overwrite a real blocked/progress state with synthetic validation-prep or handoff text.
- Validation failure is a repair handoff, not a terminal excuse: preserve the tester failure summary, return the item to an actionable approval state, and relaunch a real worker automatically with that failure context.
- Approved follow-up work that already has task-relevant local edits is eligible for a repair worker relaunch when the blocker is a failed validation result.
- The live status snapshot must classify each active item as `claimed_no_checkpoint`, `progressing`, `blocked`, or `stale`.
- The live status snapshot must show stale tasks when the watcher heartbeat is current but task progress has not moved for too long.
- If a task stays `claimed_no_checkpoint` beyond the claim timeout, it should be considered recoverable rather than trusted as active execution.
- Recovery path: run `python langgraph_multi_agent.py --project-path . --recover-stalled --output /tmp/panta-agent-loop-state.json` to move stale claimed work back to an actionable approval state.
- Recovered work that remains `approved` should stay approved until real execution evidence exists; recovery must not immediately recreate the same synthetic claim.
- Never clear, demote, or remove an `in_progress` task from the backlog just because the workflow instructions changed.
- Never kill or restart active agent/watch processes while they still own `in_progress` work. Wait for the ongoing task set to finish first, then apply workflow/WoW changes.
- The agent must read `.copilot/agent-plan.md` before continuing work and keep it updated as work progresses.
- When approved work is completed, remove it from `.copilot/agent-backlog.txt`, append it to `.copilot/agent-done.txt`, and remove or mark it complete in `.copilot/agent-plan.md`.

## Agent delivery workflow

- After an approved feature is implemented and validated, the agent must create a git commit and push it to the remote `main` branch.
- When tester validation approves the work, the agent must complete the delivery chain without pausing at a local-only state: commit, push to `main`, and deploy using the existing project deployment path.
- A task is not complete just because it reached `.copilot/agent-done.txt`; the loop must not treat backlog archival as finished delivery unless git commit delivery also succeeded.
