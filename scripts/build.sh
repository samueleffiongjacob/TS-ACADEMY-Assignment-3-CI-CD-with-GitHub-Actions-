#!/usr/bin/env bash
# =============================================================================
# build.sh - Build the Docker image and run smoke tests against it.
#
# Smoke tests:
#   help            -> must exit 0
#   system-info     -> must exit 0
#   invalid command -> must exit 2 (proves error handling works in the image)
# Exit: 0 = built and all smoke tests passed, 1 = failure, 2 = Docker missing
# the image name can be overridden by setting the IMAGE environment variable.
# =============================================================================

set -u

cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1

IMAGE="${IMAGE:-devops-tool}"
FAILED=0

if ! command -v docker >/dev/null 2>&1; then
    echo "ERROR: Docker is not installed or not on PATH" >&2
    exit 2
fi

echo "== Building image '$IMAGE' =="
if ! docker build -t "$IMAGE" .; then
    echo "Build FAILED" >&2
    exit 1
fi

# smoke NAME EXPECTED_EXIT_CODE ARGS...   (ARGS are passed to the container)
smoke() {
    local name="$1" want="$2" rc
    shift 2
    docker run --rm "$IMAGE" "$@" >/dev/null 2>&1
    rc=$?
    if [[ $rc -eq $want ]]; then
        echo "  PASS: $name (exit $rc)"
    else
        echo "  FAIL: $name (exit $rc, expected $want)"
        FAILED=$((FAILED + 1))
    fi
}

echo "== Smoke tests =="
smoke "help"                  0 help
smoke "system-info"           0 system-info
smoke "invalid command fails" 2 invalid-command

echo
if [[ $FAILED -eq 0 ]]; then
    echo "Docker build and smoke tests passed"
    exit 0
fi
echo "$FAILED smoke test(s) failed"
exit 1
