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

# The display, read from the device rather than assumed.
#
# An earlier version of this script scrolled with `input swipe 160 450 160 200`
# and that worked, because the AVD is 320x640 and those points are on it. A
# later version "improved" the swipe to 540 1400 -> 540 700, which is a good
# swipe on a 1080x2340 phone and lies entirely outside this display: `input
# swipe` with both points off-screen scrolls nothing at all. The run then
# reported "the 'Health information' section was not found" eight times, because
# the hub never moved and only the four rows above the fold were ever on screen.
#
# So the geometry is read from the device, and every coordinate below is a
# fraction of it.
SCREEN_W=320
SCREEN_H=640

read_geometry() {
  local line dims
  line="$(adb shell wm size 2>/dev/null | tr -d '\r' | tail -n 1)"
  dims="${line##*: }"
  case "$dims" in
    [0-9]*x[0-9]*) SCREEN_W="${dims%%x*}"; SCREEN_H="${dims##*x}" ;;
  esac
  case "$SCREEN_W" in ''|*[!0-9]*) SCREEN_W=320 ;; esac
  case "$SCREEN_H" in ''|*[!0-9]*) SCREEN_H=640 ;; esac
  echo "Screen is ${SCREEN_W}x${SCREEN_H}"
}

# Everything this script prints also lands in the evidence artifact.
#
# This is the fix for the failure that made this rewrite necessary. The job
# exited with "The process '/usr/bin/sh' failed with exit code 255", the
# evidence artifact was a quarter of its usual size, and there was no way to see
# which line died or why: the script's own output lived only in a job log that
# needs an account to read, and the logcat was not written until the very last
# line of the script, which an abort never reaches.
#
# Now: stdout goes to the Actions log *and* to a file that ships with the
# screenshots, and a failure names its line.
CAPTURE_LOG="$EVIDENCE/capture-script.log"
: > "$CAPTURE_LOG"
exec > >(tee -a "$CAPTURE_LOG") 2>&1

on_error() {
  local status=$?
  echo "::error::capture_screens.sh stopped at line $1 with exit $status, while running: $2" >&2
  echo "The script log and the logcat up to this point are in the evidence artifact." >&2
  exit "$status"
}
trap 'on_error "$LINENO" "$BASH_COMMAND"' ERR

# Every adb call goes through here.
#
# Exit code 255 is adb's way of saying the device connection is gone, and with
# `set -e` a single one of those aborted the whole capture at whatever line it
# happened to hit. The device is a nested virtual machine on a shared runner;
# losing it for a second is a normal event, reconnecting is the fix, and only
# losing it four times in a row is a failure worth failing on.
adb_run() {
  local attempt
  for attempt in 1 2 3 4; do
    if adb "$@"; then
      return 0
    fi
    # On stderr, so the message survives a caller that is capturing stdout -
    # `shoot` redirects this function's output into a PNG, and a note written to
    # stdout would end up inside the image.
    echo "  adb $1 failed (attempt $attempt); reconnecting to the device" >&2
    adb reconnect >/dev/null 2>&1 || true
    timeout 30 adb wait-for-device >/dev/null 2>&1 || true
    sleep $((attempt * 2))
  done
  echo "::error::adb could not run: adb $*" >&2
  return 1
}

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
  echo "  tapping '$label' at ($coords)"
  # shellcheck disable=SC2086
  adb_run shell input tap $coords
  sleep "$wait"
  echo "  tapped: $label"
  return 0
}

# Taps a row on a long scrolling screen, unless it is sitting under the tab bar.
#
# The Settings hub is taller than the display, so its last rows scroll down to
# within a few pixels of the bottom - where the tab bar is drawn over them. A
# tap on the centre of such a row lands on the tab bar instead: the app switches
# tab, and the step that follows looks for a page that was never opened and
# reports the section missing. Treating a row that low as "not found yet" makes
# the search scroll once more, and the next attempt finds it higher up.
tap_row() {
  local label="$1"
  local wait="${2:-3}"
  local coords x y limit
  if ! coords="$(find_bounds "$label")"; then
    echo "  not found: $label"
    return 1
  fi
  x="${coords%% *}"
  y="${coords##* }"
  limit=$(( SCREEN_H * 85 / 100 ))
  if [ "$y" -gt "$limit" ]; then
    echo "  '$label' is under the tab bar at y=$y; scrolling it up before tapping"
    return 1
  fi
  echo "  tapping '$label' at ($x,$y)"
  adb_run shell input tap "$x" "$y"
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
  # Half the height, from 65% down to 35%, both points well inside the display
  # whatever its size.
  adb_run shell input swipe \
    $((SCREEN_W / 2)) $((SCREEN_H * 65 / 100)) \
    $((SCREEN_W / 2)) $((SCREEN_H * 35 / 100)) 400
  sleep 1
}

