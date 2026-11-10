#!/usr/bin/env bash
#
# First-launch check for the compiled APK on an emulator.
#
# This is a script file rather than an inline block in the workflow because the
# emulator action runs its script with /usr/bin/sh, which does not accept the
# bash-style line continuations used in an inline block. Keeping the flow in a
# file also means it can be read, reviewed and re-run on its own.
#
# What it does:
#   * installs the artifact that the build job produced (nothing is rebuilt);
#   * grants POST_NOTIFICATIONS, which is a runtime permission on API 33+ and
#     without which a reminder can be posted and never shown;
#   * launches the app, waits, and records the first frame;
#   * records the system-bar geometry, so an edge-to-edge regression is
#     visible in the log rather than only in a picture;
#   * fails if the log shows a crash or an ANR for this package.
#
# Everything it produces is uploaded as evidence, pass or fail.

set -euo pipefail

PACKAGE="com.mahimmazidul.elara"
ACTIVITY="com.mahimmazidul.elara/.MainActivity"
EVIDENCE="${EVIDENCE_DIR:-evidence}"

mkdir -p "$EVIDENCE"

adb shell getprop ro.build.version.release | sed 's/^/Android release: /'
adb shell getprop ro.build.version.sdk | sed 's/^/Android SDK: /'

echo "::group::Install the artifact"
apk="$(tool/android_ui/find_apk.sh)"
echo "Installing $apk"
adb install -r "$apk"
adb shell pm list packages | grep "$PACKAGE"
echo "::endgroup::"

# A failure here is not fatal on its own (the permission does not exist before
# API 33), but on API 33+ its absence would make every later notification
# check meaningless, so it is reported either way.
echo "::group::Notification permission"
if adb shell pm grant "$PACKAGE" android.permission.POST_NOTIFICATIONS 2>&1; then
  echo "POST_NOTIFICATIONS granted"
else
  echo "POST_NOTIFICATIONS could not be granted (expected on images below API 33)"
fi
echo "::endgroup::"

adb logcat -c

echo "::group::First launch"
adb shell am start -W -n "$ACTIVITY"
sleep 12
adb exec-out screencap -p > "$EVIDENCE/01-first-launch.png"
adb shell dumpsys activity activities > "$EVIDENCE/activity-after-launch.txt" || true
grep -E "mResumedActivity|ResumedActivity" "$EVIDENCE/activity-after-launch.txt" | head -3 || true
echo "::endgroup::"

# The window's insets and the size of the app's own frame. When the app draws
# edge to edge, the app's frame covers the whole display and the status bar
# sits over it; when it does not, the frame starts below the status bar and
# the difference is exactly the grey band this project set out to remove.
echo "::group::Window geometry"
adb shell dumpsys window windows > "$EVIDENCE/window-geometry.txt" || true
adb shell wm size | tee "$EVIDENCE/display-size.txt" || true
adb shell wm density | tee "$EVIDENCE/display-density.txt" || true
python3 - "$EVIDENCE" <<'PY' || true
import re
import sys

path = sys.argv[1] + '/window-geometry.txt'
try:
    text = open(path, encoding='utf-8', errors='replace').read()
except OSError:
    sys.exit(0)

# The frame of the focused window, and the insets the system reports for it.
m = re.search(r'Window\{[^}]*com\.mahimmazidul\.elara[^}]*\}(.*?)(?=\n\s*Window\{|\Z)',
              text, re.S)
block = m.group(1) if m else text
frames = re.findall(r'Frames: containing=.*?frame=\{([^\}]*)\}', block)
if frames:
    print('App frame (edge-to-edge means it starts at 0,0):', frames[0].strip())
for key in ('mStatusBarInsets', 'mNavigationBarInsets', 'mDisplayFrame', 'mParentFrame'):
    for line in block.splitlines():
        if key in line:
            print(key + ':', line.strip())
            break
PY
echo "::endgroup::"

# Whether the status bar area is actually the app's own page colour.
#
# The first Android 13 render showed a detached grey status bar above the app
# even though the window was already drawing edge to edge. A picture of that
# is easy to miss and easy to argue about, so the top strip of the screenshot
# is sampled and compared against the page colour: if the strip is grey rather
# than the page's off-white (or its dark grey), the app has drawn a separate
# band and the edge-to-edge work has regressed.
#
# The check is reported, not fatal: the colour of the strip is only meaningful
# if the app is on its light or dark page, and the theme follows the emulator's
# setting. A regression is caught by the same check on the strip of the very
# same screenshot that a human looks at.
echo "::group::Status bar colour"
python3 - "$EVIDENCE" <<'PY' || true
import struct
import sys
import zlib


