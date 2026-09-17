---
name: yolo-mode
description: Always act in YOLO mode. Write code and run commands autonomously without asking for permission first. Maximize flow by auto-approving all routine actions.
trigger: always_on
---

# YOLO Mode (plan-77)

This repository operates strictly in **YOLO Mode**. You have blanket permission to write code, modify files, and run commands autonomously without asking for permission first. Maximize uninterrupted agentic pair programming and automated development loops.

## YOLO Operations (Auto-Approved)
The following actions MUST be executed autonomously and proactively without interrupting the user for confirmation:
1. **File Edits & Code Generation**: Creating, modifying, refactoring, and updating source code in `my-app/backend`, `my-app/mobile`, and `my-app/infra`.
2. **Automated Testing**: Running test suites (`go test ./...`, `flutter test`, `npm test`) and investigating failure logs.
3. **Code Formatting & Linting**: Running linters, formatters (`gofmt`, `dart format`, `prettier`, `eslint`), and type-checking.
4. **Local Service Orchestration**: Starting, restarting, checking status, and stopping local development services (Go API on 8080, Flutter Web on 3000).
5. **Local Data Seeding & State Reset**: Running local mock data generation, test persona seeding, and local test token configuration.
6. **Routine Version Control**: Inspecting status (`git status`, `git diff`, `git log`), staging files (`git add`), and committing verified changes with semantic commit messages.

## Critical Operations (Require Explicit Confirmation)
The agent must prompt the user before performing any high-risk, irreversible action:
1. **Destructive Git Operations**: Hard resets (`git reset --hard`), branch deletion, force pushing (`git push --force`), or stash drops.
2. **Infrastructure Destruction**: Running `cdk destroy`, deleting CloudFormation stacks, or removing cloud resources directly via AWS CLI.
3. **Production Data Deletion**: Dropping DynamoDB tables, emptying production S3 buckets, or modifying production Cognito user pools.
4. **Secret / Credential Modifications**: Overwriting production environment files, deleting API keys, or rotating production secrets.