scroll_up() {
  adb_run shell input swipe \
    $((SCREEN_W / 2)) $((SCREEN_H * 35 / 100)) \
    $((SCREEN_W / 2)) $((SCREEN_H * 65 / 100)) 400
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

# Whether the tab bar says this tab is the selected one.
#
# The bar reports itself honestly: each tab is a Button whose content-desc is
# "Calendar\nTab 2 of 4" and whose `selected` attribute is true for the current
# one. That is a real assertion about where the app is, which a label match is
# not.
# Is the tab called $1 the selected one?
#
# This used to grep for the "Tab 3 of 4" descriptor a Material NavigationBar puts
# on each destination, with selected="true" beside it. The bar is now the app's
# own floating card - four slots with a raised centre action, which a
# NavigationBar cannot express - so that descriptor no longer exists, and this
# check failed against a bar that was working perfectly: every Settings capture
# reported "the Settings tab could not be opened" and the run lost eight images.
#
# What the app does publish is each slot's own accessibility node: the tab's
# name, with selected="true" on the current one. That is the same fact read from
# the shape the app actually has.
tab_is_selected() {
  local label="$1"
  dump_ui || return 1
  grep -oE '<node [^>]*>' "$UI_DUMP" \
    | grep -F "content-desc=\"$label\"" \
    | grep -q 'selected="true"'
}

# Taps a tab by its own label. This is the way in; tap_tab below is the fallback.
#
# It used to be the other way round. The bar was four equal full-width columns at
# the very foot of the display, so its centres were arithmetic, and arithmetic
# does not miss - which was true, and stopped being true when the bar began to
# float clear of the edge with a raised action in the middle. The label is not
# arithmetic, and it follows the layout.
tap_tab_label() {
  local label="$1"
  local wait="${2:-3}"
  tap_label "$label" "$wait"
}

# Last resort: the centre of the column the tab would occupy if the card spanned
# the display. The card is inset by 8 at each side and the raised action takes 56
# from the middle, which leaves four slots whose centres are close enough to
# (2i+1)/8 of the width that a tap there still lands inside the right one. Its
# vertical centre is 40 above the bottom edge: an 8-pixel gap plus half of a
# 64-pixel card.
tap_tab() {
  local index="$1"
  local wait="${2:-3}"
  local x y
  # A non-numeric index is a call site bug, not a device state. Without this the
  # arithmetic treats the word as a variable name and `set -u` kills the run with
  # "Today: unbound variable", twenty minutes into the emulator boot.
  case "$index" in
    ''|*[!0-9]*)
      echo "::error::tap_tab was given a tab position of '$index', which is not a number"
      return 1
      ;;
  esac
  x=$(( SCREEN_W * (2 * index + 1) / 8 ))
  y=$(( SCREEN_H - 40 ))
  echo "  tapping tab $index at ($x,$y), by position"
  adb_run shell input tap "$x" "$y"
  sleep "$wait"
}

# Switches to a tab and proves it, retrying once, by label and then by position.
goto_tab() {
  local label="$1"
  local index="$2"
  if tap_tab_label "$label" 3 && tab_is_selected "$label"; then
    echo "  the $label tab is open"
    return 0
  fi
  echo "  the $label tab did not open by its label; trying its position"
  tap_tab "$index" 4
  if tab_is_selected "$label"; then
    echo "  the $label tab is open"
    return 0
  fi
  echo "  the $label tab could not be opened"
  return 1
}

# Puts the app on the Settings tab and scrolls it back to the top.
#
# After a BACK press the app may be anywhere: on Today, on a sub-screen, or
# out of the app entirely if the tap that was supposed to open a route did
# not. Each of the Settings captures starts by putting the app back on a
# known screen, so one missed tap cannot make every later capture fail.
go_to_settings() {
  ensure_foreground
  if ! goto_tab "Settings" 3; then
    # A pushed page draws no tab bar, so the tab cannot be found while one is
    # open - and a BACK that arrived a beat too early leaves exactly that: the
    # About page still up, and every capture after it looking for a tab that is
    # not on screen. Close whatever is open and try once more before giving up.
    echo "  no tab bar on screen: closing the open page and trying again"
    adb_run shell input keyevent KEYCODE_BACK
    sleep 2
    ensure_foreground
    if ! goto_tab "Settings" 3; then
      echo "  (the Settings tab was not reachable)"
      return 1
    fi
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
  # `adb exec-out screencap` is where a dying connection surfaces as exit 255,
  # and it used to abort the whole run on the spot. Through adb_run it
  # reconnects and tries again.
  # Written to a temporary name and renamed on success, because a retry after a
  # dropped connection would otherwise append the second attempt's bytes to the
  # first attempt's and leave a PNG that no viewer can open.
  if ! adb_run exec-out screencap -p > "$CAPTURES/$name.png.tmp"; then
    rm -f "$CAPTURES/$name.png.tmp"
    echo "::error::Could not capture $name: the screen could not be read from the device"
    exit 1
  fi
  if [ ! -s "$CAPTURES/$name.png.tmp" ]; then
    rm -f "$CAPTURES/$name.png.tmp"
    echo "::error::The capture for $name is empty"
    exit 1
  fi
  mv "$CAPTURES/$name.png.tmp" "$CAPTURES/$name.png"
  echo "  captured: $name.png"
}

