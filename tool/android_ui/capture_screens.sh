#!/usr/bin/env bash
#
# Captures the app's screens from the installed APK on an emulator.
#
# The pictures this produces are the evidence that the *compiled* app looks
# the way the widget-tree renders say it does: they include the Android status
# bar and the navigation area, and they are what `adb exec-out screencap`
# produced, untouched.
#
# What it does:
#   * installs the debug artifact (nothing is rebuilt);
#   * grants POST_NOTIFICATIONS;
#   * dismisses the consent gate;
#   * captures each of the four tabs, light and then dark;
#   * captures the Settings sub-sections and the About block;
#   * captures the day-detail sheet from the calendar;
#   * fails if the log shows a crash or an ANR.
#
# The taps go through uiautomator's text and content-desc matching rather than
# fixed coordinates, so they keep working when the layout changes. A target
# that cannot be found is reported and the run continues: "that screen was not
# reachable" is a finding worth reporting, not a reason to stop before the rest
# has been checked.
#
# Two things this script has to be careful about, both learned from a run that
# produced the wrong pictures:
#
#   * A swipe that starts near the bottom of the screen can be read as a
#     pull-up gesture, which opens the app drawer. Every scroll here starts
#     in the middle of the screen and is followed by a check that the app is
#     still in front.
#   * Switching the system to dark mode while the app is in the background
#     leaves the app switcher on screen. The app is relaunched after the
#     switch, and the foreground is checked before anything is captured.

set -euo pipefail

PACKAGE="com.mahimmazidul.elara"
ACTIVITY="$PACKAGE/.MainActivity"
EVIDENCE="${EVIDENCE_DIR:-evidence}"
CAPTURES="$EVIDENCE"

mkdir -p "$CAPTURES"

UI_DUMP="$EVIDENCE/ui-capture.xml"

dump_ui() {
  adb shell uiautomator dump /sdcard/ui-capture.xml >/dev/null 2>&1 || return 1
  adb pull /sdcard/ui-capture.xml "$UI_DUMP" >/dev/null 2>&1 || return 1
  return 0
}

# Prints the centre of the first node whose text or content-desc matches $1,
# as "x y".
#
# An exact match wins over a substring match. A substring match is allowed as
# a fallback, because Flutter puts a whole row's text in one content-desc
# ("Care reminders\nNothing planned"), but a substring match on its own can
# land on the wrong control, and the tap then opens something else entirely.
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

exact = None
substring = None

for node in tree.iter('node'):
    haystacks = (node.get('text') or '', node.get('content-desc') or '')
    labels = [h.strip() for h in haystacks if h and h.strip()]
    if not labels:
        continue

    bounds = node.get('bounds') or ''
    m = re.match(r'\[(\d+),(\d+)\]\[(\d+),(\d+)\]', bounds)
    if not m:
        continue
    x1, y1, x2, y2 = (int(v) for v in m.groups())
    centre = ((x1 + x2) // 2, (y1 + y2) // 2)

    if any(label.lower() == needle.lower() for label in labels):
        exact = centre
        break
    if substring is None and any(needle.lower() in label.lower() for label in labels):
        substring = centre

if exact is not None:
    print(*exact)
    sys.exit(0)
if substring is not None:
    print(*substring)
    sys.exit(0)
sys.exit(1)
PY
}

# Taps the first node matching $1. Returns non-zero when it is not found.
tap_label() {
  local label="$1"
  local wait="${2:-2}"
  local coords
  if ! coords="$(find_bounds "$label")"; then
    echo "  not found: $label"
    return 1
  fi
  # shellcheck disable=SC2086
  adb shell input tap $coords
  sleep "$wait"
  echo "  tapped: $label"
  return 0
}

