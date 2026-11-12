#!/usr/bin/env bash
#
# Proves that the notification's small icon actually draws in the status bar.
#
# The small icon is the one thing about a notification that is easiest to get
# wrong and hardest to notice from inside the app: it is drawn by the
# system, from the alpha channel of a drawable, tinted with the system's own
# colour, in a 24 dp box in the status bar. If the drawable is wrong, the
# app still works, the notification still arrives, and the only symptom is a
# blank or indistinct mark next to the clock.
#
# So it has to be looked at. This script:
#
#   * posts a notification using the app's own icon resource, through the
#     system's own `cmd notification post` command;
#   * waits for it to appear, and fails loudly if it did not;
#   * captures the status bar, cropped to the top of the screen, so the mark
#     is large enough to judge;
#   * and checks that the notification really is in the status bar's dump,
#     so a capture that happens to show no notification cannot be mistaken
#     for a good one.
#
# The syntax matters and was got wrong once:
#
#     cmd notification post [flags] <tag> <text>
#
# with `-t` for the title and `-i` for the icon. The icon is an *iconspec*,
# and to reach a drawable inside another app's package it has to be given as
# `@com.mahimmazidul.elara:drawable/ic_stat_elara`. Passing the bare name
# silently posts a notification with the system's default icon, which is
# exactly the kind of false negative this script exists to catch.

set -euo pipefail

PACKAGE="com.mahimmazidul.elara"
ICON="ic_stat_elara"
EVIDENCE="${EVIDENCE_DIR:-evidence}"

mkdir -p "$EVIDENCE"

echo "== Posting a notification with the app's own icon =="

# The notification has to be posted **by the app**, and this is how.
#
# The system's own `cmd notification post` command cannot do it: it resolves
# a drawable from its own package, not another app's, so passing
# `@com.mahimmazidul.elara:drawable/ic_stat_elara` fails with "invalid
# icon", and passing no icon at all posts a notification with the system's
# default - which looks plausible in a screenshot and proves nothing.
#
# The app has a debug-only method channel for exactly this. The handler is
# registered only when the build is a debug build, so there is no way to
# reach it in a release build.
#
# `am start` is used rather than `adb shell am broadcast`, because a
# broadcast would need a receiver registered in the manifest, and the
# channel is reachable from the activity that is already running.
# The intent reaches the activity - whose launch mode is singleTop, so the
# intent is delivered to the running instance rather than starting a second
# one - and the activity passes the request across the method channel into
# Dart, where the app's own notification service posts it.
post_output="$(adb shell am start -W -n "${PACKAGE}/.MainActivity" \
  --es elara_verification showTestNotification 2>&1 || true)"

echo "  the system said: ${post_output:-<nothing>}"

if echo "$post_output" | grep -qiE "Error|Exception|Unable to resolve"; then
  echo "  ::error::the app could not be asked to post the notification:"
  echo "$post_output" | sed 's/^/    /'
  exit 1
fi

# The notification has to have been drawn before the screen is captured.
sleep 4

# The app prints to logcat if the request failed. Reading it here turns a
# silent failure into a readable one - without it, a notification that was
# never posted looks exactly like a notification that was posted and then
# dismissed.
# The app prints a line for each step: that the request arrived, and that it
# was carried out. Both are read here, so that a request which never
# reached Dart is distinguishable from one that reached Dart and failed.
logcat_lines="$(adb logcat -d -s flutter:I Elara:I 2>/dev/null | grep -i 'Elara: the verification action' || true)"
if [ -n "$logcat_lines" ]; then
  echo "  the app said:"
  echo "$logcat_lines" | sed 's/^/    /'
fi

if echo "$logcat_lines" | grep -qi "failed"; then
  echo "  ::error::the app reported a failure."
  echo "NOTIFICATION_ICON_CHECK=failed" > "$EVIDENCE/notification-icon-check.txt"
  exit 1
fi

if ! echo "$logcat_lines" | grep -qi "was carried out"; then
  echo "  ::error::the request never reached the app."
  echo "  The capture below would prove nothing, so it is not taken."
  echo "NOTIFICATION_ICON_CHECK=not-reached" > "$EVIDENCE/notification-icon-check.txt"
  exit 1
fi

echo "== Checking that the notification is there =="
# The status bar's own dump lists the notifications it is showing. This is
# checked *before* the capture, so that a missing notification is reported as
# a failure rather than as a picture of an empty status bar.
dump="$(adb shell dumpsys notification --noredact 2>/dev/null || true)"
if echo "$dump" | grep -q "Notification icon check"; then
  echo "  the notification is present in the status bar"
