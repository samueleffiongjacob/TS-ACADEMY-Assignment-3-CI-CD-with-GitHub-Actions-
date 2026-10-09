#!/usr/bin/env bash
# =============================================================================
# tests/test.sh - Automated tests for app/app.sh (no Docker needed).
# Each test runs the app, then checks the exit code and (optionally) the output.
# Exit: 0 = all tests passed, 1 = at least one failed
# =============================================================================

set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/app/app.sh"
PASSED=0
FAILED=0

# run_test NAME EXPECTED_EXIT_CODE EXPECTED_TEXT ARGS...
#   EXPECTED_TEXT is matched case-insensitively; use "" to skip the text check.
run_test() {
    local name="$1" want_rc="$2" want_text="$3" out rc
    shift 3
    out="$("$APP" "$@" 2>&1)"
    rc=$?

    if [[ $rc -ne $want_rc ]]; then
        echo "FAIL: $name (exit $rc, expected $want_rc)"
        FAILED=$((FAILED + 1))
    elif [[ -n "$want_text" ]] && ! grep -qi -- "$want_text" <<<"$out"; then
        echo "FAIL: $name (output missing '$want_text')"
        FAILED=$((FAILED + 1))
    else
        echo "PASS: $name"
        PASSED=$((PASSED + 1))
    fi
}

echo "== Running tests for app.sh =="

run_test "help shows usage"                  0 "Usage"           help
run_test "system-info shows kernel"          0 "Kernel"          system-info
run_test "system-info shows hostname"        0 "Hostname"        system-info
run_test "no command exits 2"                2 "Usage"
run_test "invalid command exits 2"           2 "unknown command" not-a-command
run_test "check-host without host exits 2"   2 "requires a host" check-host
run_test "check-host with bad host exits 2"  2 "invalid host"    check-host 'bad host!'
run_test "check-host localhost succeeds"     0 "resolves to"     check-host localhost
run_test "check-port without port exits 2"   2 "requires a port" check-port localhost
run_test "check-port non-numeric port"       2 "integer"         check-port localhost abc
run_test "check-port port 0 rejected"        2 "integer"         check-port localhost 0
run_test "check-port port 65536 rejected"    2 "integer"         check-port localhost 65536
run_test "check-port negative port rejected" 2 "integer"         check-port localhost -1

echo
echo "Passed: $PASSED   Failed: $FAILED"
[[ $FAILED -eq 0 ]]
