# Implementation report — symptoms, reminders, health information, About/updates

Pass date: 2026-11-08. Repository: `mahimmazidul/elara-app`.

| | |
|---|---|
| Starting commit | `1fc6d0d` (README-only commit on top of `4020c24`) |
| Ending commit | `b774110` |
| Commits this pass | 6 (`2954680`, `bc8a74c`, `310ff48`, then rebased as `bbc1b5c`, `0488fc4`, `b774110` on top of the separately-pushed `fa90345`) |
| Schema | v3 → **v4** (one new table, additive) |
| Tests | 238 → **353 passing**, `dart analyze --fatal-infos` clean |
| Push | see "Commit and push status" at the end |

## 1. What was completed

### Symptom tracking (brief §2)

- **UI now exists.** `screens/symptoms/symptoms_screen.dart` is a day-grouped list
  with no streaks, no counts and no scores; `screens/symptoms/symptom_editor.dart`
  is a bottom sheet limited to *today and earlier*, with kind chips, a 3-level
  severity/flow scale, an optional 140-character note, Save, Remove and Not now.
- **Correction against reality.** `SymptomsProvider.log` gained a `replacing`
  parameter: correcting an entry replaces the row it came from. Without it, a
  correction that changed the kind or the day left a duplicate behind.
- **Date-encoding bug fixed.** `Symptom.toMap` wrote a full ISO instant into the
  `date` column while every query compared against a `yyyy-MM-dd` key, so **no
  stored symptom ever matched a date filter** — the feature was silently broken at
  the data layer before this pass. Dates now go through `dateKey()`, and the v4
  migration rewrites any legacy ISO value in place (no rows dropped, no rows
  invented). `CareReminder` was written correctly from the start.
- Today shows a two-line note of what she reported today or yesterday, and a way
  in when nothing has been recorded. Calendar days carry a small dot.
- Nothing is inferred from a phase and nothing is diagnosed; the screen says both
  in plain words, and the tests assert the absence of that language.

### Care reminders (brief §4, "optional care reminders")

- New table `care_reminders(id, date, title, note, done, created_at)` plus
  `idx_reminders_date`, added by `_migrateToV4`. The migration creates a table and
  an index; it does not seed or rewrite anything.
- Editor sheet: date picker (−60 to +365 days), free-text title with four
  practical suggestions, optional detail, a done toggle on existing rows, remove.
- `screens/reminders/reminders_screen.dart` groups past / coming up / done;
  ticking marks done rather than deleting, because "I already did that" is worth
  being able to see.
- The day detail sheet gained **Reported that day** and **Planned for that day**
  sections, and the month grid shows one 4 px dot per feature beside the today dot
  — no badges, so the date stays the thing you read first.

### Health information (brief §6)

- `data/medical_content.dart` bundles eight topics — period pain, heavy or
  prolonged bleeding, irregular periods, PMS, PMDD, PCOS, endometriosis,
  over-the-counter pain relief — plus a note on what is usually harmless. Each has
  body sections, a red-flag list, and its sources.
- Sources are real published pages (NHS, NICE, ACOG, WHO); **every URL was
  fetched and checked for a 200 before being written in**, and the month of
  checking (`November 2026`) is printed on every topic and in the list header.
- **Separate from personalized care by construction**: same text for everyone,
  reachable from Settings, not selected from any phase or logged symptom, and the
  index says so before anything else. The three-level Simple/Scientific/Read More
  upgrade was not implemented, per the brief.
- Pain relief gets precautions and contraindications, defers to the label and a
  pharmacist, and contains **no doses** — a test asserts that no `N mg`/`N tablet`
  string appears.
- Topics with an urgent line (PMDD self-harm, suspected overdose, soaking through
  protection) show it above the body, not at the bottom.

### About and release management (brief §7)

- `screens/settings/about_section.dart` replaces the old About card: installed
  version **and build number** read from `AppInfo.version` (which
  `test/app_info_test.dart` keeps in step with `pubspec.yaml`), licence, developer
  attribution, source/engine/releases links, acknowledgements, limitations, and an
  explicit statement that **Elara publishes no social accounts** — no invented
  handles or profiles.
- `services/update_service.dart` checks GitHub Releases. `SemanticVersion`
  implements SemVer precedence correctly: numeric comparison (`1.10.0 > 1.9.0`),
  build metadata ignored, pre-releases sorting below their release and **never
  offered to a stable build**. Comparison is against the installed package
  metadata, not a hardcoded constant.
- Results are a typed union, so an offline check can never render as "up to date".
  Timeouts, rate limits, 404, malformed JSON and unreadable tags each get a plain
  explanation; a request sends one unauthenticated GET with no query string, no
  identifying headers and no body, and the **service never downloads or installs**
  — links copy to the clipboard, and the sheet says the app will not install it.
- Automatic checking is a real switch, **off by default**; when on, `RootScaffold`
  makes the request once per launch, after the first frame.

### Privacy decision (brief §10)

