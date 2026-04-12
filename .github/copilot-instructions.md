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
- When a plan item is marked `approved`, the agent must move it into `.copilot/agent-backlog.txt` as `pending` and remove it from `.copilot/agent-plan.md`.
- The backlog is the **second gate**. Users approve actual execution by marking a backlog item `approved`.
- For automatic pickup, run `python langgraph_multi_agent.py --project-path . --watch --poll-interval 10` from the repo root.
- In watch mode, approved plan items are moved to backlog automatically, and approved backlog items are claimed automatically by switching them to `in_progress`.
- The agent must read `.copilot/agent-plan.md` before continuing work and keep it updated as work progresses.
- When approved work is completed, remove it from `.copilot/agent-backlog.txt`, append it to `.copilot/agent-done.txt`, and remove or mark it complete in `.copilot/agent-plan.md`.

## Agent delivery workflow

- After an approved feature is implemented and validated, the agent must create a git commit and push it to the remote `master` branch.