# Scrolls the screen down by one page.
#
# The swipe starts in the middle of the screen, never near the bottom edge:
# a swipe that begins in the bottom strip is read as a pull-up and opens the
# app drawer, which is how an earlier run ended up photographing Google
# Calendar's launcher page instead of the app's own screen.
scroll_down() {
  adb shell input swipe 160 450 160 200 400
  sleep 1
}

scroll_up() {
  adb shell input swipe 160 200 160 450 400
  sleep 1
}

# Whether Elara is the app in the foreground.
#
# Used after anything that might disturb it. If it is not, the app is
# relaunched before the next capture, so a stray drawer cannot silently
# replace a screen with a picture of something else.
#
# The check looks for a *resumed* activity line that names the package. The
# field has been called `mResumedActivity`, `topResumedActivity` and
# `mCurrentFocus` on different Android releases, so the pattern matches any
# of them rather than one; but it requires the word "resumed" or "focus" to
# be on the same line, so an activity that is merely in the back stack does
# not count.
#
# A check that silently finds nothing relaunches the app - which resets the
# scroll position of the screen being captured and makes the sections below
# the fold unreachable. That is exactly what happened: the Settings screen
# was scrolled back to the top on every section, so the health information,
# About and Privacy blocks were never reached.
elara_in_foreground() {
  local line
  while IFS= read -r line; do
    case "$line" in
      *Resumed*|*resumed*|*Focus*|*focus*)
        case "$line" in
          *"$PACKAGE"*) return 0 ;;
        esac
        ;;
    esac
  done <<EOF
$(adb shell dumpsys activity activities 2>/dev/null | head -60 || true)
EOF
  return 1
}

ensure_foreground() {
  if elara_in_foreground; then
    return 0
  fi
  echo "  (the app was not in the foreground; bringing it back)"
  adb shell am start -W -n "$ACTIVITY" >/dev/null 2>&1 || true
  sleep 3
  return 0
}

# Puts the app on the Settings tab and scrolls it back to the top.
#
# After a BACK press the app may be anywhere: on Today, on a sub-screen, or
# out of the app entirely if the tap that was supposed to open a route did
# not. Each of the Settings captures starts by putting the app back on a
# known screen, so one missed tap cannot make every later capture fail.
go_to_settings() {
  ensure_foreground
  dump_ui || true
  if ! tap_label "Settings" 2; then
    echo "  (the Settings tab was not reachable)"
    return 1
  fi
  # Back to the top of the screen, so the search starts from the beginning.
  for attempt in 1 2 3 4 5 6; do
    scroll_up
  done
  dump_ui || true
  return 0
}

shoot() {
  local name="$1"
  ensure_foreground
  adb exec-out screencap -p > "$CAPTURES/$name.png"
  echo "  captured: $name.png"
}

# Whether the screen currently shows $1.
#
# Used after a tap, so a capture is only taken of the screen that was
# actually opened. Without it, a tap that lands on the wrong control - a
# row whose subtitle happens to contain the label, or a tab at the bottom of
# the screen - produces a picture of something else under the right file
# name, which is worse than a missing picture.
shows() {
  local needle="$1"
  local coords
  if ! coords="$(find_bounds "$needle")"; then
    return 1
  fi
  return 0
}

echo "::group::Install the artifact"
# The APK is either the artifact the Android CI job uploaded, or one this job
# built in place. find_apk.sh knows both places.
apk="$(tool/android_ui/find_apk.sh)"
echo "Installing $apk"
adb install -r "$apk"
adb shell pm list packages | grep "$PACKAGE"
if adb shell pm grant "$PACKAGE" android.permission.POST_NOTIFICATIONS 2>&1; then
  echo "POST_NOTIFICATIONS granted"
else
  echo "POST_NOTIFICATIONS could not be granted (expected below API 33)"
fi
echo "::endgroup::"

adb logcat -c

echo "::group::Launch"
adb shell am start -W -n "$ACTIVITY" >/dev/null
sleep 12
shoot "00-first-launch"
echo "::endgroup::"