def read_png(path):
    """Minimal PNG reader for 8-bit RGB/RGBA images."""
    with open(path, 'rb') as handle:
        data = handle.read()
    if data[:8] != b'\x89PNG\r\n\x1a\n':
        raise ValueError('not a PNG')
    pos = 8
    width = height = None
    bit_depth = colour_type = None
    idat = bytearray()
    while pos < len(data):
        length = struct.unpack('>I', data[pos:pos + 4])[0]
        kind = data[pos + 4:pos + 8]
        body = data[pos + 8:pos + 8 + length]
        pos += 12 + length
        if kind == b'IHDR':
            width, height, bit_depth, colour_type = struct.unpack('>IIBB', body[:10])
        elif kind == b'IDAT':
            idat += body
        elif kind == b'IEND':
            break
    if bit_depth != 8 or colour_type not in (2, 6):
        raise ValueError('unsupported PNG: depth=%s colour=%s' % (bit_depth, colour_type))
    channels = 3 if colour_type == 2 else 4
    raw = zlib.decompress(bytes(idat))
    stride = width * channels
    rows = []
    previous = bytearray(stride)
    pos = 0
    for _ in range(height):
        filter_type = raw[pos]
        pos += 1
        line = bytearray(raw[pos:pos + stride])
        pos += stride
        for i in range(stride):
            left = line[i - channels] if i >= channels else 0
            up = previous[i]
            upleft = previous[i - channels] if i >= channels else 0
            if filter_type == 1:
                line[i] = (line[i] + left) & 0xFF
            elif filter_type == 2:
                line[i] = (line[i] + up) & 0xFF
            elif filter_type == 3:
                line[i] = (line[i] + (left + up) // 2) & 0xFF
            elif filter_type == 4:
                p = left + up - upleft
                pa, pb, pc = abs(p - left), abs(p - up), abs(p - upleft)
                pred = left if (pa <= pb and pa <= pc) else (up if pb <= pc else upleft)
                line[i] = (line[i] + pred) & 0xFF
        rows.append(line)
        previous = line
    return width, height, channels, rows


def average(rows, channels, y_from, y_to, x_from, x_to):
    total = [0, 0, 0]
    count = 0
    for y in range(y_from, y_to):
        line = rows[y]
        for x in range(x_from, x_to):
            base = x * channels
            total[0] += line[base]
            total[1] += line[base + 1]
            total[2] += line[base + 2]
            count += 1
    if not count:
        return None
    return tuple(c / count for c in total)


try:
    width, height, channels, rows = read_png(sys.argv[1] + '/01-first-launch.png')
except Exception as error:  # noqa: BLE001 - the check must never fail the run
    print('Could not sample the screenshot: %s' % error)
    sys.exit(0)

# The status bar is the top 4% of the display. The icons are excluded by
# sampling only the middle band of the strip, so a clock or a battery icon
# does not drag the average away from the background.
strip_height = max(1, int(height * 0.04))
y_from, y_to = 1, strip_height - 1
x_from, x_to = int(width * 0.35), int(width * 0.65)

bar = average(rows, channels, y_from, y_to, x_from, x_to)
if bar is None:
    sys.exit(0)

# The page background just below the strip, for comparison.
page = average(rows, channels, strip_height + 2, min(height, strip_height + 12),
               x_from, x_to)

print('Status bar strip average RGB: %.1f %.1f %.1f' % bar)
if page:
    print('Page just below the strip RGB:  %.1f %.1f %.1f' % page)
    difference = max(abs(a - b) for a, b in zip(bar, page))
    print('Difference: %.1f' % difference)
    if difference > 12:
        print('VERDICT: the status bar strip differs from the page by more than 12')
        print('          per channel — the app is drawing a separate band there.')
    else:
        print('VERDICT: the status bar strip matches the page colour — the app')
        print('          draws edge to edge.')
else:
    print('VERDICT: could not sample the page below the strip.')
PY
echo "::endgroup::"

# A probe, not a smoke test: it answers whether Flutter's semantics tree is
# visible to external automation at all, which decides how the navigation flows
# are driven in the next stage.
echo "::group::UI tree probe"
if adb shell uiautomator dump /sdcard/ui-first-launch.xml >/dev/null 2>&1; then
  adb pull /sdcard/ui-first-launch.xml "$EVIDENCE/ui-first-launch.xml" >/dev/null
  head -c 4000 "$EVIDENCE/ui-first-launch.xml" || true
else
  echo "uiautomator produced no dump"
fi
echo "::endgroup::"

adb logcat -d -v time > "$EVIDENCE/logcat-first-launch.txt" || true

if grep -qE "FATAL EXCEPTION|ANR in $PACKAGE" "$EVIDENCE/logcat-first-launch.txt"; then
  echo "::error::The app crashed or ANR'd on first launch."
  grep -E "FATAL EXCEPTION" -A 30 "$EVIDENCE/logcat-first-launch.txt" || true
  exit 1
fi

echo "No crash or ANR in the first-launch log."
echo "First-launch evidence written to $EVIDENCE."
