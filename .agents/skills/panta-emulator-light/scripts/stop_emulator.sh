#!/usr/bin/env bash
# stop_emulator.sh - Gracefully shut down running Android emulator

echo "🛑 Shutting down Android emulator..."
adb -s emulator-5554 emu kill 2>/dev/null || killall qemu-system-x86_64 2>/dev/null || true
echo "✅ Emulator stopped."
