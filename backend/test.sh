#!/usr/bin/env bash
# backend/test.sh - Run Go backend test suite with execution timing banner
set -e
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"$DIR/../scripts/fast_test.sh" backend "$@"
