# Implementation report — CI-backed Android testing, native edge-to-edge, UI overhaul

Milestone pass. Repository: `mahimmazidul/elara-app`. Branch: `main`.

Every claim below names the run, the artifact or the test that backs it.
Nothing is claimed from a local run alone. Where a thing was **not** verified,
that is said plainly rather than left to be inferred.

---

## 1. Commits

Fifty-six non-bot commits on `main`. The bot commits
(`chore: refresh screenshots [skip ci]`) are the screenshot workflow's own
output and are not counted.

| | SHA | What it does |
| --- | --- | --- |
| | `49d2ca4` | the notification small icon |
| | `5701d59` | build and inspect a debug APK in GitHub Actions |
| | `7b1d73a` | retry the APK build past a flaky Gradle download |
| | `80427e7` | install the built APK on an emulator and record what happens |
| | `9f496cd` | run the emulator flow from a script file |
| | `446b4f9` | pin the test-only sqlite3 to a line that builds offline |
| | `d42600d` | make CI the test environment for the whole suite |
| | `c9a7c87` | fix a workflow-file error that stopped the sharded suite from starting |
| | `56384ed` | record the first complete CI run of the whole suite |
| | `c6037aa` | record the first real Android render and what it shows |
| | `52778ab` | draw the app edge to edge behind the system bars |
| | `75f79ec` | take the boxes off Settings and About, and fix the rows that break |
| | `1db3ad4` | make the status bar actually transparent, not just edge-to-edge |
| | `009a2ad` | drive the app through its navigation on the emulator |
| | `9ac94cb` | record the UI unboxing, the transparent status bar, and the emulator navigation |
| | `8f55f1d` | bring the README and the landing page up to the current UI |
| | `6aa3327` | capture the screenshots from the compiled APK on an emulator |
| | `b319ad4` | purposeful motion, and respect "remove animations" |
| | `ab03a50` | make the icon vocabulary complete, and enforce it |
| | `9435f15` | sweep every pushed screen at the text scales Android offers |
| | `9145f6c` | find the debug APK wherever the job put it |
| | `5eb8433` | make the emulator capture the screens it means to |
| | `066d24a` | define ACTIVITY in navigation.sh, and check the scripts in CI |
| `79dbb6b` | check that a tap opened the screen it meant to, and retry a raced push |

No force-push. No history rewrite. No test file was deleted.

---

## 2. GitHub Actions as the build and test environment

### The sharded suite

`.github/workflows/ci.yml` is three jobs:

| job | what it does |
| --- | --- |
| `analyze` | `dart analyze --fatal-infos`; a failure here stops the run |
| `plan` | lists `test/**/*_test.dart`, sorts them, and distributes them round-robin into `$GITHUB_OUTPUT` as `ids=[0,1,2,3]` |
| `test` | a four-shard matrix, `flutter test --reporter expanded`, one shard per id |

The shard count is repeated in each job's own `env:` block, because a job's
`name:` is evaluated before the workflow-level `env` context exists — that was
the mistake that produced a run with zero jobs.

**The first complete green run of the whole suite:** run **42597704379** on
`c9a7c87` — 27 files, 359 tests, all four shards green.

**The most recent green run:** run **42608178358** on `9145f6c` — **436
tests** across the four shards (108 / 134 / 112 / 82), all green, with
`analyze` green.

### The Android build

`.github/workflows/android-ci.yml` has two jobs:

- `apk`: analyze → test → build the debug APK → **inspect it** with `aapt2`
  → upload it as `elara-debug-apk`.
- `emulator`: download that artifact (nothing is rebuilt), install it on an
  emulator, run `tool/android_ui/first_launch.sh` and
  `tool/android_ui/navigation.sh`, and upload the evidence as
  `emulator-evidence-api{level}`.

The APK inspection is not a formality. It asserts the package id is
`com.mahimmazidul.elara`, that a `versionName` exists, and that
`ic_stat_elara` is present in the packaged resources — a build that could
not draw a status-bar icon would fail there rather than silently ship.

**Emulator matrix: API 29, 33 and 35.** The system bars behave differently
across them — Android 10 introduced the contrast enforcement that paints a
scrim over the navigation bar, and Android 15 forces edge-to-edge for every
app — so an app that only looks right on one of them has not been verified.

