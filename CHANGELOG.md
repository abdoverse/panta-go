# Changelog

All notable changes to the Panta Go project are documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.4.0] - 2026-09-14

### Added
- **GDPR Cookie Consent & Legal Preference Management (`plan-85`)**:
  - Implemented Swedish LEK 2022:482 & EU GDPR compliant cookie consent system with strictly necessary, functional, analytics, and marketing categories.
  - Added bottom overlay banner (`CookieConsentBanner`) and granular preferences modal dialog (`_CookiePreferencesDialog`).
  - Added cookie management tile in `ProfileScreen` under Account settings for revocation and consent modification.
  - Added backend legal declaration endpoint (`GET /api/v1/legal/cookies`).
  - Added comprehensive unit and widget tests in `cookie_consent_test.dart` and backend `legal_test.go` with 100% localization guard compliance.

- **Admin User Suspension & Legal Investigation Controls (Item 15)**:
  - Implemented market admin controls to suspend and reinstate user accounts (`POST /api/v1/admin/users/block`, `POST /api/v1/admin/users/unblock`, `GET /api/v1/admin/users/blocks`).
  - Enforced sign-in blocking across email/password (`/api/v1/login`) and BankID authentication, as well as blocking creation of new recycling requests and acceptance/completion of jobs.
  - Returned clear, non-sensitive account restriction messages referencing the case ID to blocked users (`ACCOUNT_RESTRICTED`).
  - Implemented automatic request reconciliation: cleanly cancels unassigned pending requests, reassigns accepted helper jobs back to the pending pool, and preserves in-progress requests to protect innocent helpers.
  - Maintained a durable audit trail in `adminLogs` with case reference IDs, admin identities, reasons, and timestamps.
  - Integrated "User Suspensions & Legal Cases" oversight section and modal dialogs in `AdminDashboardPage` and `AdminApiService`.
  - Added unit and widget tests in `user_suspension_test.go` and `admin_user_suspension_test.dart` with complete Swedish and English localization.

- **Multi-Tab Session Isolation & Security (`SessionVault`)**:
  - Replaced global `localStorage` / `SharedPreferences` session credential storage on Flutter Web with tab-scoped `window.sessionStorage` via `SessionVault`.
  - Enables full session independence across different browser tabs of the same origin (e.g. testing Anna Recycler and Erik Helper simultaneously in separate tabs without session collision or overlap).
  - Automatically cleans up legacy `localStorage` session tokens to prevent cross-tab leakage.
  - Enhanced web security: session credentials are kept in memory/sessionStorage and automatically discarded when the tab is closed, preventing token persistence risks on shared or public devices.
- **Context-Aware Distance Sorting Indicator (Item 20)**:
  - Restricted the "Distance-aware sorting is enabled for this pickup" label in `HelperJobCard` exclusively to available jobs (`isAcceptable && !isCompleted`).
  - Removed the distance-aware sorting indicator from the completed Pickup History view and active assigned jobs where proximity sorting is not relevant.

- **Visual 5-Star Rating Display in Pickup History (Item 21)**:
  - Created reusable `FiveStarRatingDisplay` widget rendering 5 visual star icons (filled, half, outline) matching the rating moment.
  - Enhanced completed pickup history cards in both `HelperJobCard` and `UserRequestCard` with visual 5-star displays, score badges (e.g. `4 / 5`), and formatted user feedback quotes.
  - Added full unit and widget test coverage in `pickup_history_rating_and_sorting_test.dart`.

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