echo "::group::Consent gate"
dump_ui || true
if tap_label "She knows, and this is fine" 4; then
  echo "  the consent was granted"
else
  echo "  the consent button was not found"
fi
echo "::endgroup::"

# The first-run onboarding.
#
# Granting consent is not the last step: the app then asks for the date of
# the last period, and until that is given the Today screen shows an
# onboarding card instead of its content. The captures below were therefore
# all photographs of the same card - the tab label was tapped, but the tab
# was already selected, so the screen behind it never changed.
#
# So the date is chosen here, once, before anything is captured.
echo "::group::First-run onboarding"
dump_ui || true
if tap_label "Choose a date" 3; then
  echo "  the date picker was opened"
  # The picker is a Material date picker: the day cells carry the day
  # number as their text. Any day will do - the captures are about the
  # layout, not the date - so the first one with a plausible number is
  # taken.
  dump_ui || true
  day=""
  for candidate in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do
    if tap_label "$candidate" 2; then
      day="$candidate"
      break
    fi
  done
  if [ -n "$day" ]; then
    echo "  chose day $day"
    dump_ui || true
    if tap_label "OK" 2 || tap_label "Done" 2; then
      echo "  the date was accepted"
    else
      echo "  the picker was not confirmed by its own button"
    fi
  else
    echo "  no day cell was found in the picker"
  fi
  dump_ui || true
  if tap_label "Confirm" 3; then
    echo "  the first period date was confirmed"
  else
    echo "  the Confirm button was not found"
  fi
  sleep 3
else
  echo "  the onboarding card was not on screen"
fi
echo "::endgroup::"

echo "::group::Tabs, light"
for entry in "Today:01-today-light" "Calendar:03-calendar-light" "Insights:04-insights-light" "Settings:05-settings-light"; do
  label="${entry%%:*}"
  name="${entry##*:}"
  dump_ui || true
  if tap_label "$label" 3; then
    shoot "$name"
  else
    echo "  the $label tab was not found"
  fi
done

echo "::endgroup::"

echo "::group::Settings sections"
# Each entry is "label:file:expected text on the opened screen".
#
# The expected text is what proves the tap opened the screen that was
# intended. Without it, a tap that lands on the wrong control produces a
# picture of something else under the right file name.
for entry in \
    "Open preferences:06-preferences:Preferences" \
    "Symptoms:07-symptoms:Symptoms" \
    "Care reminders:08-reminders:Care reminders" \
    "Open health information:09-medical:Health information"; do
  label="${entry%%:*}"
  rest="${entry#*:}"
  name="${rest%%:*}"
  expected="${rest#*:}"
  go_to_settings
  found=0
  # The Settings screen is long. Look for the row on the visible part first,
  # then scroll down a page at a time - from the middle of the screen, so the
  # gesture is not read as a pull-up.
  for attempt in 1 2 3 4 5; do
    if tap_label "$label" 3; then
      found=1
      break
    fi
    scroll_down
    dump_ui || true
  done
  if [ "$found" = 1 ]; then
    dump_ui || true
    if shows "$expected"; then
      shoot "$name"
    else
      echo "  the '$label' row was tapped but '$expected' is not on screen;"
      echo "  the tap landed somewhere else, so nothing was captured."
    fi
  else
    echo "  the '$label' section was not found"
  fi
  adb shell input keyevent KEYCODE_BACK
  sleep 1
  ensure_foreground
done
echo "::endgroup::"

echo "::group::About block"
go_to_settings
found=0
# The About block is the last thing on the Settings screen, below the Privacy
# block, so it needs more scrolling than the sections above it. Six attempts
# was not enough: the run captured the app drawer instead of the About block,
# because the search gave up before it got there and the capture was of
# whatever happened to be on screen.
for attempt in 1 2 3 4 5 6 7 8 9 10 11 12; do
  if tap_label "Developer" 2; then
    found=1
    break
  fi
  scroll_down
  dump_ui || true