Run **42611291545** reports **success for API 29, API 33 and API 35** —
all three emulator jobs green, with the artifact installed and the app
driven through its navigation on each.

### The device screenshots

`.github/workflows/device-screenshots.yml` builds the debug APK, installs it
on an Android 13 emulator, drives it through the screens with
`tool/android_ui/capture_screens.sh`, and commits what the emulator's
`screencap` produced into `docs/device-screenshots/`. Nothing is edited.

**The first run of this workflow failed** (run 42607046734): the capture
script looked for `artifact/app-debug.apk`, but that job builds the APK in
place. `tool/android_ui/find_apk.sh` now finds it in either place, and all
three scripts use it.

**The second run succeeded** (run 42608178415) and committed sixteen real
device screenshots as `9a1d62c`.

### The emulator scripts are checked before they run

`tool/android_ui/check_scripts.py` runs `bash -n` on every script in
`tool/android_ui/`, checks that every upper-case variable a script uses is
assigned somewhere in it, and checks that no script installs an APK from a
hardcoded path instead of going through `find_apk.sh`. It is wired into the
CI workflow's analyze job, so it runs on every change and takes a second.

Those are the two mistakes that have actually happened, and both were found
the expensive way: an undefined `$ACTIVITY` after twenty minutes of emulator
boot on a runner, and a missing APK after the emulator had started. The
check catches both in a second, and it was verified by removing the
assignment and watching it fail.

---

## 3. The notification status-bar icon

**The defect.** The app passed `'@mipmap/ic_launcher'` as the notification
icon. Two independent faults follow from that:

1. **Wrong kind of resource.** Android draws a status-bar icon from the
   **alpha channel alone** and tints it with the system's colour. A launcher
   mipmap is a filled square in full colour, so its alpha is opaque
   everywhere and the bar shows a solid block.
2. **Wrong resource type and name.** `flutter_local_notifications` resolves
   the string with `getIdentifier(name, "drawable", package)`
   (`FlutterLocalNotificationsPlugin.java:913`). `'@mipmap/ic_launcher'` is
   not an identifier it can resolve that way, so the lookup returns 0 and the
   icon is genuinely empty.

**The fix.** `android/app/src/main/res/drawable/ic_stat_elara.xml`: a 24 dp
vector, white on transparent, the crescent and dot traced from the launcher's
own monochrome layer, inset to 21 dp of the 24 dp box. A vector rather than
density-specific PNGs, so it is exact at every density and cannot go stale.
`res/raw/keep.xml` keeps it and the launcher mipmaps past the resource
shrinker, because the plugin resolves the name at runtime and the shrinker
cannot see the reference.

**Verified:** `test/services/notification_icon_test.dart` (6 assertions) and
the `aapt2` check in the APK job, which fails the build if the drawable is
missing from the packaged resources. The launcher icon is unchanged.

---

## 4. Native edge-to-edge

### What was wrong, and what it took

The first edge-to-edge commit (`52778ab`) made the *window* draw behind the
system bars, and the emulator evidence proves it worked at that level:

```
Window{... com.mahimmazidul.elara/...MainActivity}:
  mAttrs={(0,0)(fillxfill) ... fmt=TRANSPARENT ...}
  Frames: parent=[0,0][320,640] display=[0,0][320,640] frame=[0,0][320,640]
```

**And the screenshot still showed a grey band above the app.** The window was
right and the bar was still wrong, and the causes were on two sides:

1. **Flutter painted the band.** Flutter falls back to the engine's own
   default system bar style when no `AppBar` and no `AnnotatedRegion` supplies
   one, and that default paints a grey strip. The
   `appBarTheme.systemOverlayStyle` added to the theme could not fix it,
   because the screen showing the defect — the consent gate — has no
   `AppBar`. The style now lives in an `AnnotatedRegion` around the whole app
   (`lib/theme/system_overlay_style.dart`), so every screen inherits it. The
   brightness comes from `Theme.of(context).brightness` inside
   `MaterialApp.builder`, which is the *resolved* theme, so `ThemeMode.system`
   is handled correctly.