else
  # A warning, not an error: the caller runs this at the end of the
  # capture with `|| true`, so nothing downstream fails on it. An
  # ::error:: annotation that no step acts on paints a green run red and
  # teaches everyone to ignore red, which is how a real failure gets
  # missed later.
  echo "  ::warning::no Elara notification is in the status bar."
  echo "  The capture below would prove nothing, so it is not taken."
  echo "NOTIFICATION_ICON_CHECK=not-found" > "$EVIDENCE/notification-icon-check.txt"
  exit 1
fi

echo "== Capturing the status bar =="

# The full screen first: it is the evidence, and it shows the notification
# in the context of the system bars around it.
adb exec-out screencap -p > "$EVIDENCE/40-notification-status-bar.png"
echo "  captured: 40-notification-status-bar.png"

# Then a crop of the top strip, where the small icon lives, magnified so the
# mark can actually be judged. `sips` is not on a runner; the crop is done
# with Python and the standard library only.
python3 - "$EVIDENCE/40-notification-status-bar.png" \
          "$EVIDENCE/41-notification-icon.png" <<'PY'
import struct
import sys
import zlib

src, dst = sys.argv[1], sys.argv[2]


def read_png(path):
    with open(path, 'rb') as f:
        data = f.read()
    assert data[:8] == b'\x89PNG\r\n\x1a\n', 'not a PNG'
    pos = 8
    width = height = None
    bit_depth = colour = None
    idat = b''
    while pos < len(data):
        length = struct.unpack('>I', data[pos:pos + 4])[0]
        kind = data[pos + 4:pos + 8]
        body = data[pos + 8:pos + 8 + length]
        if kind == b'IHDR':
            width, height, bit_depth, colour = struct.unpack('>IIBB', body[:10])
        elif kind == b'IDAT':
            idat += body
        pos += 12 + length
    assert bit_depth == 8, f'unsupported bit depth {bit_depth}'
    channels = {0: 1, 2: 3, 4: 2, 6: 4}[colour]
    raw = zlib.decompress(idat)
    stride = width * channels
    out = bytearray()
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
            upper_left = previous[i - channels] if i >= channels else 0
            if filter_type == 1:
                line[i] = (line[i] + left) & 0xFF
            elif filter_type == 2:
                line[i] = (line[i] + up) & 0xFF
            elif filter_type == 3:
                line[i] = (line[i] + (left + up) // 2) & 0xFF
            elif filter_type == 4:
                p = left + up - upper_left
                pa, pb, pc = abs(p - left), abs(p - up), abs(p - upper_left)
                predictor = left if (pa <= pb and pa <= pc) else (up if pb <= pc else upper_left)
                line[i] = (line[i] + predictor) & 0xFF
        out += line
        previous = line
    return width, height, channels, bytes(out)


def write_png(path, width, height, channels, pixels):
    raw = bytearray()
    stride = width * channels
    for y in range(height):
        raw.append(0)
        raw += pixels[y * stride:(y + 1) * stride]

    def chunk(kind, body):
        return (struct.pack('>I', len(body)) + kind + body +
                struct.pack('>I', zlib.crc32(kind + body) & 0xFFFFFFFF))

    header = struct.pack('>IIBBBBB', width, height, 8,
                          {1: 0, 2: 4, 3: 2, 4: 6}[channels], 0, 0, 0)
    with open(path, 'wb') as f:
        f.write(b'\x89PNG\r\n\x1a\n')
        f.write(chunk(b'IHDR', header))
        f.write(chunk(b'IDAT', zlib.compress(bytes(raw), 6)))
        f.write(chunk(b'IEND', b''))


width, height, channels, pixels = read_png(src)

# The status bar is the top of the screen. Take a strip a little taller than
# it, so the mark and the clock beside it are both in frame.
strip = min(height, max(48, height // 12))
crop = bytearray()
for y in range(strip):
    crop += pixels[y * width * channels:(y + 1) * width * channels]

# Magnify 3x, nearest neighbour: the mark is small and the point is to see
# its shape, not its anti-aliasing.
scale = 3
big_w, big_h = width * scale, strip * scale
big = bytearray(big_w * big_h * channels)
for y in range(big_h):
    src_row = (y // scale) * width * channels
    row = bytearray()
    for x in range(width):
        pixel = pixels[src_row + x * channels:src_row + (x + 1) * channels]
        row += pixel * scale
    big[y * big_w * channels:(y + 1) * big_w * channels] = row

write_png(dst, big_w, big_h, channels, bytes(big))
print(f'  cropped and magnified: 41-notification-icon.png '
      f'({big_w}x{big_h})')
PY

echo "NOTIFICATION_ICON_CHECK=posted" > "$EVIDENCE/notification-icon-check.txt"

echo "Notification icon evidence written to $EVIDENCE."