done
if [ "$found" = 1 ]; then
  dump_ui || true
  if shows "Developer"; then
    shoot "10-about"
  else
    echo "  the Developer row is not on screen, so the About block was not captured."
  fi
else
  echo "  the About block was not found"
fi
echo "::endgroup::"

echo "::group::Privacy"
go_to_settings
found=0
# The Privacy block sits above the About block, so it takes fewer scrolls than
# the About block does - but the same generous budget costs nothing when the
# row is found early, and it removes the guesswork from how far down the
# screen a given section happens to be.
for attempt in 1 2 3 4 5 6 7 8 9 10 11 12; do
  if tap_label "Privacy and data" 2; then
    found=1
    break
  fi
  scroll_down
  dump_ui || true
done
if [ "$found" = 1 ]; then
  dump_ui || true
  if shows "Privacy and data"; then
    shoot "11-privacy"
  else
    echo "  the Privacy section is not on screen, so it was not captured."
  fi
else
  echo "  the Privacy section was not found"
fi
echo "::endgroup::"

echo "::group::Day detail sheet"
dump_ui || true
tap_label "Calendar" 3 || true
dump_ui || true
# Any cell in the grid opens the day sheet. The cell's accessible name is its
# day number, so "15" is the target: any date in the month works. If the
# month does not have a fifteenth on the visible grid, any other day number
# will do, so the first one that is found is used.
day_found=0
for day in 15 16 14 17 18 19 20 21 22 23 24; do
  if tap_label "$day" 3; then
    day_found=1
    break
  fi
done
if [ "$day_found" = 1 ]; then
  dump_ui || true
  # The day sheet carries a Remove control for a recorded start, and the
  # day's date in its heading. Either confirms the sheet is open.
  if shows "Remove" || shows "day"; then
    shoot "12-day-detail"
  else
    echo "  the day sheet did not open, so it was not captured."
  fi
  adb shell input keyevent KEYCODE_BACK
  sleep 1
else
  echo "  no calendar cell was reachable"
fi
echo "::endgroup::"

echo "::group::Dark mode"
# The switch has to be followed by a relaunch: setting the system's night
# mode while the app is in the background leaves the app switcher on screen,
# and the next capture would photograph that instead of the app.
adb shell "cmd uimode night yes" >/dev/null 2>&1 || echo "  could not switch to dark mode"
sleep 3
adb shell am force-stop "$PACKAGE" || true
sleep 1
adb shell am start -W -n "$ACTIVITY" >/dev/null 2>&1 || true
sleep 8
ensure_foreground

dump_ui || true
tap_label "Today" 3 || true
shoot "13-today-dark"
dump_ui || true
tap_label "Calendar" 3 || true
shoot "14-calendar-dark"
dump_ui || true
tap_label "Insights" 3 || true
shoot "15-insights-dark"
dump_ui || true
tap_label "Settings" 3 || true
shoot "16-settings-dark"

adb shell "cmd uimode night no" >/dev/null 2>&1 || true
sleep 3
echo "::endgroup::"

echo "::group::Notification icon"
# The notification's small icon is drawn by the system in the status bar, so
# nothing inside the app shows it. It is captured and magnified here, and
# the numbered capture is committed with the rest of the evidence.
EVIDENCE_DIR="$EVIDENCE" tool/android_ui/notification_icon.sh || true
echo "::endgroup::"

adb logcat -d -v time > "$EVIDENCE/logcat-capture.txt" || true

if grep -qE "FATAL EXCEPTION|ANR in $PACKAGE" "$EVIDENCE/logcat-capture.txt"; then
  echo "::error::The app crashed or ANR'd while being captured."
  grep -E "FATAL EXCEPTION" -A 30 "$EVIDENCE/logcat-capture.txt" || true
  exit 1
fi

echo "No crash or ANR in the capture log."
echo "Device captures written to $CAPTURES."
