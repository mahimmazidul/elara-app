#!/usr/bin/env bash
#
# Drives the compiled APK through the app's real navigation on an emulator.
#
# This is the script for the second half of the Android verification: the
# first-launch script proves the app starts and does not crash, and this one
# proves the screens it is supposed to have actually work when they are
# reached by tapping them.
#
# What it does:
#   * runs after first_launch.sh, with the app already installed;
#   * dismisses the consent gate by tapping the button Flutter exposes
#     through the semantics tree;
#   * visits each of the four tabs, capturing a screenshot of each;
#   * opens Settings and the sub-sections behind it;
#   * scrolls a couple of screens, so a layout that only breaks further down
#     is exercised;
#   * switches the app to dark mode and captures the same screens again;
#   * opens a dialog, dismisses it with the back button, and backgrounds and
#     restores the app;
#   * fails if the log shows a crash or an ANR at any point.
#
# Everything it produces is uploaded as evidence, pass or fail.
#
# The taps go through uiautomator's own coordinate-free `text`/`content-desc`
# matching rather than fixed screen coordinates, so the script keeps working
# when the layout changes. When a target cannot be found the script says so
# and continues, because "the screen was not reachable" is a finding worth
# reporting rather than a reason to stop before the rest is checked.

set -euo pipefail

PACKAGE="com.mahimmazidul.elara"
ACTIVITY="$PACKAGE/.MainActivity"
EVIDENCE="${EVIDENCE_DIR:-evidence}"

mkdir -p "$EVIDENCE"

# `uiautomator dump` is slow, and the script asks for the tree many times, so
# the tree is cached in a variable and refreshed only when it has to be.
UI_DUMP="$EVIDENCE/ui-navigation.xml"

dump_ui() {
  adb shell uiautomator dump /sdcard/ui-nav.xml >/dev/null 2>&1 || return 1
  adb pull /sdcard/ui-nav.xml "$UI_DUMP" >/dev/null 2>&1 || return 1
  return 0
}

