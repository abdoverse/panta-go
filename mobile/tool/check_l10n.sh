#!/usr/bin/env bash
set -e

echo "Running Dart AST Localization Scanner..."
dart run tool/l10n_scanner.dart --check

echo "Running Automated Flutter Localization Guard Test..."
flutter test test/l10n_guard_test.dart

echo "✅ All components adhere to the localization policy!"
