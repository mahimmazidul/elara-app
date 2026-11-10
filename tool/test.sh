#!/usr/bin/env bash
#
# Run the fast, relevant part of the suite while developing.
#
# The full suite belongs to CI: see docs/TESTING_POLICY.md. The development
# sandbox has a 2 GB memory ceiling and cannot compile the larger widget
# suites, so running everything here fails for reasons that have nothing to do
# with the code.
#
# Usage:
#   tool/test.sh                       # the fast suites, by default
#   tool/test.sh test/providers/       # one directory
#   tool/test.sh test/foo_test.dart    # one file
#   tool/test.sh --all                 # the whole suite (needs the memory)
#
set -euo pipefail

cd "$(dirname "$0")/.."

# The suites that are quick to compile and quick to run. Everything else is
# left to CI on purpose.
FAST=(
  test/app_info_test.dart
  test/data
  test/providers
  test/services
  test/theme
  test/utils
)

if [ "${1:-}" = "--all" ]; then
  exec flutter test --reporter expanded
fi

if [ "$#" -gt 0 ]; then
  exec flutter test --reporter expanded "$@"
fi

echo "Running the fast suites; the widget suites and the full run are CI's job."
echo "(docs/TESTING_POLICY.md explains why.)"
exec flutter test --reporter compact "${FAST[@]}"
