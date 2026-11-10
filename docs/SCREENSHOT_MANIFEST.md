# Screenshot manifest

There are **two** sets of images in this project, and they answer different
questions.

| | `docs/screenshots/` | `docs/device-screenshots/` |
| --- | --- | --- |
| What is rendered | the real Flutter widget tree | the **compiled APK** on an emulator |
| Produced by | `tool/screenshots/screenshots_test.dart` | `tool/android_ui/capture_screens.sh` |
| Has the Android system bars | no | **yes** |
| Has the gesture / navigation area | no | **yes** |
| Deterministic | yes — same seed, same date | no — the emulator's own clock |
| Used for | the README and the landing page | evidence that the compiled app matches the widget tree |

Neither set is a mockup, a design comp, an HTML recreation, or an edited image.
The widget-tree set is rebuilt by `screenshots.yml` on every change; the device
set is rebuilt by `device-screenshots.yml` and committed from the emulator's own
`screencap`, untouched.

## The widget-tree set

Regenerate with:

```bash
flutter test tool/screenshots/screenshots_test.dart
```

Nothing here is compared on a normal `flutter test` run — the file lives outside
`test/` so antialiasing noise never produces meaningless commits. Each capture is
inspected by eye after generation; the defects found that way are listed at the
bottom.

## Capture method

| | |
| --- | --- |
| Harness | `tool/screenshots/screenshots_test.dart` |
| Widget | real `RootScaffold` and the real screens, real providers |
| Database | sqflite FFI, in-memory, reseeded per test |
| Network | `MockClient`: fixed Open-Meteo and OpenAQ responses, no real requests |
| Fonts | `assets/fonts/DMSans-{Regular,Medium,Bold}.ttf`, `NotoSansBengali-Subset.ttf`, SDK `MaterialIcons-Regular.otf` |
| Pixel ratio | 3× (a 390 × 844 logical viewport becomes 1170 × 2532 px) |
| Date | the machine's current date; **all** relative data is seeded from it so the date, cycle day, phase and countdown agree |
| Debug banner | disabled |

## Demo data

Fictional throughout; no real person's data is used or included.

- Five period starts at 125, 97, 68, 39 and 9 days before today, each 5 days
  long — a 29-day rhythm. Today is therefore **day 10**, phase **ovulatory**,
  next estimate **20 days** away (± 2).
- Thirty days of cached climate (heat index 33–39 °C, PM2.5 ~38–50, monsoon
  humidity) so both the strip and the Insights heat series show a real series.
- Five preferences: three written by her (one kept private on purpose), two the
  holder observed (one unconfirmed). One fatigue symptom recorded yesterday.
- Consent recorded as granted through the setup gate, which the Settings card
  shows as "Recorded".

## Files

| File | Screen | Theme | Viewport (logical) | State shown | Status |
| --- | --- | --- | --- | --- | --- |
| `today.png` | Today | light | 390 × 844 | full data; date, phase chip, countdown, three care suggestions with their sources, start of the phase card | Verified |
| `today-dark.png` | Today | dark | 390 × 844 | same state | Verified |
| `today-action.png` | Today, guidance section | light | 390 × 844 | scrolled to the care section: her preference, reported symptom, weather, then the elara-core phase prompt with food chip and caveat | Verified |
| `today-action-dark.png` | Today, guidance section | dark | 390 × 844 | same state | Verified |
| `calendar.png` | Calendar | light | 390 × 844 | November; four phase colours, today marked, legend and projection note | Verified |
| `calendar-dark.png` | Calendar | dark | 390 × 844 | same month | Verified |
| `calendar-detail.png` | Day-detail sheet | light | 390 × 844 | 30 October 2026, a **recorded** start: correction buttons plus that day's action card and food chips | Verified |
| `insights.png` | Insights | light | 390 × 844 | 4 cycles: length history, average 29.0 ± 0.8 days (1 SD, n = 4), 30-day heat index series | Verified |
| `settings.png` | Settings, top | light | 390 × 844 | location, appearance, notification toggles | Verified |
| `settings-privacy.png` | Settings, scrolled to the end | light | 390 × 844 | consent, notification privacy, encrypted backup, About | Verified |
| `preferences.png` | Preferences | light | 390 × 844 | her three answers (one "Kept private"), the holder's two observations (one "Unconfirmed") | Verified |
| `about.png` | Settings › About block | light | 390 × 844 | name, version 1.3.0+7, licence, developer, engine, the start-up update check and the medical-limitation line | Verified |
| `tablet.png` | Today on a tablet | light | 1024 × 768 (3072 × 2304 px) | navigation rail beside a centred 720 dp content column | Verified |
| `contact-sheet.png` | index of the above | — | 2434 × 1774 | every phone capture on one page, for review | Verified |

