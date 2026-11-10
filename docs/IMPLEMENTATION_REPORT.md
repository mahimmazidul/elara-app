# Implementation report — feature preservation, screenshots, README

Date: 8 November 2026

## Baseline

| | |
| --- | --- |
| Feature baseline inspected from | `59412f6` — last commit before the P1 UI and recommendation work |
| HEAD at the start of this pass | `ea21a43` |
| HEAD at the end of this pass | `ef059f2`, pushed to `main` |
| Working tree at start | clean (the P1 work was already committed) |

No force-push, no history rewrite, and no unrelated files were reformatted. The
only files touched are listed under "Files changed".

## Feature audit

90 feature rows were recorded in [`FEATURE_REGRESSION.md`](FEATURE_REGRESSION.md),
covering cycle handling, partner care, environment, calendar and astronomy,
notifications, privacy and data, and interface.

| | |
| --- | --- |
| Features inspected | 90 |
| Preserved unchanged | 71 |
| Improved or relocated (behaviour kept, presentation or code path changed) | 14 |
| Preserved as-is after verification (action cards, regenerated in place) | included above |
| Accidentally removed, then restored | **1** — `ActionCards` on Today (see below) |
| Removed intentionally, with the owner's approval | **1** — numerical conversation / romance score bars (`score_bar.dart`, deleted in `7548c05`) |
| Still unverified | 6, each with a stated manual procedure |

Two files have ever been deleted from this repository and no test file ever has;
both facts are verified with `git log --diff-filter=D` over the whole history and
recorded in the matrix.

### The action-card regression

`ActionCards` was never dead code in any commit: from `08f9564` to `59412f6` it was
imported by `today_screen.dart` continuously. In the *first* pass of the P1 rework
the new Today screen stopped importing it and the file was removed from the index.
That was a regression, it was called out, and it is fixed:

- The file was restored from `HEAD` before any commit and is now committed in its
  redesigned form (`a0e7d6e`).
- Behaviour preserved: the phase prompt from elara-core's `ActionEngine`
  (`Offer practical support`, `Check in gently`, `Make time to connect`,
  `Consider a date night`, `Make room for a quiet check-in`, `Offer support
  without assumptions`), `foodSuggestions` as chips, the standing caveat, and the
  explicit empty state when no phase can be classified.
- Behaviour **added**: cards after `cards[0]` now render when they say something
  the block does not already say, instead of being dropped.
- Behaviour kept out on purpose: `conversationScore` and `romanceScore` are still
  produced by elara-core and deliberately not read by the UI.
- `ActionResult` is still used in four places: `prediction_service.dart` (builds
  it), `today_screen.dart` → `ActionCards`, `day_detail_sheet.dart` (the day's own
  card), and `notification_service.dart` (reminder text).
- Climate-aware actions are generated twice over: the severity → `ActionEngine`
  path, and `CareRecommender._fromClimate` for heat ≥ 38 °C, PM2.5 ≥ 100 and
  heat ≥ 33 °C.

## Screenshots

13 captures in `docs/screenshots/` plus a contact sheet, all rendered from the
real widget tree by `tool/screenshots/screenshots_test.dart` at 390 × 844 @ 3×
(tablet at 1024 × 768 @ 3×) with the bundled fonts, a fixed fictional dataset and
mocked weather. Nothing is a mockup, nothing is retouched, and no screenshot shows
a feature that does not exist.

`today`, `today-dark`, `today-action`, `today-action-dark`, `calendar`,
`calendar-dark`, `calendar-detail`, `insights`, `settings`, `settings-privacy`,
`preferences`, `about`, `tablet`, `contact-sheet`.

The screenshots were the review tool. Ten defects were found by looking at them
and fixed in the Flutter code rather than in the images:

1. Bengali lunar names rendered as tofu boxes → 43 KB Noto Sans Bengali subset,
   declared as `fontFamilyFallback`.
2. Scrolling pages ended level with the bottom navigation bar, so the last line of
   Today was clipped and Settings' last control sat behind the bar → `pageInsets`
   reserves the M3 bar height.
3. The day-detail sheet overflowed and hid the day's action card → capped at 85 %
   of the height and made scrollable.
4. "Post–monsoon" broke after its hyphen in a third of the width → season moved to
   its own caption line.
5. The phase chip was a 22 pt headline on a screen about care → 15 pt subtitle chip.
6. The cycle day was printed twice → duplicate removed.
7. Climate sat above care → reordered to match the brief's hierarchy.
8. Settings overflowed at 1.5× text (13 px) and 2.0× (99 px) → wrapping chips
   replace the segmented control; the location buttons share the row.
9. Selected chips took the luteal purple from Material's `secondary` → neutral
   `chipTheme`.
10. Two captures caught real defects of the harness rather than the app (a
    mid-route fade, and a hard crop through a line of copy) → the harness now waits
    past the route animation and scrolls to a section boundary.

## Tests

| | |
| --- | --- |
| `dart analyze --fatal-infos` | clean |
| `flutter test` | **237 passed**, 0 failed, 20 test files |
| New this pass | 28 (17 care recommender, 8 preferences screen, 5 action cards — the last two committed earlier in the P1 pass; plus 3 responsive matrix expansions) |
| Screenshot generator | `tool/screenshots/screenshots_test.dart`, 9 tests, all producing files |

New coverage worth naming:

- `test/services/care_recommender_test.dart` — generation for every preference
  category, priority (her answer > observation, confirmed > unconfirmed, shared
  answer > symptom, environment labelled as an assumption), consent filtering,
  the two-day symptom window, de-duplication, and copy that never names a
  condition.
