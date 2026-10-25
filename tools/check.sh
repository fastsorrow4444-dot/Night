#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
godot_bin="${GODOT_BIN:-godot}"
"$godot_bin" --headless --path . --editor --import --quit
mkdir -p test-results
touch test-results/.gdignore
log_file="$(mktemp)"
trap 'rm -f "$log_file"' EXIT
for runner in SmokeRunner FeatureRunner AnimationRunner; do
  test_status=0
  "$godot_bin" --headless --path . --fixed-fps 60 --quit-after 6000 --scene "res://tests/$runner.tscn" >"$log_file" 2>&1 || test_status=$?
  cat "$log_file"
  if (( test_status != 0 )); then
    exit "$test_status"
  fi
  if ! grep -Eq '^RESULT: [1-9][0-9]* checks, 0 failures$' "$log_file"; then
    exit 1
  fi
  if grep -Eq '^(SCRIPT ERROR|ERROR):' "$log_file"; then
    exit 1
  fi
done
