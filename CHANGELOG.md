# Changelog

All notable changes to the Panta Go project are documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.5.0] - 2026-09-16

### Added
- **Market-Based In-App Notification System (Client-Fetched Operational Notices)**:
  - Implemented client-side server-fetched market notification system that does not rely on push notifications or device tokens.
  - Added backend endpoints:
    - `GET /api/v1/market/notifications?market={market}`: Public endpoint returning active operational notices targeted to the requested market (`SE`, `NO`, etc.) or global (`ALL` / `*`) system announcements.
    - `POST /api/v1/admin/market/notifications`: Admin-protected endpoint to broadcast operational notices with title, Swedish/English text, severity (`warning`, `critical`, `info`), and dismissibility flags.
    - `POST /api/v1/admin/market/notifications/simulate`: Endpoint for testing and simulated technical outage announcements.
  - Added in-memory thread-safe store pre-seeded with: `"We are experiencing some technical issues and are looking into it."` (`"Vi upplever för närvarande vissa tekniska problem och undersöker saken."`).
  - Added Flutter data model (`MarketNotification`) and HTTP fetch service (`MarketNotificationService`) with local dismissal persistence in `SharedPreferences`.
  - Added top-level animated banner (`MarketNotificationBanner`) in `MaterialApp.builder` in `app.dart` displaying cleanly across mobile viewports and desktop web viewports for all pages and user roles (login, recycler, helper, admin).
  - Integrated auto-refreshing in `PantaProvider` upon market switch (`setMarket`), dashboard pull-to-refresh (`UserHomePage` & `HelperHomePage`), and app initialization.
  - Added Market Announcements management section and broadcast dialog to `AdminDashboardPage`:
    - Allows administrators to view all active and historical operational announcements.
    - Added one-tap "Broadcast Announcement" modal dialog with target market selector (`ALL`, `SE`, `NO`, `DK`, `FI`, etc.), severity levels (`warning`, `critical`, `info`), and dual-language (Swedish/English) title and message composition.
    - Added instant toggle switch to activate or deactivate individual announcements.
    - Added one-tap "Simulate technical issue" action button for operational drills.
  - Added full test coverage: Go backend unit tests (`market_notifications_test.go`) and Flutter unit & widget tests (`market_notification_test.dart`, `admin_dashboard_test.dart`), maintaining 100% compliance with `l10n_guard_test.dart`.

### Fixed
- **Web Tooltip Hover Crash (`minified:jx<void>`)**: Resolved Flutter Web exception triggered when hovering over the notification banner dismiss button by replacing the default tooltip overlay trigger and enclosing the root builder in an `Overlay`.
- **Test Runner State Leakage**: Fixed un-reset `tester.view.devicePixelRatio` teardown leaks across `admin_user_suspension_test.dart`, `arrived_at_door_test.dart`, `cookie_consent_test.dart`, and `profile_screen_test.dart`, restoring test isolation across all suites.

### Changed
- **Ultra-Fast Local Feedback Loop & Tooling**:
  - Added [`scripts/fast_test.sh`](scripts/fast_test.sh) providing targeted sub-12s test execution (`fast_test.sh mobile <pattern>`) and an aggregated runner executing all 114+ Flutter tests in ~40s (down from 80+s sequential run).
  - Added `dev` target in `panta-dev-loop/scripts/run_local.sh dev` launching interactive hot reload on port 3000 without requiring 92-second release builds.
  - Cached web builds in `run_local.sh start` to reuse existing bundles when `build/web/index.html` is present.

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