- `docs/PRIVACY_MODEL.md` records what is stored where, what protects it, the four
  encryption options weighed, and the decision: **leave the database unencrypted
  for this pass**, with a passphrase-derived key + SQLCipher as the target model.
  The reasoning is the failure-mode rule: a Keystore-only key adds a
  decryption-failure path that could lock a user out of her own history, without
  protecting against the threat that matters (someone holding the unlocked phone).
- The Privacy and data card now **states the limit plainly** instead of implying
  encryption at rest: exports are encrypted, stored history is not, and it relies
  on the app sandbox and device encryption.

### Prediction reliability (brief §5) — measured, not claimed

- `tool/prediction/calibration_report.dart` runs a walk-forward evaluation over
  eight synthetic cohorts and writes `docs/PREDICTION_CALIBRATION.md`. The report
  says plainly that synthetic cohorts describe engine behaviour, not calibration
  for real users.
- `docs/PREDICTION.md` records the finding: for consistently long spacing
  (60–120 days) confidence collapses and the window widens as it should, but the
  point estimate stays near 37–41 days, so a symmetric window misses the outcome.
  **No algorithm was changed**; the fix belongs in `elara-core` behind its own
  backtest gates, and is written up as a recommendation with a gate.
- One input guard was added here: a start fewer than 10 days after the previous
  start is refused with the gap named and a pointer to correcting the earlier
  date. Same-day logging still updates the duration; long gaps are never refused.

### App icon (brief §8)

- Corner radius softened 0.22 → **0.25** of the tile, matching the website's mark
  (18 px on 72 px). Symbol, proportions and colours untouched.
- The Android 13 monochrome layer was a bare crescent; the gold dot is now in the
  alpha mask too, at the same position and size ratio, because without it the
  themed icon loses the shape that identifies it.

### README mobile responsiveness (final task)

- The showcase is a single vertical column: capture above description, six
  screenshots at 260 px, the light/dark pair at 240, tablet at 600. Real captures
  only, aspect ratios intact.
- The two remaining tables (release files, dependencies) became lists.
- Verified in **headless Chromium** at 320/360/375/390/430/1024 px: no horizontal
  overflow at any width, every image inside the column, text at full width.
- Feature list, schema version and roadmap brought back in step with the app.

## 2. What is partial or not done

| Item | State |
|---|---|
| Preferences interface (brief §1) | **Already complete** at the starting commit (screen, editor, private-answer rule, observation/confirmed distinction, delete confirmation). Not rebuilt; only linked alongside the new rows. |
| Wider window for long cycles | **Measured and documented, not changed.** Needs an `elara-core` change with its own evaluation. |
| Encryption at rest | **Decided against for now**, with the model and next steps recorded in `docs/PRIVACY_MODEL.md`. |
| Automatic/silent install of updates | **Deliberately absent** — the brief forbids it. |
| Calendar "planning activities" | Covered by care reminders (free text per date). No separate activity/supplies data model was added; inventing one would have duplicated what reminders already do. |
| Prediction intervals | **Not described as validated anywhere.** |

## 3. Files changed

New: `lib/data/medical_content.dart`, `lib/data/models/care_reminder.dart`,
`lib/providers/reminders_provider.dart`, `lib/providers/update_provider.dart`,
`lib/services/update_service.dart`, `lib/screens/symptoms/{symptom_editor,symptoms_screen}.dart`,
`lib/screens/reminders/{care_reminder_editor,reminders_screen}.dart`,
`lib/screens/medical/{medical_screen,medical_topic_screen}.dart`,
`lib/screens/settings/about_section.dart`, `lib/screens/today/day_notes.dart`,
`tool/prediction/calibration_report.dart`,
`docs/{PREDICTION,PREDICTION_CALIBRATION,PRIVACY_MODEL,IMPLEMENTATION_REPORT}.md`,
tests: `test/providers/{symptoms,reminders}_provider_test.dart`,
`test/screens/{symptoms_and_reminders,medical_screen,about_section}_test.dart`,
`test/services/update_service_test.dart`.

Modified: `lib/data/database_helper.dart` (v4), `lib/data/models/symptom.dart`,
`lib/providers/{cycle,symptoms,settings}_provider.dart`, `lib/providers/settings_keys.dart`,
`lib/main.dart`, `lib/screens/root_scaffold.dart`,
`lib/screens/calendar/{calendar_screen,day_detail_sheet}.dart`,
`lib/screens/settings/{settings_screen,privacy_data_section}.dart`,
`lib/screens/today/today_screen.dart`, `lib/widgets/icons.dart`,
`tool/icon/generate_icon.py`, ten launcher PNGs, `README.md`, and four existing
test files plus `tool/screenshots/screenshots_test.dart` (provider graphs).

## 4. Database changes

`care_reminders` + `idx_reminders_date` (v4, additive). The v4 migration also
normalises a legacy `yyyy-MM-ddTHH:mm:ss` value in `symptoms.date` to
`yyyy-MM-dd`, in place. No table dropped, no column removed, no row invented or
deleted; `test/data/consent_schema_test.dart` still proves the v1→v2 path and
`database_helper_test.dart` covers the rest.

## 5. Tests added

115 new tests (238 → 353):

