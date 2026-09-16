---
name: panta-emulator-light
description: Launches and manages the ultra-lightweight Android emulator (Nexus 4 / Android 7.1) for Panta mobile testing with zero host overhead, instant snapshot boot, disabled window animations, and automatic reverse port forwarding. Use when the user asks to start, test, or run the app on the Android emulator in a lightweight configuration.
---

# Panta Ultra-Light Android Emulator Skill

This skill provides an optimized, low-overhead mobile testing environment on Linux. It prevents system freezes, "Application Not Responding" (ANR) popups, and high CPU usage commonly caused by heavy Android 14 / Impeller Vulkan emulation on integrated GPUs.

---

## Why this Setup is 10x Lighter

1. **Nexus 4 Resolution (768x1280)**: Low DPI requires far less pixel rendering and memory than full-HD or 4K phone profiles.
2. **Android 7.1 / API 24 Image**: Runs the stable Skia renderer without Impeller Vulkan shader compilation stalls on integrated Intel GPUs.
3. **Zero Audio & Camera Overhead**: Audio and camera emulation are completely disabled (`-no-audio`, `-camera-back none`), eliminating background audio polling threads.
4. **Animation Scaling Disabled (0x)**: `window_animation_scale`, `transition_animation_scale`, and `animator_duration_scale` are set to `0`, making UI interactions immediate without frame drops.
5. **Port Forwarding Pre-Configured**: Automatically executes `adb reverse tcp:8080 tcp:8080` so the emulator reaches the local Go backend on `http://10.0.2.2:8080` or `http://localhost:8080`.
6. **Optimized RAM & Heap**: Configured with 1536MB RAM and 256MB VM heap to completely prevent Dalvik Garbage Collection thrashing.

---

## Quick Start Commands

### 1. Start the Light Emulator
```bash
.agents/skills/panta-emulator-light/scripts/start_light_emulator.sh
```

### 2. Run the Panta Flutter App
```bash
.agents/skills/panta-emulator-light/scripts/run_app.sh
```
*(Supports Hot Reload `r` and Hot Restart `R` directly in the terminal).*

### 3. Stop the Emulator
```bash
.agents/skills/panta-emulator-light/scripts/stop_emulator.sh
```

---

## Manual Execution Reference

If running commands directly:
```bash
# Start emulator in background with light flags
setsid /home/abdo/Android/Sdk/emulator/emulator \
    -avd panta_emulator_lite \
    -no-boot-anim \
    -no-audio \
    -camera-back none \
    -camera-front none \
    -timezone Europe/Stockholm \
    -netdelay none \
    -netspeed full \
    -no-metrics > /dev/null 2>&1 &

# Forward ports
adb reverse tcp:8080 tcp:8080

# Disable UI animation overhead
adb shell settings put global window_animation_scale 0
adb shell settings put global transition_animation_scale 0
adb shell settings put global animator_duration_scale 0

# Run Flutter mobile app
cd mobile && flutter run -d emulator-5554 --dart-define=API_BASE_URL="http://10.0.2.2:8080"
```