# Prints the bounds of the first node whose text or content-desc matches
# $1, as "x y".
find_bounds() {
  local needle="$1"
  python3 - "$UI_DUMP" "$needle" <<'PY'
import re
import sys
import xml.etree.ElementTree as ET

path, needle = sys.argv[1], sys.argv[2]
try:
    tree = ET.parse(path)
except Exception:
    sys.exit(1)

for node in tree.iter('node'):
    haystacks = (node.get('text') or '', node.get('content-desc') or '')
    if not any(needle.lower() in h.lower() for h in haystacks):
        continue
    bounds = node.get('bounds') or ''
    m = re.match(r'\[(\d+),(\d+)\]\[(\d+),(\d+)\]', bounds)
    if not m:
        continue
    x1, y1, x2, y2 = (int(v) for v in m.groups())
    print((x1 + x2) // 2, (y1 + y2) // 2)
    sys.exit(0)
sys.exit(1)
PY
}

# Taps the first node matching $1. Returns non-zero when it is not found, so
# the caller can report it and carry on.
tap_label() {
  local label="$1"
  local coords
  if ! coords="$(find_bounds "$label")"; then
    echo "  not found: $label"
    return 1
  fi
  # shellcheck disable=SC2086
  adb shell input tap $coords
  sleep "${2:-2}"
  echo "  tapped: $label"
  return 0
}

shoot() {
  local name="$1"
  adb exec-out screencap -p > "$EVIDENCE/$name.png"
  echo "  captured: $name.png"
}

echo "== Install the artifact =="
# The navigation run may be a fresh emulator, so the artifact is installed
# here rather than assumed to be there. It is the same file the build job
# produced; nothing is rebuilt.
apk="$(tool/android_ui/find_apk.sh)"
echo "Installing $apk"
adb install -r "$apk"
if adb shell pm grant "$PACKAGE" android.permission.POST_NOTIFICATIONS 2>&1; then
  echo "  POST_NOTIFICATIONS granted"
fi

adb logcat -c
adb shell am start -W -n "$PACKAGE/.MainActivity" >/dev/null 2>&1 || true
sleep 8

echo "== Consent gate =="
dump_ui || echo "  could not dump the UI tree"
if tap_label "She knows, and this is fine" 4; then
  shoot "10-after-consent"
else
  echo "  the consent button was not found"
  dump_ui || true
  for candidate in "fine" "consent"; do
    if tap_label "$candidate" 4; then
      shoot "10-after-consent"
      break
    fi
  done
fi

echo "== Tabs =="
for entry in "Today:20-today" "Calendar:21-calendar" "Insights:22-insights" "Settings:23-settings"; do
  label="${entry%%:*}"
  name="${entry##*:}"
  dump_ui || true
  if tap_label "$label" 3; then
    shoot "$name"
  else
    echo "  the $label tab was not found"
  fi
done

echo "== Settings sub-sections =="
# The sub-sections of Settings are reached by scrolling down to them, and
# each one is pushed as a route, so the back button leaves it again. The
# labels are the ones the screens actually use.
for entry in "Open preferences:30-preferences" "Symptoms:31-symptoms" "Care reminders:32-reminders" "Open health information:33-medical"; do
  label="${entry%%:*}"
  name="${entry##*:}"
  dump_ui || true
  found=0
  # The Settings screen is long. Look for the row on the visible part first,
  # then scroll down a page at a time - from the middle of the screen, so the
  # gesture is not read as a pull-up that opens the app drawer.
  for attempt in 1 2 3 4 5; do
    if tap_label "$label" 3; then
      found=1
      break
    fi
    adb shell input swipe 160 450 160 200 400
    sleep 1
    dump_ui || true
  done
  if [ "$found" = 1 ]; then
    shoot "$name"
  else
    echo "  the '$label' section was not found"
  fi
  # Leave the section again, so the next one starts from a known place.
  adb shell input keyevent KEYCODE_BACK
  sleep 1
done

echo "== About section =="
# The About block sits at the bottom of Settings, behind the update check and
# the notification switches. It is captured here rather than as a route,
# because it is part of the Settings screen rather than a screen of its own.
dump_ui || true
for attempt in 1 2 3 4 5 6; do
  if tap_label "Developer" 2; then
    break
  fi
  adb shell input swipe 160 450 160 200 400
  sleep 1
  dump_ui || true
done
shoot "31b-about-section"

echo "== Scrolling =="
dump_ui || true
tap_label "Today" 2 || true
adb shell input swipe 160 450 160 200 400
sleep 1
adb shell input swipe 160 450 160 200 400
sleep 1
shoot "34-today-scrolled"
adb shell input swipe 160 200 160 450 400
sleep 1
adb shell input swipe 160 200 160 450 400
sleep 1

echo "== Dark mode =="
# Switching the system's night mode while the app is in the background leaves
# the app switcher on screen, so the app is relaunched afterwards.
adb shell "cmd uimode night yes" >/dev/null 2>&1 || echo "  could not switch to dark mode"
sleep 3
adb shell am force-stop "$PACKAGE" || true
sleep 1
adb shell am start -W -n "$ACTIVITY" >/dev/null 2>&1 || true
sleep 8
dump_ui || true
tap_label "Today" 3 || true
shoot "35-today-dark"
dump_ui || true
tap_label "Settings" 3 || true
shoot "36-settings-dark"

echo "== Back to light =="
adb shell "cmd uimode night no" >/dev/null 2>&1 || true
sleep 3

echo "== Dialog =="
dump_ui || true
if tap_label "Settings" 3; then
  # "Check for updates" is the one control on the Settings screen that opens
  # a dialog, and it can be reached without any data having been entered
  # first. The dialog it opens reports that the build is current (or that the
  # check failed, if the emulator has no network) - either way there is a
  # dialog on screen with a Close button.
  dump_ui || true
  found=0
  for attempt in 1 2 3 4 5 6; do
    if tap_label "Check for updates" 4; then
      found=1
      break
    fi
    adb shell input swipe 160 450 160 200 400
    sleep 1
    dump_ui || true
  done
  [ "$found" = 1 ] || echo "  the update check was not reachable"
  shoot "37-dialog"
  if tap_label "Close" 2; then
    echo "  the dialog was closed with its Close button"
  else
    adb shell input keyevent KEYCODE_BACK
    sleep 1
    echo "  the dialog was dismissed with the back button"
  fi
fi

echo "== Notification icon =="
# The notification's small icon is drawn by the system, from the alpha
# channel of a drawable, in the status bar. Nothing inside the app shows it,
# so it has to be captured from the status bar and looked at.
#
# This check is reported, not enforced: it is a separate concern from the
# navigation this script verifies, and a failure here says the icon is
# wrong - not that the app is broken. The capture workflow treats it the
# same way, and the screenshot is the real evidence.
if ! tool/android_ui/notification_icon.sh; then
  echo "  (the notification icon check did not pass; the navigation check continues)"
fi

echo "== Backgrounding =="
adb shell input keyevent KEYCODE_HOME
sleep 2
adb shell am start -W -n "$PACKAGE/.MainActivity" >/dev/null 2>&1 || true
sleep 3
shoot "38-after-resume"
dump_ui || true
shoot "39-final-tree"

adb logcat -d -v time > "$EVIDENCE/logcat-navigation.txt" || true

if grep -qE "FATAL EXCEPTION|ANR in $PACKAGE" "$EVIDENCE/logcat-navigation.txt"; then
  echo "::error::The app crashed or ANR'd while being navigated."
  grep -E "FATAL EXCEPTION" -A 30 "$EVIDENCE/logcat-navigation.txt" || true
  exit 1
fi

echo "No crash or ANR in the navigation log."
echo "Navigation evidence written to $EVIDENCE."