- `reminders_provider_test.dart` (13): round trip, blank title refused, **two
  reminders on one day both survive**, edit keeps the id, blank edit refused, done
  is a flag not a delete, single delete, note clearing, upcoming window, reopen
  persistence, summary counts unfinished only, unknown id, map round trip.
- `symptoms_provider_test.dart` (12): stored against the given day, time-of-day
  dropped, future date refused, several per day, correction in place, correction
  that changes kind **and** day leaves no duplicate, out-of-range severity
  refused, delete one, out-of-window rows neither shown nor marked but **not
  deleted**, symptoms never create a cycle record, summary in days.
- `symptoms_and_reminders_test.dart` (22): both screens' empty states and
  wording, editor save, tap-to-edit, tick-to-done, add from the list, blank
  refusal, a **literal-escape regression check**, and 320–430 dp × 1.0/1.5/2.0×.
- `medical_screen_test.dart` (23): sources present and https with a path, red
  flags ≥ 3 per topic, bodies non-empty, ids unique, no diagnostic phrasing, the
  brief's seven subjects present, pain relief carries precautions and **no doses**,
  index/topic rendering, urgent notes, and 320–430 dp × 1.0/1.5/2.0×.
- `update_service_test.dart` (21): version ordering including `1.10 > 1.9` and
  pre-release precedence, bad input, newer/older/pre-release outcomes, APK parsing
  with `arm` not matching `arm64`, offline ≠ up to date, timeout, rate limit, 404,
  malformed JSON, unreadable installed version, and **the request carries no
  identity and no query**.
- `about_section_test.dart` (19): version + build from metadata, no invented
  social links, limitations and privacy statements, an unchecked row not implying
  current, release sheet with notes and sizes, offline dialog, automatic check off
  by default, and 320–430 dp × 1.0/1.5/2.0×.
- `cycle_correction_test.dart` (+5): implausible interval refused with the gap,
  the pointer to correcting the earlier date, threshold boundary accepted,
  same-day logging still updates, backfilling an older start allowed.

## 6. Analysis and build results

- `dart analyze --fatal-infos`: **No issues found.**
- `flutter test`: **353 tests, all passing** (run three times across the pass; two
  full runs after the last two commits).
- `flutter build apk`: **not run successfully — not verified.** This sandbox has
  no Android SDK (`[!] No Android SDK found`), so no APK was produced or
  inspected in this pass. Nothing here should be read as a verified build.

## 7. UI verification

Rendered with a temporary harness that loads the real DM Sans and Material Icons
fonts (the committed screenshot harness's approach) and writes PNGs:

- **Symptoms** (light and dark), **Care reminders**, **Health information index**,
  **Period pain topic** at 390 × 844: verified visually. This is how the literal
  `\u00b7` bug was found and fixed — a screenshot caught what the tests did not,
  and a regression test now covers it.
- **Calendar with day marks and the day sheet**: my own harness could not be run
  (the climate provider's timers hang a headless render), so **these were not
  visually confirmed by me**. The separately generated screenshots
  (`docs/screenshots/calendar.png`, `calendar-detail.png`, refreshed in `fa90345`
  from the post-rebase tree) do show the shipped calendar and day sheet, and the
  Settings capture shows the new Symptoms and Care reminders rows with their live
  summaries ("Recorded on 1 day", "Nothing planned") and the Health information
  card. Their behaviour is covered by widget tests
  (`responsive_test.dart`, `screens_test.dart`, `accessibility_test.dart`) and by
  the grid/sheet code paths exercised there, but no screenshot was taken.
- **README**: rendered to HTML and measured in headless Chromium at six widths (see
  above).
- Layout assertions for the new screens and About run automatically at
  320/360/390/430 dp and 1.0/1.5/2.0× text; two real defects were found and fixed
  this way (a `ListTile` with no `Material` for its ink, and a `Spacer` that made
  a label unshrinkable).

## 8. Remaining limitations and what still needs verification

- **Long-cycle prediction placement** is a known defect, documented and
  unfixed (it requires an `elara-core` change).
- **No APK was built**, so nothing about the release artefact is verified here.
- **No real-device run**: launcher-icon rendering under a vendor mask, themed
  icons on Android 13+, notification privacy wording on a lock screen, and the
  background alarm path remain unverified on hardware.
- **No clinical review** of the health information. The text is written from
  cited public sources and says so; it is not clinically validated, and the
  sources should be re-checked before any release note claims currency beyond
  November 2026.
- **Encryption at rest is absent by decision**, and the app now says so.
- The preferences work from the previous pass was left intact; this pass only
  linked it, so its own limitations carry over unchanged.

## 9. Commit and push status

Pushed to `main`, rebased onto `fa90345` (`chore: refresh screenshots`), which
the separate screenshot work had pushed while this pass was running. Nothing of
that work was overwritten: the screenshots commit is an ancestor, and the three
of my own commits sit on top of it.

Note on history: the sandbox was reset twice mid-pass. The working tree survived
each time and the local `.git` did not, so the first three stages are recorded in
one commit whose message says so, rather than in reconstructed commits whose file
sets would overlap. No history was rewritten and no force-push was used.
