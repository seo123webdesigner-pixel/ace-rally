#!/usr/bin/env bash
#
# Ace Rally verification. Runs every check in order and stops at the first failure.
# Exits 0 with a PASS banner, non-zero with a FAIL banner, so it works in CI.

set -u
set -o pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

GODOT="${GODOT:-godot}"

# Godot exits 0 even when scripts fail to parse, so the project-load check has to
# read the output as well as the exit code. Measured against 4.7.2.
ERROR_PATTERN='^(SCRIPT ERROR|ERROR|USER ERROR|USER SCRIPT ERROR|FATAL):'

# GUT exits 0 even when a test script fails to parse: it prints a warning, skips
# the whole file and still reports "All tests passed". Measured on 9.7.1 during
# Sprint 1, where a parse error in test_scenes.gd cost 10 tests silently. These
# patterns are what turn that back into a failure.
GUT_SKIP_PATTERN='(Ignoring script|Parse Error:|SCRIPT ERROR:)'
GUT_SUCCESS_PATTERN='All tests passed'

step_number=0

banner_fail() {
	echo
	echo "=================================================="
	echo "  FAIL: $1"
	echo "=================================================="
	exit 1
}

start_step() {
	step_number=$((step_number + 1))
	echo
	echo "--- Step ${step_number}: $1 ---"
}

if ! command -v "$GODOT" >/dev/null 2>&1; then
	banner_fail "godot not found on PATH (set GODOT=/path/to/godot to override)"
fi

echo "Ace Rally verification"
echo "godot: $("$GODOT" --version)"

# ------------------------------------------------------------------------------
start_step "Import assets and register addon class_names"
# On a fresh clone the GUT global classes are not in .godot/global_script_class_cache
# yet, and gut_cmdln.gd refuses to run without them. This step is what makes CI work.
import_log="$(mktemp)"
trap 'rm -f "$import_log"' EXIT
if ! "$GODOT" --headless --import --path . >"$import_log" 2>&1; then
	cat "$import_log"
	banner_fail "asset import failed"
fi
echo "ok"

# ------------------------------------------------------------------------------
start_step "Parse check (project load)"
parse_output="$("$GODOT" --headless --quit --path . 2>&1)"
parse_status=$?
echo "$parse_output"
if [ $parse_status -ne 0 ]; then
	banner_fail "parse check exited ${parse_status}"
fi
if echo "$parse_output" | grep -qE "$ERROR_PATTERN"; then
	banner_fail "parse check reported errors (see output above)"
fi
echo "ok"

# ------------------------------------------------------------------------------
start_step "GUT test suite"
gut_output="$("$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://test -ginclude_subdirs -gexit 2>&1)"
gut_status=$?
echo "$gut_output"
if [ $gut_status -ne 0 ]; then
	banner_fail "GUT suite exited ${gut_status}"
fi
if echo "$gut_output" | grep -qE "$GUT_SKIP_PATTERN"; then
	banner_fail "GUT skipped or failed to parse a test script (see output above)"
fi
if ! echo "$gut_output" | grep -qE "$GUT_SUCCESS_PATTERN"; then
	banner_fail "GUT did not report success (see output above)"
fi

# ------------------------------------------------------------------------------
echo
echo "=================================================="
echo "  PASS: all checks succeeded"
echo "=================================================="
exit 0
