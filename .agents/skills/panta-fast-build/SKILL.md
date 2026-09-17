---
name: panta-fast-build
description: Guidelines, performance benchmarks, and protocols for fast development cycles, build optimization, targeted testing, and preserving compiler cache states in the Panta project. Use when building, testing, compiling, or optimizing Flutter/Go cycle times.
---

# Panta Fast Build & Feedback Loop Optimization Skill

This skill documents the hardware profile, performance diagnostics, and operational protocols required to keep the build and testing cycle ultra-fast on this system.

---

## 1. System Profile & Hardware Reality

- **Host CPU**: Intel Core i5-6200U (2 cores / 4 threads, 2.3 GHz base, 2.8 GHz turbo).
  - Typically operates under the Linux `powersave` governor at ~1.0 GHz.
  - Compute-heavy JIT/AOT compiler passes (like Dart AST analysis and `frontend_server_aot`) take ~30s on a cold start.
- **Disk Utilization**: `/dev/sda2` is at ~93% capacity (~40 GB free out of 549 GB due to `/home/abdo/disk.img` 315 GB).
  - High disk utilization increases ext4 block allocation latency and write amplification.
  - Minimizing throwaway disk churn and preserving compiler caches is critical for responsiveness.

---

## 2. Core Protocols for Build & Test Execution

### A. Preserve Warm Kernel Caches (`build/test_cache`)
- **NEVER** run `flutter clean` routinely before tests or builds.
- Profiling breakdown:
  - Cold compile (`flutter test -v` without cache): **31.7s compilation** + 3.3s test execution = **~35-44s**.
  - Warm compile (reusing `build/test_cache`): **~4s compilation** + 3.3s test execution = **~12s**.
- Only run `flutter clean` when there is verifiable cache corruption or stale native binary linkage failure.

### B. Use Targeted Tests During Active Development
- When developing a feature, **always** run targeted tests:
  ```bash
  # Targeted test (takes ~8-12s):
  ./scripts/fast_test.sh mobile <feature-name-or-pattern>
  # Examples:
  ./scripts/fast_test.sh mobile chat_notification
  ./scripts/fast_test.sh mobile market_notification
  ./scripts/fast_test.sh mobile admin_dashboard
  ```
- For Go backend changes:
  ```bash
  # Takes ~1-2s:
  ./scripts/fast_test.sh backend
  ```
- **Only run full stack verification before commits or major merges**:
  ```bash
  ./scripts/fast_test.sh all    # Full suite (~36s on warm cache)
  ```

### C. Keep Telemetry & Network Overhead Disabled
- Keep analytics disabled to eliminate outbound network telemetry latencies:
  ```bash
  flutter config --no-analytics
  dart --disable-analytics
  ```

### D. Localization Scanner Efficiency
- `mobile/tool/check_l10n.sh` invokes the Dart AST analyzer.
- Because `package:analyzer` takes ~20s to parse all project files on this CPU, only run `check_l10n.sh` when new UI strings or localization keys are introduced or modified, not on purely backend/state changes.

### E. Low-Overhead Local Stack Execution
- When testing the UI locally in the browser, prefer:
  ```bash
  scripts/run_local.sh dev
  # Or:
  scripts/run_dev.sh
  ```
  This uses Flutter Hot Reload on port 3000 rather than rebuilding release web bundles.
- If testing on Android, always use the lightweight profile:
  ```bash
  .agents/skills/panta-emulator-light/scripts/start_light_emulator.sh
  ```
  (Nexus 4 resolution, Skia renderer, 0x animations, no audio/camera overhead).
