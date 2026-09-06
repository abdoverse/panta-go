# Gemini / Antigravity Project Configuration for Panta

## Project Overview
Panta is a high-grade recycling platform connecting household recyclers with verified local helpers (pantare) in Sweden.
- **Backend**: Go REST API (`my-app/backend/cmd/api`) running on port 8080.
- **Frontend**: Flutter Web & Mobile (`my-app/mobile`) running on port 3000.
- **Cloud Infrastructure**: AWS DynamoDB (`panta-go-requests`), S3 (`panta-go-request-images`), Cognito in region `eu-north-1`.
- **Changelog**: Maintained at [`CHANGELOG.md`](file:///home/abdo/Desktop/abdoverse/panta-go/CHANGELOG.md).

---

## High-Autonomy Development Mode (plan-77)
This workspace operates with **non-critical action auto-approval**:
- Auto-approve: Code edits, file creation, unit/widget test execution, formatting (`gofmt`, `dart format`), local builds, and local service lifecycle.
- Reserve explicit user approval strictly for: destructive git operations (`reset --hard`, force push), cloud infrastructure destruction (`cdk destroy`), or deleting persistent production data.
- See detailed policy in [`.agents/rules/autonomy.md`](file:///home/abdo/Desktop/abdoverse/panta-go/.agents/rules/autonomy.md).

---

## Local Development Workflow
Run the full local stack in the browser for manual or automated verification:

```bash
# Start backend (8080) and Flutter web (3000)
./panta-dev-loop/scripts/run_local.sh start

# Check status of local services
./panta-dev-loop/scripts/run_local.sh status

# Seed or reset demo requests (Stockholm personas)
./panta-dev-loop/scripts/run_local.sh seed

# View real-time service logs
./panta-dev-loop/scripts/run_local.sh logs

# Stop local stack
./panta-dev-loop/scripts/run_local.sh stop
```

Access points:
- **Web App**: `http://localhost:3000` (Use 1-click test personas: Anna Recycler or Erik Helper)
- **API Server**: `http://localhost:8080`
- **WebSocket Gateway**: `ws://localhost:8080/api/v1/ws`

---

## Testing & Verification
Before delivering changes, ensure all automated verification checks pass:
- **Backend Tests**: `cd my-app/backend && go test ./...`
- **Mobile / Web Tests**: `cd my-app/mobile && flutter test`

---

## Agent Workspace & Backlog Structure (plan-75)
Tasks, plans, and orchestrations are natively managed under [`.agents/`](file:///home/abdo/Desktop/abdoverse/panta-go/.agents/):
- **Backlog**: [`.agents/agent-backlog.txt`](file:///home/abdo/Desktop/abdoverse/panta-go/.agents/agent-backlog.txt)
- **Completed Archive**: [`.agents/agent-done.txt`](file:///home/abdo/Desktop/abdoverse/panta-go/.agents/agent-done.txt)
- **Roadmap / Plan**: [`.agents/agent-plan.md`](file:///home/abdo/Desktop/abdoverse/panta-go/.agents/agent-plan.md)
- **Rules & Standards**: [`.agents/rules/`](file:///home/abdo/Desktop/abdoverse/panta-go/.agents/rules/)
- **Orchestrator Logs**: [`.agents/logs/`](file:///home/abdo/Desktop/abdoverse/panta-go/.agents/logs/)