## What is not captured

Stated explicitly rather than implied by omission:

| Item | Why | How to verify |
| --- | --- | --- |
| The medical information screen and the update dialog | both are implemented, but they are captured by the **device** set rather than the widget-tree set, because the medical screen opens on a route pushed from Settings and the dialog depends on a network answer | `docs/device-screenshots/09-medical.png` and `37-dialog.png` |
| Text scaling at 1.5× and 2.0× | no PNG; `test/widgets/responsive_test.dart` renders every tab at 1.0×, 1.3×, 1.5× and 2.0× and fails on any overflow | run the app at 2.0× and look at it — the test proves no exception, not that it looks right |
| Phone viewports other than 390 dp (320/360/375/430) | `test/widgets/responsive_test.dart` lays Today out at each width and fails on overflow | install on those devices |
| Notification shade and lock screen | platform UI, outside the Flutter tree | install the release APK and wait for a reminder |
| Onboarding and the consent gate | deliberately not screenshotted: they are first-run states, and the README shows the app in use | run on a fresh install |

## Defects found during screenshot inspection, and fixed

The screenshots are the review tool, not decoration; these were all found by
looking at the first renders and were fixed in the Flutter code rather than
retouched.

| Defect seen in the render | Fix |
| --- | --- |
| Bengali lunar name drawn as tofu boxes (`□□□□□□`) | bundled a 43 KB subset of Noto Sans Bengali and registered it as `fontFamilyFallback` on every text style |
| Bottom text clipped under the navigation bar | `ElaraSpacing.pageInsets` now reserves the M3 navigation bar height (80 dp) plus the safe-area inset |
| Day-detail sheet cut off, hiding the day's action card | sheet capped at 85 % of screen height and made scrollable |
| "Post–monsoon" broken after its hyphen in a third of the width | season moved to its own caption line under the two measured values |
| Phase chip too large, reading as the headline of the screen | 15 pt subtitle chip with tighter padding |
| Cycle day printed twice ("Day 10" in the chip, "Day 9 of this cycle" below) | removed the duplicate |
| Climate strip above the care section | reordered: care first, climate after |
| Settings' last control sat behind the navigation bar | fixed by the same inset change; re-verified by scrolling to the end |
| Preferences capture caught mid-route-transition (two screens cross-faded) | harness now waits past the 300 ms route animation |
| Settings theme selector overflowed at 1.5× text (13 px) and the location buttons at 2.0× (99 px) | segmented control replaced by wrapping chips; both location buttons share the row |
| Selected chips took the luteal purple from Material's `secondary` | `chipTheme` uses the neutral raised tint, so no phase colour appears on a control unrelated to the cycle |
| Settings and About were a stack of cards | five cards in Settings and four in About unwrapped into headed sections with hairline separators; the consent gate's card removed too |
| The developer's name broke in the middle of itself in About | the label-and-value row now measures both texts and moves the value under the label when they will not fit side by side |
| The "Check on start-up" switch overflowed its row by 60 px at 1.5× text | replaced with the same shape as the notification switches: an `Expanded` label column and a `Switch.adaptive` |
| The version header overflowed at 320 dp and 1.5× text | the row became a `Wrap` |
| The status bar was a grey band detached from the app | the window drew edge to edge but Flutter painted its own default bar style over it; the style now comes from an `AnnotatedRegion` around the whole app, and the emulator script samples the top strip of the screenshot to check it |

## The device set

`docs/device-screenshots/` is what the emulator's own `screencap` produced from
the installed APK. It is committed by `.github/workflows/device-screenshots.yml`,
which builds the debug APK, installs it on an Android 13 emulator, drives it
through its screens and copies the captures out.

The differences that matter, and that the widget-tree set cannot show:

- **The Android status bar is in the frame**, with the clock, the signal icons
  and the battery. Whether it is transparent — showing the app's page colour —
  or a grey band is decided by the platform and the Flutter engine, not by the
  widget tree.
- **The navigation area is in the frame**, so the bottom of the app's tab bar
  can be checked against the gesture handle.
- The captures are **not deterministic**: the emulator's clock and the real
  system state decide the date on screen. They are evidence, not a fixed
  baseline, which is why the README uses the widget-tree set.

## Cross-checking

`docs/screenshots/contact-sheet.png` puts every phone capture side by side. When
reviewing a change, compare it against the previous sheet rather than only the
individual file: the sheet makes a shifted baseline, a changed accent or a
mismatched light/dark pair obvious in a way single images do not.
