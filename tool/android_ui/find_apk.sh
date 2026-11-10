#!/usr/bin/env bash
#
# Prints the path of the debug APK to install, or fails.
#
# The APK is in one of two places depending on how the run was set up:
#
#   * the Android CI job builds it and uploads it as an artifact, which the
#     emulator job then downloads into `artifact/`;
#   * the device-screenshots job builds it in place, so it stays under the
#     Flutter output directory.
#
# Both scripts that install the APK use this, so a change to where the build
# lands is a change to one file rather than to three.
#
# Usage:  apk_path="$(tool/android_ui/find_apk.sh)"

set -euo pipefail

candidates=(
  # Downloaded from the `elara-debug-apk` artifact.
  "artifact/app-debug.apk"
  # Built in place by this job.
  "build/app/outputs/flutter-apk/app-debug.apk"
)

for candidate in "${candidates[@]}"; do
  if [ -s "$candidate" ]; then
    echo "$candidate"
    exit 0
  fi
done

echo "::error::No debug APK found. Looked for:" >&2
for candidate in "${candidates[@]}"; do
  echo "::error::  $candidate" >&2
done
echo "::error::Under artifact/: $(ls artifact 2>/dev/null || echo '(missing)')" >&2
echo "::error::Under build/app/outputs/flutter-apk/: $(ls build/app/outputs/flutter-apk 2>/dev/null || echo '(missing)')" >&2
exit 1
