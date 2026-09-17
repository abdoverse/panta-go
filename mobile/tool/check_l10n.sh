#!/usr/bin/env bash
set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MOBILE_DIR="$PROJECT_ROOT/mobile"
cd "$MOBILE_DIR"

get_timestamp() {
    date +%s.%N 2>/dev/null || date +%s
}

format_time() {
    date +"%H:%M:%S"
}

format_duration() {
    local start="$1"
    local end="$2"
    python3 -c "
import sys
try:
    s = float('$start')
    e = float('$end')
    elapsed = max(0.0, e - s)
    mins = int(elapsed // 60)
    secs = elapsed % 60
    if mins > 0:
        print(f'{mins}m {secs:.1f}s ({elapsed:.2f}s)')
    else:
        print(f'{elapsed:.2f}s')
except Exception:
    print('unknown')
" 2>/dev/null || awk -v s="$start" -v e="$end" 'BEGIN { d = e - s; if (d < 0) d = 0; if (d >= 60) printf "%dm %.1fs (%.2fs)\n", int(d/60), (d%60), d; else printf "%.2fs\n", d }'
}

start_all=$(get_timestamp)
start_clock=$(format_time)

echo "============================================================"
echo "🌐 STARTING LOCALIZATION AUDIT"
echo "🕒 Started at: $start_clock"
echo "============================================================"
echo ""

echo "🔍 [1/2] Running Dart AST Localization Scanner..."
t0=$(get_timestamp)
set +e
dart run tool/l10n_scanner.dart --check
scanner_exit=$?
set -e
t1=$(get_timestamp)
scanner_dur=$(format_duration "$t0" "$t1")
if [ $scanner_exit -ne 0 ]; then
    echo "❌ AST scanner failed after $scanner_dur!"
    exit $scanner_exit
fi
echo "✅ AST scanner completed in $scanner_dur!"
echo ""

echo "🛡️  [2/2] Running Automated Flutter Localization Guard Test..."
t2=$(get_timestamp)
set +e
flutter test test/l10n_guard_test.dart
guard_exit=$?
set -e
t3=$(get_timestamp)
guard_dur=$(format_duration "$t2" "$t3")
if [ $guard_exit -ne 0 ]; then
    echo "❌ Localization guard test failed after $guard_dur!"
    exit $guard_exit
fi
echo "✅ Localization guard test completed in $guard_dur!"

end_all=$(get_timestamp)
end_clock=$(format_time)
total_dur=$(format_duration "$start_all" "$end_all")

echo ""
echo "============================================================"
echo "⏱️  LOCALIZATION AUDIT SUMMARY"
echo "============================================================"
echo "  🔍 AST Scanner:       $scanner_dur [✅ PASSED]"
echo "  🛡️  Flutter Guard:     $guard_dur [✅ PASSED]"
echo "  ----------------------------------------------------------"
echo "  🎯 Overall Status:    ✅ PASSED (100% compliant)"
echo "  ⏱️  Total Duration:    $total_dur"
echo "  🕒 Started:           $start_clock"
echo "  🕒 Finished:          $end_clock"
echo "============================================================"
