# Changelog

All notable changes to the Panta Go project are documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.3.0] - 2026-09-06

### Added
- **Dynamic Per-Market Request Quota (`plan-74`)**:
  - Implemented backend market configuration engine in `backend/cmd/api/market_config.go` with `GET /api/v1/market/config`.
  - Configurable market profile defaults (e.g. `market_se_stockholm` with max 5 active requests per recycler) and environment variable overrides (`PANTA_MARKET_ID`, `PANTA_MAX_ACTIVE_REQUESTS`).
  - Enforced active request quota verification on request creation (`POST /api/v1/requests`) in `backend/cmd/api/requests.go`.
  - Added mobile UI quota banner and submit button locking in `CreateRequestPage` and `PantaProvider` with unit and widget test coverage (`market_quota_test.dart`).
- **GDPR-Compliant Chat Storage & AES-256-GCM Encryption at Rest (`plan-73`)**:
  - Implemented authenticated encryption at rest in `backend/cmd/api/chat_security.go` using AES-256-GCM with 12-byte random nonces and request-scoped AAD binding.
  - Added GDPR Article 17 Right to Erasure endpoint (`DELETE /api/v1/chat?requestId=...`) and realtime `chat-erased` WebSocket notification.
  - Added 30-day automatic retention policy filter with full preservation of UTF-8 multi-language text (Swedish `å`, `ä`, `ö`) and emojis.
- **BankID Personal Number Privacy (`plan-72`)**:
  - Masked and removed national identity personal number display from BankID verification badge on the user profile screen.
  - Added widget verification test in `bankid_test.dart`.
- **Systematic Repository Changelog (`plan-76`)**:
  - Authored repo-level `CHANGELOG.md` adhering to Keep a Changelog standard and SemVer, documenting releases 1.0.0 through 1.3.0 with dates and task IDs.
- **Gemini / Antigravity Native Workspace Migration (`plan-75`)**:
  - Migrated legacy `.copilot` directory structure to native `.agents/` layout (`.agents/agent-backlog.txt`, `.agents/agent-done.txt`, `.agents/agent-plan.md`, `.agents/rules/`, `.agents/logs/`).
  - Added repo-level `GEMINI.md` and `AGENTS.md` configuration entrypoints.
  - Updated `langgraph_multi_agent.py`, `manage_loop.sh`, `run_local.sh`, and `panta-dev-loop` skill with `.agents/` paths while preserving full backward compatibility.
- **High-Autonomy Development Mode Policy (`plan-77`)**:
  - Configured workspace rule `.agents/rules/autonomy.md` enabling auto-execution of routine non-critical dev actions (code edits, test runs, linting, local builds/runs) without user interruption, reserving confirmation strictly for critical destructive actions.
- **Local Browser Testing Persona Suite**:
  - Added 1-click test personas for Anna Recycler and Erik Helper with local token bootstrap and pre-seeded recycling requests.
  - Added HTTP polling fallback for environments where WebSocket upgrades are constrained.

### Changed
- Refactored `PantaProvider` request state lifecycle to prevent unauthenticated session clear race conditions during widget tests.
- Relaxed CORS and origin policies on local dev ports (`localhost:3000`, `127.0.0.1:3000`).

---

## [1.2.0] - 2026-09-06

### Added
- **Swedish BankID Authentication & Verification (`a0748f15`)**:
  - BankID authentication flow, test simulation credentials, verification claims parsing, and profile badge.
- **Adaptive Multi-Platform Layouts (`db8e81ed`)**:
  - Responsive architecture supporting mobile, tablet, and desktop viewports (`ResponsiveContainer`, `ResponsiveCardGrid`, `AdaptiveNavigationScaffold`).
  - Navigation Rail for wide screens and bottom Navigation Bar for compact viewports.

---

## [1.1.0] - 2026-04-12

### Added
- **Helper Door Arrival Alert (`plan-65`)**:
  - One-tap "I am at the door" notification allowing helpers to alert recyclers upon arrival.
- **Recycling Gamification Engine (`plan-54`)**:
  - Recycling streaks, eco impact levels, and unlockable achievement badges.
- **Sustainability & Pant Analytics Dashboard (`plan-68`)**:
  - Historical recycling statistics, carbon offset calculator, and bottle count tracking.
- **In-App Real-Time Chat (`plan-69`)**:
  - Real-time conversation between recycler and assigned helper with contextual quick-reply chips.
- **Contactless "Leave at Door" Pickup (`plan-56`)**:
  - Contactless pickup toggle with access code instructions and photo proof on collection.
- **Automated Pant Refund Split Engine (`plan-62`)**:
  - Interactive split selector (70/30, 50/50, 100% helper) and payout calculation.
- **Receipt Scanner Simulation (`plan-67`)**:
  - Recycling receipt scanner simulation with automated pant total recognition and credit.
- **Live Helper Map & Tracking (`plan-63`, `plan-64`)**:
  - Live pickup location visualization and real-time ETA calculation.

---

## [1.0.0] - 2026-04-12

### Added
- **Production Architecture & Cloud Infrastructure**:
  - Modular Go REST API backend (`backend/cmd/api`) with modules for auth, bootstrap, requests, realtime, and uploads.
  - DynamoDB queries and GSI indices for request ownership and lifecycle tracking (`plan-1`).
  - AWS ECS Express Mode container deployment with minimal footprint cost optimization (`plan-51`).
  - Helper job pool lifecycle with cancellation recovery (`plan-50`).
  - Cross-platform Flutter mobile application supporting Swedish (`sv`) and English (`en`) localization.