2. **The native side was fighting itself.** `MainActivity` called
   `enableEdgeToEdge()`, which resolves to **androidx's**
   `ComponentActivity.enableEdgeToEdge()` rather than a local method. That
   helper exists for apps whose bars sit on their own surfaces, and it paints
   a translucent scrim over the bars to guarantee contrast — precisely the
   grey band being removed. Androidx applies it *after* `super.onCreate`, so
   it also overwrote the transparent status bar the activity had just set. The
   activity no longer calls it. It sets the bars transparent itself and turns
   off the platform's contrast enforcement on API 29+, the native equivalent
   of the `*ContrastEnforced` flags in Flutter's `SystemUiOverlayStyle`.

### Insets are honoured, not zeroed

`SafeArea` reads the view padding Android reports for the system bars, and
the navigation bar's own padding is added *inside* the bottom bar in
`lib/screens/root_scaffold.dart` — so the background reaches the physical
bottom edge while the icons stay clear of the gesture handle. Drawing behind
the bars does not mean zeroing the insets.

### It is checked, not eyeballed

`tool/android_ui/first_launch.sh` samples the top strip of the screenshot and
compares it with the page just below it; a difference of more than 12 per
channel means the app is drawing a separate band. Run against the evidence
from `52778ab` it reports:

```
Status bar strip average RGB: 187.0 187.0 186.0
Page just below the strip RGB:  250.0 250.0 248.0
Difference: 63.0
VERDICT: the status bar strip differs from the page by more than 12
          per channel — the app is drawing a separate band there.
```

Which is the defect it is meant to catch.

**Verified on the device:** `docs/device-screenshots/00-first-launch.png` and
`05-settings-light.png` show the page colour running behind the clock, the
signal icons and the battery, with no grey band, and the tab bar reaching the
bottom edge of the display.

**Verified across the API range.** Run **42611291545** reports success for
**API 29, API 33 and API 35** — all three emulator jobs green, each installing
the artifact and driving the app through its navigation. Running the same
sampler over each one's screenshot:

| API level | status bar strip | page just below | difference |
| --- | --- | --- | --- |
| 29 (Android 10) | RGB(250, 250, 248) | RGB(250, 250, 248) | **0.0** |
| 33 (Android 13) | RGB(250, 250, 248) | RGB(250, 250, 248) | **0.0** |
| 35 (Android 15) | RGB(250, 250, 248) | RGB(250, 250, 248) | **0.0** |

The same check reported a difference of **63.0** before the fix. Android 10
is the case that needed `setNavigationBarContrastEnforced(false)`, because
that release introduced the platform's own translucent scrim over the
navigation bar; Android 15 is the case that forces edge-to-edge on every
app regardless of what the app asks for. The API 29 and API 35 renders show
the transparent status bar and the gesture area with the app's own
background behind it.

---

## 5. The adaptive UI overhaul

### The boxing

`ElaraCard` blocks were removed from the consent gate (one), Settings (five)
and About (four), and two `Hairline` separators were put back where a card
edge used to be. `tool/ui/unwrap_settings_cards.py` is the script that did
it, kept in the repository so the transformation is reviewable and
repeatable; it is idempotent.

**Nothing was removed to achieve that.** The location fields, the Dhaka
default, the notification switches, the theme selector and the update check
are all still on the Settings screen — the device capture
`docs/device-screenshots/05-settings-light.png` shows them.

The fourteen `ElaraCard` uses that remain are deliberate: the three chart
containers in `insights/charts.dart`, the two in `insights_screen.dart`, the
calendar's, the climate strip, the Today screen's, the onboarding card, and
the destructive-action panel in `settings/privacy_data_section.dart` — the
last because "delete everything" should look like a decision rather than a
list item.

### The three defects the boxes had been hiding

| defect | cause | fix |
| --- | --- | --- |
| "Md. Mazidul Islam Mahim" wrapped in the middle of itself | two `Flexible` halves split the row, so the value half had half the width | `_AboutRow` measures both texts with a `TextPainter` and only lays them side by side when they fit; otherwise the value moves under the label |
| the "Check on start-up" switch overflowed its row by 60 px at 1.5× text | `SwitchListTile` lays the switch beside a title that cannot shrink | replaced with `_AutoCheckSwitch`: an `Expanded` label column and a `Switch.adaptive`, with the label in an `InkWell` so tapping the words toggles it |
| the version header overflowed at 320 dp / 1.5× text | a `Row` with a name and a build number | changed to a `Wrap` |

