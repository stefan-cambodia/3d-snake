#!/usr/bin/env bash
# Run the headless test suite. Extra args are passed to the runner, e.g.
#   tools/run_tests.sh --filter=test_spine
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-tools/godot/godot}"
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
exec "$GODOT" --headless --path . -s tests/run_tests.gd -- "$@"
