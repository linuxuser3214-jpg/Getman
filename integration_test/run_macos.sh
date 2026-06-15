#!/usr/bin/env bash
# Runs the whole Getman E2E suite on macOS in a SINGLE invocation.
#
# All flows are composed into one entry point (all_flows_test.dart) so the macOS
# app is built and launched once, then every case runs sequentially in that one
# process. (Passing multiple test *files* to `flutter test` on desktop doesn't
# work — the 2nd+ fail with "Error waiting for a debug connection" — hence the
# single aggregator file.)
#
# Usage:  bash integration_test/run_macos.sh
# Single flow during development (rebuilds, but isolates one flow):
#         fvm flutter test integration_test/flows/<name>_test.dart -d macos
set -uo pipefail

cd "$(dirname "$0")/.."

exec fvm flutter test integration_test/all_flows_test.dart -d macos