- `test/screens/today_action_cards_test.dart` — the prompt, both food chips and
  the caveat are visibly rendered; no `conversation`, `romance` or `/10` text
  anywhere; the unknown-phase explanation; the phase accent; and a full
  `TodayScreen` render proving the care suggestions **and** the action card both
  appear.
- `test/screens/preferences_screen_test.dart` — persistence, editing, deletion,
  the private-answer rule, the observation/confirmed distinction, and the honest
  wording about same-device storage.
- `test/widgets/responsive_test.dart` — Today at 320/360/375/390/430/720/1024 and
  every tab at 1.0×/1.3×/1.5×/2.0× text scale, failing on any overflow.

## Build status

- Analyze and tests: **pass** (locally and on CI, run `42518514202`).
- Android APK: **not built in this environment** — the sandbox has no Android
  SDK, and this project needs SDK 37, AGP 9.1 and an NDK download that exceeds it.
  CI's `ci.yml` covers analysis and tests only; the Release workflow builds the
  signed APKs and the AAB, and was skipped for this commit because the version was
  not bumped (v1.2.0 is already published). No claim is made that the Android
  build of this commit was verified.
- All changes are Dart, asset fonts and docs; no manifest, Gradle or plugin
  changes were made, so the Android build surface is unchanged.

## README and website

- `README.md` rewritten as a showcase in the required order: icon and hero with
  verified badges, short introduction, six alternating feature sections built from
  real screenshots, light/dark pair, privacy and offline-first architecture,
  prediction methodology, medical boundaries, installation with the actual v1.2.0
  asset names, development setup, architecture, testing and CI, roadmap split into
  implemented and planned, the Greek name, credits with verified links only,
  contributing, licence.
- Every local image path resolves, every badge and external link returned HTTP
  200, and the version shown (`v1.2.0`) matches the published release.
- No claim in the README refers to an unimplemented feature; the medical section
  and updater are listed under Planned. No test count is hardcoded.
- The paired sections are Markdown tables, which GitHub renders side by side and
  does not stack; the README says so and points at the full-size captures rather
  than pretending the layout is responsive.
- `docs/index.html` keeps its design. Two changes: a real CSS grid showing two
  captures (collapsing to one column below 40 rem, which is a genuine media query
  the site can use), and a feature line that now describes a few ranked ideas
  instead of one.

## Remaining issues, stated plainly

| Issue | Consequence | Next step |
| --- | --- | --- |
| Android build unverified in this environment | a compile error would only surface on the next release run | run `flutter build apk` on a machine with the SDK before tagging |
| Notifications, background alarms and lock-screen privacy untested | platform behaviour cannot be exercised headlessly | install the release APK and wait for a reminder |
| Symptom logging has no UI yet | the table, model and provider exist and are used by the recommender, but there is no screen to enter a symptom | design and build it; do not advertise it until then |
| Medical-information content not implemented | no screenshot and no README claim; it is listed as planned | needs a clinician's review as well as code |
| Updater and About-with-links not implemented beyond the in-app About card | listed as planned | — |
| Prediction coverage not validated | the app shows a window but makes no accuracy claim | measure against a real history before claiming anything |
| Text at 2.0× verified for exceptions, not for looks | no PNG at that scale | look at it on a device |
| Preferences editor driven by tests at the provider level, not through the sheet UI | a layout bug in the sheet would not be caught | add a widget test that taps through add → edit → share → delete |

## Files changed

```
lib/screens/today/action_cards.dart        extra cards render; flat, phase-accented
lib/screens/today/today_screen.dart        hierarchy: care before climate; no duplicate day
lib/screens/today/climate_strip.dart       season on its own line
lib/screens/calendar/day_detail_sheet.dart capped and scrollable
lib/screens/settings/settings_screen.dart  preferences link; chips; no overflow
lib/screens/preferences/preferences_screen.dart        NEW
lib/providers/preferences_provider.dart    summary line for the Settings row
lib/theme/elara_theme.dart                 nav-bar inset, chip theme, Bangla fallback
lib/widgets/phase_chip.dart                subtitle-size chip
lib/widgets/icons.dart                     plus, more
lib/utils/moon_phase.dart                  Bangla names (from the P1 pass)
assets/fonts/NotoSansBengali-Subset.ttf    NEW, 43 KB
pubspec.yaml                               the Bengali fallback family
tool/fonts/build_fonts.py                  subsets and builds it
tool/screenshots/screenshots_test.dart     new captures, mocked preferences, font
test/services/care_recommender_test.dart   NEW
test/screens/today_action_cards_test.dart  NEW
test/screens/preferences_screen_test.dart  NEW
test/widgets/responsive_test.dart          width and text-scale matrix
README.md                                  rewritten
docs/FEATURE_REGRESSION.md                 NEW
docs/SCREENSHOT_MANIFEST.md                NEW
docs/screenshots/*.png                     14 files, regenerated
docs/index.html                            two-shot responsive grid
```

## Commits

```
a0e7d6e  fix: restore and protect core feature behavior
ca26ebc  docs: regenerate and verify application screenshots
4271552  docs: redesign README with a visual feature showcase
5890b19  docs: add the feature regression matrix and align the website
ef059f2  docs: say plainly how the paired showcase behaves on a narrow phone
```

Pushed to `main`; `git ls-remote` confirms `ef059f2` is the remote head. CI passed
for that SHA (analyze and the full suite).
