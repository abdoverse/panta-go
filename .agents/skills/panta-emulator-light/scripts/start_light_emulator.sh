#!/usr/bin/env bash
# start_light_emulator.sh - Launches the ultra-lightweight Android emulator with zero overhead

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
EMULATOR_BIN="/home/abdo/Android/Sdk/emulator/emulator"
AVD_NAME="panta_emulator_lite"

# Check if an emulator is already connected
if adb devices | grep -q "emulator-"; then
    echo "ℹ️  Android emulator is already running and connected."
else
    echo "🚀 Starting ultra-lightweight Android emulator ($AVD_NAME)..."
    
    # Launch with minimum resource consumption
    setsid "$EMULATOR_BIN" \
        -avd "$AVD_NAME" \
        -no-boot-anim \
        -no-audio \
        -camera-back none \
        -camera-front none \
        -timezone Europe/Stockholm \
        -netdelay none \
        -netspeed full \
        -no-metrics \
        > /dev/null 2>&1 &
    
    echo "⏳ Waiting for emulator to connect to adb..."
    adb wait-for-device
    
    echo "⏳ Waiting for Android system boot to complete..."
    while [ "$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" != "1" ]; do
        sleep 1
    done
    echo "✅ Emulator booted successfully!"
fi

# Apply real-time performance and responsiveness optimizations
echo "⚡ Applying ultra-responsive system tweaks..."
adb shell "settings put global window_animation_scale 0"
adb shell "settings put global transition_animation_scale 0"
adb shell "settings put global animator_duration_scale 0"
adb shell "settings put global stay_on_while_plugged_in 3"
adb shell "settings put secure location_mode 3"

# Setup reverse port forwarding to local Go backend
echo "🔌 Forwarding backend port (8080) to emulator..."
adb reverse tcp:8080 tcp:8080

echo "🎉 Ultra-light emulator is ready for testing!"
