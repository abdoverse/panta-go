#!/usr/bin/env bash
# mobile/test.sh - Run Flutter test suite with execution timing banner
set -e
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"$DIR/../scripts/fast_test.sh" mobile "$@"
