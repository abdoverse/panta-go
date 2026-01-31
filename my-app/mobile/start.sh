#!/bin/bash
# Script to setup and run the Panta mobile application

set -e # Exit on error

# Navigate to the mobile directory (relative to script location)
BASE_DIR="$(dirname "$0")"
cd "$BASE_DIR"

echo "========================================"
echo "   Panta Recycling App - Mobile Setup   "
echo "========================================"

# Check for Flutter
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter SDK not found. Please install Flutter."
    echo "   Visit: https://docs.flutter.dev/get-started/install"
    exit 1
fi

echo "✅ Flutter found."

# Generate platform-specific build files (Linux, Web, etc.) if missing
echo "🛠️  Generating platform files..."
flutter create .

# Install dependencies
echo "📦 Installing packages..."
flutter pub get

# Seed backend data
echo "🌱 Seeding backend data..."
if [ -f "../../seed.js" ]; then
    node ../../seed.js
else
    echo "⚠️  Seed script not found at ../../seed.js, skipping."
fi

# Run the app
echo "🚀 Launching App..."
echo "   If multiple devices are connected, select one from the list."
flutter run -d chrome --web-port 3000