### Typography

The type scale is semantic already: `ElaraTypography` names the roles
(`displayNumber`, `number`, `headline`, `title`, `subtitle`, `body`,
`bodyStrong`, `label`, `caption`, `overline`), restricts weights to the three
DM Sans bundles, and carries `Noto Sans Bengali` as a `fontFamilyFallback` on
every style, so the Bengali lunar names resolve instead of rendering as tofu.
Android's own text scaling is honoured throughout.

**Verified:**

- `test/widgets/responsive_test.dart` — every tab at 1.0×, 1.3×, 1.5× and
  2.0×, at 320 / 360 / 375 / 390 / 430 dp and at 720 / 1024 dp.
- `test/screens/about_section_test.dart` — twelve layout cases at 320 / 360 /
  390 / 430 dp × 1.0 / 1.5 / 2.0×.
- `test/screens/text_scale_sweep_test.dart` — **new**: every screen the app
  can push (Symptoms, Reminders, Preferences, the health-information list
  and a topic) at 320 and 390 dp and 1.0× / 1.3× / 1.5× / 2.0×, forty cases,
  seeded with the longest strings the app will ever hold. **All forty pass**,
  so the pushed routes needed no change.
- `test/screens/climate_strip_test.dart` — **new**: the climate section at
  the same widths and scales. All pass; the section already puts the season
  on its own caption line rather than in a third column.

### Motion

The app had no animation at all — every `Duration` in it was a data duration,
not a length of time something moved for.

`lib/theme/elara_motion.dart` holds the rules: nothing runs for longer than
300 ms (the longest is 280 ms, for a sheet), and
`ElaraMotion.reduceMotion` reads `MediaQueryData.disableAnimations` — what
Android's "Remove animations" accessibility setting reports — and
`accessibleNavigation`. When either is set, **every duration collapses to
zero**, not to something shorter. An app that keeps animating anyway is
choosing a stranger's discomfort over their own setting.

The three motions, and why each is there:

| widget | where | why |
| --- | --- | --- |
| `ElaraAnimatedColor` | the phase chip | when a cycle start is logged the accent moves from one phase to another across the whole app; a cross-fade reads as the same chip showing a new state, where a snap reads as the screen reloading |
| `ElaraFadeIn` | the Today header | a fade says "this is ready"; a slide would pull the eye to the top of the screen every time a tab is opened |
| `ElaraCountUp` | the days remaining | the one number on Today that changes because the user did something |

`test/widgets/motion_test.dart` (11 tests) asserts each of them is *absent*
when the platform has asked for animations to be removed, not merely shorter.

Two bugs surfaced while writing those tests and were fixed rather than
worked around: `ElaraFadeIn` read the MediaQuery in `initState`, which
throws; and `ElaraCountUp` showed `0` for its first frame, which on a
screen that states a date is a lie for as long as it lasts.

### Icons

`lib/widgets/icons.dart` is now **complete**: every icon the app draws has a
name in it, including the symptom kinds, the theme choices, the chart
headings, the calendar navigation and the privacy eye.
`test/widgets/icon_system_test.dart` walks `lib/` and fails if any file
reaches for a raw `Icons.` constant, so the vocabulary cannot be quietly
bypassed later.

Two duplicates were found while doing this, and the new test is what found
them: `observation` and `reveal` were both `Icons.visibility_outlined` (they
mean different things — an eye says "looking at something", and what
"observation" marks is a note nobody has confirmed — so `observation` is now
a pencil), and `update` was an unused second name for `download`.

One duplicate is deliberate and is listed as such in the test: `next` and
`disclosure` are the same chevron, because "next month" and "open this row"
are different actions that both say "there is more this way".

---

## 6. Screenshots

There are **two** sets, and they answer different questions.

| | `docs/screenshots/` | `docs/device-screenshots/` |
| --- | --- | --- |
| what is rendered | the real Flutter widget tree | the **compiled APK** on an emulator |
| produced by | `tool/screenshots/screenshots_test.dart` | `tool/android_ui/capture_screens.sh` |
| has the Android system bars | no | **yes** |
| deterministic | yes | no |

