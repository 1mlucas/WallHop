#!/bin/sh
# Runs the headless simulation test. Passes only if the test printed "PASS:".
# (When a script fails to parse, Godot still exits with code 0, so the exit
# code alone cannot be trusted.)
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
cd "$(dirname "$0")/.." || exit 1
out=$("$GODOT" --headless --path . --script tests/sim_run.gd 2>&1)
code=$?
echo "$out" | grep -E "^run |^fruit tower|PASS|FAIL|SCRIPT ERROR"
if [ $code -eq 0 ] && echo "$out" | grep -q "^PASS:" && ! echo "$out" | grep -q "SCRIPT ERROR"; then
	exit 0
fi
echo "TESTS FAILED"
exit 1