# Whether the app's process is alive right now.
app_is_running() {
  if adb shell pidof "$PACKAGE" >/dev/null 2>&1; then
    return 0
  fi
  # `pidof` is toybox on newer images and absent on some older ones; the process
  # list is the answer that does not depend on which.
  adb shell "ps -A" 2>/dev/null | grep -q "$PACKAGE"
}

# Stops the run when the log says the app has died, hung, or is drawing
# Flutter's error screen.
#
# The error screen matters as much as a crash and is much easier to miss: a
# widget that throws leaves the process alive, leaves no "FATAL EXCEPTION" in
# the log, and leaves a screen with no labels on it. To a script that finds its
# way around by label, that is indistinguishable from a tap that landed in the
# wrong place, so the script spends minutes tapping at nothing and then reports
# a pile of missing captures rather than the exception that caused them. This
# check names the exception instead.
#
# Overflows are reported and do not stop the run: a RenderFlex overflow is a
# cosmetic defect the widget tests already sweep for, not a reason to throw
# away every capture after it.
check_app_health() {
  local phase="$1"
  local log="$EVIDENCE/logcat-capture.txt"
  if [ -f "$log" ]; then
    if grep -qE "FATAL EXCEPTION|ANR in $PACKAGE" "$log"; then
      echo "::error::The app crashed or stopped responding during: $phase"
      grep -E "FATAL EXCEPTION|ANR in $PACKAGE" -A 30 "$log" | tail -n 40 || true
      exit 1
    fi
    local caught overflow
    caught="$(grep -c "EXCEPTION CAUGHT BY" "$log" || true)"
    overflow="$(grep -c "overflowed by" "$log" || true)"
    if [ "${caught:-0}" -gt "${overflow:-0}" ]; then
      echo "::error::The app is drawing an error screen during: $phase"
      grep -E "EXCEPTION CAUGHT BY" -A 12 "$log" | tail -n 40 || true
      exit 1
    fi
    if [ "${overflow:-0}" -gt 0 ]; then
      echo "::warning::A widget overflowed during: $phase (see the logcat in the artifact)"
    fi
  fi
  if ! app_is_running; then
    echo "::error::$PACKAGE is not running during: $phase"
    exit 1
  fi
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
adb_run install -r "$apk"
if ! adb shell pm list packages 2>/dev/null | grep -q "$PACKAGE"; then
  echo "::error::$PACKAGE is not installed after a successful install command"
  exit 1
fi
if adb shell pm grant "$PACKAGE" android.permission.POST_NOTIFICATIONS 2>&1; then
  echo "POST_NOTIFICATIONS granted"
else
  echo "POST_NOTIFICATIONS could not be granted (expected below API 33)"
fi
echo "::endgroup::"

adb_run logcat -c || true

# The log is written from here on, in the background.
#
# It used to be dumped at the very end of the script, so the one time the script
# did not reach the end there was no log in the artifact at all: the run failed
# and took its own evidence with it. A reader of the artifact could see that the
# captures had stopped but not why.
adb logcat -v time > "$EVIDENCE/logcat-capture.txt" 2>&1 &
LOGCAT_PID=$!
trap 'kill "${LOGCAT_PID:-}" >/dev/null 2>&1 || true' EXIT

echo "::group::Launch"
read_geometry
adb_run shell am start -W -n "$ACTIVITY" >/dev/null
sleep 12
shoot "00-first-launch"
check_app_health "the first launch"
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
# Each entry is "position:label:file". The position is the tab's place in the
# bar and the label is what the bar calls it; the tap goes by the label and the
# position is only the fallback.
for entry in "0:Today:01-today-light" "1:Calendar:03-calendar-light" "2:Insights:04-insights-light" "3:Settings:05-settings-light"; do
  index="${entry%%:*}"
  rest="${entry#*:}"
  label="${rest%%:*}"
  name="${rest##*:}"
  if goto_tab "$label" "$index"; then
    shoot "$name"
  else
    echo "  nothing captured for $name: the app was not on the $label tab"
  fi
  check_app_health "the $label tab"
done

echo "::endgroup::"

echo "::group::Settings sections"
# Each entry is "label:file:expected text on the opened screen".
#
# The expected text is what proves the tap opened the screen that was
# intended. Without it, a tap that lands on the wrong control produces a
# picture of something else under the right file name.
# The label is the text on the row, which is what uiautomator can see.
#
# Two of these entries used to read "Open preferences" and "Open health
# information". No widget in the app ever renders those words: they were an
# assumption about a semantic label that was never added, so both taps failed
# on every run since the settings hub was written, and 06-preferences and
# 09-medical have never existed in docs/device-screenshots. The run reported
# it and carried on, which is exactly why nobody noticed for four releases.
for entry in \
    "Preferences:06-preferences:Preferences" \
    "Symptoms:07-symptoms:Symptoms" \
    "Care reminders:08-reminders:Care reminders" \
    "Health information:09-medical:Health information"; do
  label="${entry%%:*}"
  rest="${entry#*:}"
  name="${rest%%:*}"
  expected="${rest#*:}"
  # Best effort: if the Settings tab cannot be reached the section is reported
  # as missing at the end, which is a finding. Returning non-zero from here
  # under `set -e` would instead end the run and throw away every capture after
  # it, which is not.
  go_to_settings || true
  found=0
  # The Settings screen is long. Look for the row on the visible part first,
  # then scroll down a page at a time - from the middle of the screen, so the
  # gesture is not read as a pull-up.
  # Eight attempts, not five: with the longer swipe this is more than the height
  # of the whole Settings hub, and the row nearest the bottom of it - the health
  # information section - is the one that used to run out of budget.
  for attempt in 1 2 3 4 5 6 7 8; do
    if tap_row "$label" 3; then
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
      # Only leave the page that was actually opened. Pressing BACK on the hub
      # itself leaves the *app*, and the run then spends the next section
      # driving the launcher: that is the "(the app was not in the foreground;
      # bringing it back)" line the last run printed, and the twelve failed
      # searches that came after it.
      adb_run shell input keyevent KEYCODE_BACK
      sleep 1
    else
      echo "  the '$label' row was tapped but '$expected' is not on screen;"
      echo "  the tap landed somewhere else, so nothing was captured."
    fi
  else
    echo "  the '$label' section was not found"
  fi
done
echo "::endgroup::"

echo "::group::About block"
go_to_settings || true
found=0
# Two taps, not one.
#
# This block used to scroll the Settings hub looking for the word "Developer",
# which is not on the hub at all: it is a row on the page the "About" row opens.
# So the search could never succeed, whatever the scroll budget, and 10-about
# has never existed in docs/device-screenshots. The row is tapped first, and the
# word is only looked for once the page behind it is open.
for attempt in 1 2 3 4 5 6 7 8 9 10 11 12; do
  if tap_row "About" 3; then
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
    check_app_health "the About page"
  else
    echo "  the About row was tapped but its page did not open, so nothing was captured."
  fi
  # Back to the hub. The next block starts by looking for a tab, and a tab bar
  # is not drawn on a pushed page, so a missing BACK here breaks the capture
  # that follows it.
  adb_run shell input keyevent KEYCODE_BACK
  sleep 1
  ensure_foreground
else
  echo "  the About row was not found"
fi
echo "::endgroup::"

echo "::group::Phase guide"
# The newest screen in the app, and the only one a partner reads for its own
# sake: what each phase is like, what to do, what to skip, what to put in front
# of her. It is one row down in Settings, so it needs no scroll to reach - but
# the row is looked up by its wording, and the wording is the point of the
# screen, so a rename that empties this capture is a capture that says so.
go_to_settings || true
found=0
for attempt in 1 2 3 4 5 6 7 8; do
  if tap_row "What helps, by phase" 3; then
    found=1
    break
  fi
  scroll_down
  dump_ui || true
done
if [ "$found" = 1 ]; then
  dump_ui || true
  if shows "In the kitchen"; then
    shoot "17-phase-guide"
    check_app_health "the phase guide"
  else
    echo "  the row was tapped but the guide did not open, so nothing was captured."
  fi
  adb_run shell input keyevent KEYCODE_BACK
  sleep 1
  ensure_foreground
else
  echo "  the phase guide row was not found"
fi
echo "::endgroup::"

echo "::group::Location"
# The district picker. It replaced two typed decimals, so the capture is the
# proof that a household outside Dhaka can now set a place in two taps.
go_to_settings || true
found=0
for attempt in 1 2 3 4 5 6 7 8 9 10; do
  if tap_row "Location" 2; then
    found=1
    break
  fi
  scroll_down
  dump_ui || true
done
if [ "$found" = 1 ]; then
  dump_ui || true
  if shows "District"; then
    shoot "18-location"
    check_app_health "the location page"
  else
    echo "  the Location row was tapped but the page did not open, so nothing was captured."
  fi
  adb_run shell input keyevent KEYCODE_BACK
  sleep 1
  ensure_foreground
else
  echo "  the Location row was not found"
fi
echo "::endgroup::"

echo "::group::Privacy"
go_to_settings || true
found=0
# The Privacy block sits above the About block, so it takes fewer scrolls than
# the About block does - but the same generous budget costs nothing when the
# row is found early, and it removes the guesswork from how far down the
# screen a given section happens to be.
for attempt in 1 2 3 4 5 6 7 8 9 10 11 12; do
  if tap_row "Privacy and data" 2; then
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
    check_app_health "the privacy page"
  else
    echo "  the Privacy section is not on screen, so it was not captured."
  fi
  # The same BACK as the About block, and for the same reason: this page is now
  # reached (it used to sit below the reach of a 250-pixel swipe), and the
  # day-detail capture that follows starts by tapping the Calendar tab, which a
  # pushed page does not draw.
  adb_run shell input keyevent KEYCODE_BACK
  sleep 1
  ensure_foreground
else
  echo "  the Privacy section was not found"
fi
echo "::endgroup::"

echo "::group::Day detail sheet"
goto_tab "Calendar" 1 || true
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
  adb_run shell input keyevent KEYCODE_BACK
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
adb_run shell am start -W -n "$ACTIVITY" >/dev/null 2>&1 || true
sleep 8
ensure_foreground
# Dark mode is a configuration change, a force-stop and a cold start on a
# software renderer: the least forgiving thing this script does, and the point
# at which a run that has been quietly failing stops being quiet.
check_app_health "the relaunch into dark mode"

# The same four tabs as the light run, and the same verification. A dark
# capture that is a copy of the one before it is worse than no capture: it says
# the screen was checked when it was not.
for entry in "0:Today:13-today-dark" "1:Calendar:14-calendar-dark" "2:Insights:15-insights-dark" "3:Settings:16-settings-dark"; do
  index="${entry%%:*}"
  rest="${entry#*:}"
  label="${rest%%:*}"
  name="${rest##*:}"
  if goto_tab "$label" "$index"; then
    shoot "$name"
  else
    echo "  nothing captured for $name: the app was not on the $label tab"
  fi
  check_app_health "the $label tab in dark mode"
done

adb shell "cmd uimode night no" >/dev/null 2>&1 || true
sleep 3
echo "::endgroup::"

echo "::group::Notification icon"
# The notification's small icon is drawn by the system in the status bar, so
# nothing inside the app shows it. It is captured and magnified here, and
# the numbered capture is committed with the rest of the evidence.
EVIDENCE_DIR="$EVIDENCE" tool/android_ui/notification_icon.sh || true
echo "::endgroup::"

# Stop the live log before reading it, so the last lines are flushed.
kill "${LOGCAT_PID:-}" >/dev/null 2>&1 || true
sleep 1
check_app_health "the end of the run"

# A run that produced most of the pictures used to be reported as a success.
# The last green run before 2.2.0 committed twelve captures and had been
# silently missing four of them for four releases, because a capture that never
# happened was only ever a sentence in a log. Green now means the whole set.
EXPECTED="00-first-launch 01-today-light 03-calendar-light 04-insights-light
05-settings-light 06-preferences 07-symptoms 08-reminders 09-medical 10-about
11-privacy 12-day-detail 13-today-dark 14-calendar-dark 15-insights-dark
16-settings-dark 17-phase-guide 18-location"
missing=""
for name in $EXPECTED; do
  if [ ! -s "$CAPTURES/$name.png" ]; then
    missing="$missing $name"
  fi
done
if [ -n "$missing" ]; then
  echo "::error::The capture set is incomplete. Missing:$missing"
  echo "A missing capture means a row was not found or a screen did not open."
  echo "The script log above names the tap; the logcat in the artifact names the cause."
  exit 1
fi

echo "No crash, no error screen, and all 18 captures were produced."
echo "Device captures written to $CAPTURES."
