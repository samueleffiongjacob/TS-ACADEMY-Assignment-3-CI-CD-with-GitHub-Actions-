#!/usr/bin/env bash
# =============================================================================
# lint.sh - Static checks for the project.
#   1. Every required file exists
#   2. `bash -n` (syntax check) passes for every Bash script
#   3. ShellCheck runs too, if it is installed (optional extra)
# Exit: 0 = clean, 1 = a problem was found
# #######
# =============================================================================

set -u

# Always run from the repository root, wherever the script is called from.
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1

ERRORS=0

echo "== Checking required files =="
REQUIRED=(
    README.md app/app.sh scripts/lint.sh scripts/build.sh tests/test.sh
    Dockerfile compose.yaml .dockerignore .github/workflows/ci.yml grade.sh
)
for f in "${REQUIRED[@]}"; do
    if [[ -f "$f" ]]; then
        echo "  ok      $f"
    else
        echo "  MISSING $f"
        ERRORS=$((ERRORS + 1))
    fi
done

echo "== Bash syntax check (bash -n) =="
for f in app/*.sh scripts/*.sh tests/*.sh grade.sh; do
    [[ -f "$f" ]] || continue
    if bash -n "$f"; then
        echo "  ok      $f"
    else
        echo "  SYNTAX ERROR in $f"
        ERRORS=$((ERRORS + 1))
    fi
done

echo "== ShellCheck (optional) =="
if command -v shellcheck >/dev/null 2>&1; then
    # -S warning: only fail on warnings and errors, not style suggestions.
    if shellcheck -S warning app/*.sh scripts/*.sh tests/*.sh; then
        echo "  ok      shellcheck passed"
    else
        echo "  shellcheck reported problems"
        ERRORS=$((ERRORS + 1))
    fi
else
    echo "  skipped (shellcheck not installed)"
fi

echo
if [[ $ERRORS -eq 0 ]]; then
    echo "Lint passed"
    exit 0
fi
echo "Lint failed with $ERRORS problem(s)"
exit 1
