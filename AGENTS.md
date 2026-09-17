# Gemini / Antigravity Project Configuration for Panta

## Project Overview
Panta is a high-grade recycling platform connecting household recyclers with verified local helpers (pantare) in Sweden.
- **Backend**: Go REST API (`backend/cmd/api`) running on port 8080.
- **Frontend**: Flutter Web & Mobile (`mobile/`) running on port 3000.
- **Infrastructure**: AWS CDK TypeScript stack (`infra/`). DynamoDB (`panta-requests`), S3 (`panta-request-images`), Cognito in region `eu-north-1`.
- **Changelog**: Maintained at [`CHANGELOG.md`](CHANGELOG.md).

---

## YOLO Mode (plan-77)
This workspace operates with **non-critical action auto-approval**:
- Auto-approve: Code edits, file creation, unit/widget test execution, formatting (`gofmt`, `dart format`), local builds, and local service lifecycle.
- Reserve explicit user approval strictly for: destructive git operations (`reset --hard`, force push), cloud infrastructure destruction (`cdk destroy`), or deleting persistent production data.
- See detailed policy in [`.agents/rules/autonomy.md`](.agents/rules/autonomy.md).

---

## Local Development Workflow
Run the full local stack in the browser for manual or automated verification:

```bash
# Start backend (8080) and fast Flutter web (3000) using cached bundle
./panta-dev-loop/scripts/run_local.sh start

# Start interactive local stack with Flutter Hot Reload (no release build)
./panta-dev-loop/scripts/run_local.sh dev

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

## Testing & Fast Feedback Loop
Use the optimized test runner `./scripts/fast_test.sh`:
- **Full Stack Fast Verification (~36s)**: `./scripts/fast_test.sh all`
- **Targeted Mobile Test (~8-12s)**: `./scripts/fast_test.sh mobile <pattern-or-file>` (e.g. `./scripts/fast_test.sh mobile market_notification`)
- **Aggregated Mobile Suite (~35s)**: `./scripts/fast_test.sh mobile`
- **Backend Tests (~1-2s)**: `./scripts/fast_test.sh backend` (or `cd backend && go test ./...`)
- **Cache Retention**: Preserve `build/test_cache` (do not run `flutter clean` routinely) to keep compile times ~4s rather than ~32s. See skill [`.agents/skills/panta-fast-build/SKILL.md`](.agents/skills/panta-fast-build/SKILL.md).

---

## Agent Workspace & Backlog Structure (plan-75)
Tasks, plans, and orchestrations are natively managed under [`.agents/`](.agents/):
- **Backlog**: [`.agents/agent-backlog.txt`](.agents/agent-backlog.txt)
- **Completed Archive**: [`.agents/agent-done.txt`](.agents/agent-done.txt)
- **Roadmap / Plan**: [`.agents/agent-plan.md`](.agents/agent-plan.md)
- **Rules & Standards**: [`.agents/rules/`](.agents/rules/)
- **Orchestrator Logs**: [`.agents/logs/`](.agents/logs/)