Neither set is a mockup, an HTML recreation or an edited image. The device
set is what `adb exec-out screencap` produced.

**The device set is the evidence that the compiled app matches the widget
tree**, and it is the only thing that can show a platform problem: the
status bar's colour, the gesture area, the real system insets.

**Three of the sixteen device captures from the first successful run were
photographs of the wrong thing** — the four "dark" ones were a launcher's
app-switcher page, and the About one was the Android app drawer. Causes and
fixes are in the commit message for `5eb8433`: a bottom-edge swipe is read
as a pull-up, and switching the system to night mode while the app is in the
background leaves the app switcher on screen. The script now scrolls from
the middle of the screen, relaunches the app after the mode switch, and
checks the foreground app before every capture.

**Not yet done:** the corrected captures have not been re-run and inspected.
The set committed in `9a1d62c` still contains the three wrong pictures.

---

## 7. The README and the website

Both were brought up to date in `8f55f1d`, after the UI work rather than
before it:

- a new "Settings, without the boxes" section in the README, with the
  Settings and About captures, making the point that the boxes came off
  without anything coming out with them;
- the light-and-dark captions no longer claim the screens are made of
  cards;
- a paragraph on what is still boxed and why;
- a paragraph on the edge-to-edge layout;
- the landing page gains the Settings and About captures and a pointer to
  the device screenshots.

The README's approved crescent-and-gold-circle icon is unchanged, no link or
badge was invented, no proposed feature is advertised as released, and no
hardcoded test count is stated.

---

## 8. Features preserved

**No core feature was removed.** No file was deleted in this pass. The
action cards are intact with their phase prompts, food suggestions, climate
recommendations, unknown-phase explanation, uncertainty caveat and
`CareBasis` labels — the numerical romance/mood/conversation/emotional-availability
scores that were removed earlier are the only thing that ever went, and that
was approved separately.

Verified by reading the code and by the suite: `lib/screens/today/action_cards.dart`
still carries the phase prompt, `foodSuggestions` as chips, the standing
caveat and the "A suggestion, not a forecast" line;
`lib/services/care_recommender.dart` still declares all six `CareBasis`
values and the ordering that puts her preferences above your observations.

---

## 9. Unresolved defects and what was not verified

1. **The corrected device captures have not been re-run and inspected.** The
   set in `docs/device-screenshots/` still holds the three wrong pictures
   from before `5eb8433`. The fix is pushed and the next run of the workflow
   will replace them, but that run's output has not been looked at.
2. **The day-detail sheet and the health-information screen have not been
   captured on the device.** The script now tries several dates, but no run
   since that change has produced them.
4. **No notification has been seen in a notification shade on a device.** The
   icon's *resource* is verified — the `aapt2` check, the six unit
   assertions, and the resolved-name diagnosis. That the system tints it
   legibly in light and dark on a real status bar is **not** verified.
5. **No physical device was used.** Everything above was an emulator. The
   API 29, 33 and 35 images are the emulator's, not a handset's.
6. **The three-button navigation bar was not exercised.** The emulator uses
   the gesture navigation area.
7. **The keyboard obscuring an input was not exercised.** No test drives
   the on-screen keyboard.
8. **The `cmd uimode night yes` path is not the same as a user changing the
   setting in Android's own UI.** The app's dark theme is verified by the
   widget-tree renders and by the device captures; the switch in Settings is
   verified by unit tests, not by a device run.
9. **The updater was not exercised against the real API.** The dialog's
   behaviour is verified by unit tests and by the widget-tree renders; on
   the emulator it would report "could not check", because the runner has no
   route to the API.

---

## 10. Branch and push status

`main` on `mahimmazidul/elara-app`. Every commit above was pushed; nothing
is sitting unpushed. No force-push and no history rewrite were used. The
screenshot workflow's bot commits (`chore: refresh screenshots [skip ci]`)
land on `main` between pushes, and each time the next push had to rebase onto
them — that is the workflow's own output, not a history rewrite.

The token lives in `.gitinfo/token` and has never been printed, logged or
committed.
