---
name: coding-standards
description: Enforce architectural guidelines, testing practices, and security rules across Panta Go backend, Flutter frontend, and AWS infrastructure.
trigger: always_on
---

# Panta Project Coding Standards & Guidelines

## 1. Backend (Go)
- **Modular Structure**: Keep code organized in focused packages/modules under `my-app/backend/cmd/api/` (`auth.go`, `bootstrap.go`, `chat_security.go`, `market_config.go`, `requests.go`, `realtime.go`, `types.go`).
- **Data Protection & GDPR**:
  - All chat messages stored at rest in DynamoDB must be encrypted via AES-256-GCM (`chat_security.go`) with requestID AAD binding.
  - Plaintext fallback must remain supported for backward compatibility with legacy rows.
  - Preserve 30-day retention policies and implement Article 17 Right to Erasure endpoints.
  - Maintain full UTF-8 support for Swedish characters (`å`, `ä`, `ö`) and emojis.
- **Testing**: Maintain unit test coverage for new endpoints and security modules; run `go test ./...` to verify.

## 2. Frontend (Flutter / Dart)
- **State Management**: Use `Provider` (`PantaProvider`) with separated state domain handlers (`panta_state_services.dart`).
- **Responsive Architecture**: Use `ResponsiveContainer`, `ResponsiveCardGrid`, and `AdaptiveNavigationScaffold` for seamless scaling across mobile, tablet, and desktop viewports.
- **Privacy First**: Never display personal identity numbers (e.g. Swedish personnummer) in the UI; show verified badges only.
- **Testing**: Maintain widget and unit test suites; run `flutter test` across `my-app/mobile`. Use `tester.runAsync` when awaiting provider async initialization to avoid fake-async event loop deadlocks.

## 3. Local Development & Demo Modes
- Provide 1-click test personas for rapid browser evaluation (`http://localhost:3000`).
- Ensure local HTTP polling fallback exists alongside WebSockets for restricted local network environments.
