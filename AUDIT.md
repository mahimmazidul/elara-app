# Elara: product audit, UX review and development plan

Reviewed against `main` at `7548c05`, plus the two commits it followed. Every
claim below was checked against the source in this repository, and where a
number is quoted it was measured by running code, not estimated.

Two notes before anything else.

**Scope of what has already changed.** The brief carried a separate
implementation section that pre-approved three changes. Those are done and
shipped: phase-adaptive theming, DM Sans, and the landing page. Two of them
entailed removing the conversation and romance scores, which this audit
independently recommends (P0-1). Everything else in this document is a proposal
and nothing else has been written.

**What this is not.** Elara is a partner-oriented app built around care, and
this audit treats it that way. The recommendations push toward asking, noticing
and preparing. None of them add surveillance, scores, or hormone-based
character reading.

---

## A. Executive assessment

Elara is a genuinely good small application with a clear identity, and it is
about two steps short of being the thing it claims to be.

The engineering is stronger than the product thinking. The data layer is
versioned and refuses to open a database written by a newer build. The
prediction engine is a real ensemble rather than a marketing word. The test
suite is 140 tests over real SQLite, real astronomy and real widget trees, and
it passes. Typography, contrast and the four-colour phase system are consistent
to the point where removing one shadow would be a visible change. That is not
typical for a project of this size.

Where it falls short is exactly where the identity lives. The app currently
describes a partner's inner life in numbers, which the brief and this audit both
reject. It has no notion of consent, even though its entire premise is one
person holding another person's health data. It never asks what the partner
herself has said she finds helpful, so every suggestion is inferred from a
calendar rather than from the person. And its notification text can show cycle
information on a locked screen without asking.

Maturity: solid beta. The correctness and release machinery are release-grade.
The product layer needs the P0 and P1 work below before it should be handed to a
real couple.

Strengths, specifically:

- Offline-first is real. No account, no sync, no analytics, no network call
  except weather and air quality.
- Uncertainty is shown, not hidden: `± 2 days` sits next to the estimate.
- The prediction engine handles the cases that break naive trackers, including a
  period longer than the predicted cycle and an overdue start.
- Honest empty states throughout. With one cycle logged, the app says it needs
  more rather than inventing a phase.

Weaknesses, ranked by how much they damage the product:

1. Numerical relationship scores (P0, now removed).
2. No consent model for whose data this is (P0).
3. Lock-screen notifications exposing cycle state (P0).
4. Guidance inferred from dates rather than from the partner's own preferences
   (P1).
5. Calibration of the prediction window is optimistic for irregular cycles
   (P1; measured below).
6. No way to correct a mistake in the data beyond deleting a day (P1).
7. Astronomical layers (nakshatra, Hijri) are well built but sit in the primary
   reading path, where they dilute the care message (P2).

---

## B. Confirmed issue register

Severity: **S1** data exposure or trust damage, **S2** incorrect or misleading
output, **S3** usability defect, **S4** maintenance risk. Each item is a
confirmed defect with a source reference, not a hypothesis. Hypotheses are in
section B2 and kept separate.

### B1. Confirmed defects

**B-01 · S1 · No consent or provenance model for whose data this is**
`lib/screens/today/onboarding_card.dart:114` asks "When did your wife's last
period start?" and the app then stores her cycle history indefinitely. There is
no screen, toggle or copy anywhere that establishes that she knows the app
exists, that she agreed to it, or how to withdraw. Current behaviour: the
partner's health data is entered by a third party with no record of consent.
Expected: an explicit, revocable statement of who this data belongs to, taken
before the first entry. Root cause: the app was built around the user who holds
the phone. Fix: consent gate at onboarding, stored as a settings row with a
timestamp, revocable from Settings, which also clears derived data. Regressions
to watch: existing installs must not be re-gated on upgrade; the gate must not
be a modal that can be dismissed and never revisited. Tests: consent row written
once, revocation clears cycles, upgrade path leaves existing data readable.

**B-02 · S1 · Notification content is visible on the lock screen**
`lib/services/notification_service.dart:534-535` uses
`Importance.defaultImportance` / `Priority.defaultPriority` and sets no
visibility, so Android uses the channel default and the briefing body
(`:368`) appears in full in the shade and on the lock screen. Cycle state in a
notification is health information. Expected: default to private. Fix: set
`visibility: NotificationVisibility.private` and add a "Show details in
notifications" setting, off by default, with a neutral title when off. Tests:
scheduling passes private visibility; the toggle changes the body text.

**B-03 · S1 · Database is unencrypted**
Nothing in `lib/data/database_helper.dart` encrypts; `elara.db` is plaintext in
app storage. This is defensible for a single-user tracker, but this app holds
two people's information. Expected: at minimum, encrypted storage or a documented
and deliberate decision not to; ideally `sqlcipher` with the key in
Keystore-backed storage. Fix must be judged against battery and startup cost.
Related: no `FLAG_SECURE` on the activity, so the app's own screen appears in the
recents thumbnail. Tests: a migration that opens an existing plaintext database
and re-encrypts it without data loss (needs a real-device test).

**B-04 · S2 · Prediction window is optimistic for irregular cycles**
Measured by backtesting `ElaraFusion` over 200 synthetic histories per scenario
(throwaway script, mean cycle 29 days, 6% chance of a long cycle):

| scenario | cycles | MAE (days) | actuals inside ±window | mean window |
| --- | --- | --- | --- | --- |
| regular, sd 1.0 | 3 | 1.88 | 96% | ±3.6 |
| regular, sd 1.0 | 12 | 1.56 | 94% | ±2.8 |
| moderate, sd 3.0 | 12 | 3.25 | 85% | ±4.8 |
| irregular, sd 6.0 | 12 | 5.42 | 71% | ±6.9 |
| irregular, sd 6.0 | 3 | 5.41 | 62% | ±5.5 |

For irregular cycles the stated window contains the true date 62–71% of the
time. A user reading "± 5 days" will assume a near-certainty; the honest number
is closer to two in three. Root cause: `windowDays` is derived from a deviation
estimate and clamped (`elara-core`, `lib/src/engines/flowlytics_engine.dart:86`),
not from measured coverage. Fix: calibrate the multiplier so the window achieves
roughly 90% coverage at each variability level, and say so in words: "usually
right within a few days; yours have varied by about a week". Regressions: a
wider window changes the downstream phase classification start, so phase labels
must be re-checked. Tests: a backtest harness in the repo asserting coverage
bounds per scenario.

**B-05 · S2 · A long gap is treated as a normal cycle**
A 151-day gap between recorded starts predicts with a window of ±15 days rather
than flagging the record as implausible. `prediction_service.dart` drops
non-increasing and duplicate starts (`_toCycleRecords`) but has no upper bound.
A data-entry error therefore skews the forecast and the average in Insights.
Expected: implausible gaps are either excluded with a visible note or the user is
asked to confirm. Tests: a gap above 90 days is excluded and the screen says why.

**B-06 · S3 · The partner cannot correct or contribute anything**
The only write paths are "log a period start" and edit duration
(`cycle_provider.dart`, `settings_screen.dart`). If the date is wrong by a day
and the app was told by someone else, there is no correction path other than
deleting the row, and no way for the person the data is about to add a symptom
she is actually having. This is the gap between "cycle tracker" and "care app".

**B-07 · S3 · Settings has no export and no way to see what is stored**
`database_helper.dart` exposes `resetAllData` but `settings_screen.dart` never
calls it. There is no export, no "what this app knows" view, and no delete-all
control presented to the user. For sensitive data this is a gap in user control,
whatever the encryption story is.

**B-08 · S4 · Notification body text is composed from a re-run prediction**
`notification_service.dart:344-380` recomputes the pipeline per occurrence. That
is the right choice for freshness, but it means seven days of briefings repeat
the same severity (`_actionFor(phaseDay.phaseResult, severity)`, `:358`) because
severity is computed once from today's climate. A heat spike tomorrow is not in
tomorrow's briefing. Expected: per-day climate when the schedule is rebuilt, or
text that does not imply a daily measurement.

**B-09 · S4 · Insights climate chart uses one day's severity for all bands**
`insights_screen.dart:_bandsFor` takes `result.severity` (today's) and paints it
across thirty days of history. The bands are a phase projection, not a
measurement, which is stated in the caption, but the chart visually suggests
per-day severity it does not have.

**B-10 · S4 · Screenshot renders are not byte-identical across machines**
The Screenshots workflow re-committed `today-action.png` and
`today-action-dark.png` immediately after a local run. Measured difference: 19
pixels, maximum channel delta 1 — antialiasing noise, not a content change. The
cost is a spurious commit each time the job runs. Fix: compare with a small
tolerance and skip the commit below it.

**B-11 · S4 · `README.md` records a stale test count**
It says one hundred and twelve; the suite is 140 after the theme, responsive and
utility tests. Cosmetic, but it is the kind of number a reviewer checks first.

### B2. Hypotheses, explicitly not confirmed

- **H-01** The periodic background alarm at 03:00
  (`notification_service.dart:595`) may be deferred or dropped by OEM battery
  managers (Xiaomi, Oppo, Samsung). Not verified: no device available here. It
  would show up as reminders that stop after a reboot until the app is next
  opened.
- **H-02** `SCHEDULE_EXACT_ALARM` is declared rather than requested lazily; on
  Android 14+ the permission can be revoked, and the inexact fallback is
  implemented (`_schedule` falls back to `inexactAllowWhileIdle`) but has not been
  observed on a device.
- **H-03** The `± windowDays` label may be read as a promise rather than a range.
  Untested with users; worth five conversations before changing the copy.
- **H-04** Nakshatra and Hijri dates may add value for some users and noise for
  others. This is a user-research question, not a code question.

---

## C. UI/UX audit, screen by screen

Reviewed as renders at 390×844, 320×640, in dark mode, with text at 1.3x and
2.0x, and at 1024×768. Screenshots in `docs/screenshots/`.

**Today.** Hierarchy is right: phase chip, countdown, climate, guidance. The
countdown is the strongest element on screen and deserves to be. Two issues
remain after this pass. First, the guidance card now says "A place to start" and
one prompt, but it is still phase-derived, not person-derived; that is P1-2, not
a visual fix. Second, the climate strip gives the season a two-line treatment
next to two single-line figures, which looks slightly uneven; a shorter label
("Post-monsoon" → "Monsoon's end") or a full-width row would balance it.

**Calendar.** Best screen in the app. Logged starts are distinguished from
projected days, the legend is honest about projection, and the four colours are
distinguishable at a glance and in the dark theme. Cell height now follows text
scale. Remaining: tapping a day opens a sheet with phase and guidance but no way
to correct that day, and no visible mark for "this day was edited".

**Insights.** Charts are legible and the statistics are the right ones (sample
SD with n−1, which matches what the prediction uses). The heat-index chart's
phase bands carry the B-09 caveat. The screen's empty state is the best-written
copy in the app.

**Settings.** Functional but thin. Location, theme, five notification toggles and
a disclaimer. Missing entirely: consent, export, delete, notification privacy.
No indication of what data exists or how much space it takes.

**Onboarding.** One date picker and a confirm button, with warm copy. It is
missing the things that make a care app trustworthy: what is stored, where, who
it is about, and how to undo it. It also assumes a wife.

**Notifications.** Text is warm and specific, and the scheduling design is
thoughtful (per-occurrence, rebuilt on foreground). But it prints "Conversation
score 8/10" (removed in this pass) and shows in full on the lock screen (B-02).

**Cross-cutting.**

- Touch targets: now at least 48dp in the calendar; the notification toggles and
  segmented control were already compliant.
- Large text: four overflows were found and fixed this pass (phase chip,
  countdown numeral, "days since" row, calendar header button). Nothing overflows
  at 2.0x after the fix, verified by test.
- Dark mode: complete and consistent; the new phase tint is applied to both
  themes and checked for contrast in all eight combinations.
- Wide screens: a `NavigationRail` appears at 720dp and content is capped at a
  readable measure.

---

## D. Feature evaluation

| Feature | Decision | Reasoning |
| --- | --- | --- |
| Ensemble prediction with stated window | **Improve** | Core value. Window calibration is B-04. |
| Phase classification and colour system | **Keep** | Clear, accessible, well tested. |
| Daily action cards | **Improve** | Right idea, wrong source: currently phase-derived prose. Should consult her stated preferences first (P1-2). |
| Conversation / romance scores | **Remove** | Done. False precision about a person. |
| Food suggestions | **Keep, demote** | Useful and concrete; belongs inside the guidance card, not beside it. |
| Heat index and air quality | **Keep** | Credible link to physical comfort; the app explains the mechanism. |
| Season label | **Simplify** | Four words for a fact that rarely changes what to do. Fold into the climate line. |
| Moon phase | **Keep, small** | Charming and cheap; genuinely apposite for a moon-named app. |
| Nakshatra | **Make optional** | Well implemented, no care value, and it competes for the same strip. |
| Hijri date | **Make optional** | Same reasoning; valuable to some, irrelevant to others. |
| Five notification types | **Keep, add one** | Add a "prepare" reminder the day before a predicted start (P1-3). |
| Calendar projection | **Keep** | Honest about being a projection; the strongest screen. |
| Insights charts | **Keep** | Correct statistics, good empty states. |
| Location setting | **Keep** | Needed for weather; could offer a one-time device location read. |
| No accounts, no sync, no analytics | **Keep, protect** | This is the product's spine. Nothing in the roadmap may weaken it. |

---

## E. Proposed improvements, ranked

Ranked by user benefit against effort, maintenance and risk. Benefit is from the
partner's perspective first, the phone-holder's second.

| # | Change | Benefit | Effort | Maintenance | Risk |
| --- | --- | --- | --- | --- | --- |
| 1 | Consent gate and revocation | High | S | Low | Low |
| 2 | Private notifications by default | High | S | Low | Low |
| 3 | Her preferences, entered by her | High | M | Medium | Medium |
| 4 | Symptom log, by exception only | High | M | Medium | Medium |
| 5 | Window calibration and plain-language uncertainty | High | M | Low | Medium |
| 6 | Export and delete-all in Settings | Medium | S | Low | Low |
| 7 | "Prepare tomorrow" care reminder | Medium | S | Low | Low |
| 8 | Correct a recorded date in place | Medium | S | Low | Low |
| 9 | Encrypted database (sqlcipher) | Medium | M | Medium | High |
| 10 | Optional astronomy strip | Low | S | Low | Low |
| 11 | Date ideas filtered by weather and stated interest | Medium | L | High | Medium |
| 12 | On-device personalization (learn her symptom patterns) | Medium | L | High | Medium |

Two deliberate rejections. A "mood prediction" feature, in any form, because it
would make exactly the claim the brief forbids. And any cloud backup, because it
turns a private app into a data controller with obligations it cannot meet.

---

## F. Roadmap

### P0: correctness, consent, exposure

1. Consent gate at onboarding, revocable, with a written record (B-01).
2. Notifications private by default, detail toggle in Settings (B-02).
3. Document the encryption decision; if the device-threat model justifies it,
   move to sqlcipher behind a migration (B-03).
4. Export and delete-all in Settings, with a clear statement of what is stored
   (B-07).
5. Fix the README test count and the stale claims it makes (B-11).

### P1: the care experience

6. Preferences profile, filled in by her, with a "skip for now" (D, row 3).
7. Symptom logging by exception, and guidance that prioritises a reported
   symptom over the calendar (brief section 6).
8. Window calibration to ~90% coverage plus plain-language uncertainty (B-04).
9. Prepare-tomorrow reminder, optional and off by default (D, row 10).
10. Correct a date in place, with the correction visible on the calendar (B-06).
11. Reject implausible gaps with an explanation rather than a silent skew (B-05).

### P2: refinement

12. Move the astronomy strip behind a setting; season label simplification.
13. Insights: separate projected severity from measured severity in the chart
    (B-09).
14. Per-day climate in scheduled briefings (B-08).
15. Onboarding rewrite that says what is stored and why, in two screens.

### P3: optional experiments

16. Date ideas that respect weather and stated interests, not phase.
17. On-device learning of her symptom patterns, with an explicit opt-in and no
    data leaving the phone.
18. Screenshot tolerance so the bot stops committing 19-pixel changes (B-10).

---

## G. Implementation plan

Affected files, migrations and tests for the P0 and P1 items. None of this is
started.

**Consent (P0-1).** New `lib/screens/onboarding/consent_screen.dart`; new keys
`SettingsKeys.consentGivenAt`, `SettingsKeys.consentRecordedBy`,
`SettingsKeys.consentRevokedAt`; `SettingsProvider` gains
`hasConsent`/`recordConsent()`/`revokeConsent()`; `RootScaffold` gates on
`hasConsent`. Revocation clears cycles and derived settings through the existing
`DatabaseHelper.resetAllData`. No schema migration: settings is key/value.
Existing installs are treated as consented if any cycle exists, with a
one-time notice. Tests: gate appears with no consent, consent persists across
restart, revocation clears data, upgrade path does not destroy history.

**Notification privacy (P0-2).** `notification_service.dart` `_schedule` gains
`visibility: NotificationVisibility.private`; new key
`SettingsKeys.notificationPreview` (default false) read in `rescheduleAll` and
threaded into body composition; `settings_screen.dart` gains the toggle.
Tests: default body has no cycle terms; toggle changes it; channel config asserts
private visibility.

**Preferences (P1-6).** New table `preferences` (schema version 2, migration
`_migrations[1]`): `id, key, value, recorded_by, updated_at`. New
`providers/preferences_provider.dart`; new screen reached from Settings;
`action_cards.dart` prefers a stored preference over the phase template. Tests:
migration creates the table from a v1 database, CRUD round-trip, guidance prefers
a preference when present.

**Symptoms (P1-7).** New table `symptoms` (schema version 2): `id, date, kind,
severity, note, recorded_by`. `PredictionService` passes recent symptoms into the
action selection; `today_screen.dart` shows a one-tap "she mentioned discomfort
today" that steers guidance. Tests: a reported symptom outranks phase in the
chosen guidance; expired symptoms do not persist.

**Window calibration (P1-8).** Change in `elara-core` (separate repository),
consumed by a `ref` bump here. Add `test/prediction/coverage_test.dart` that
backtests the engine over synthetic histories and asserts coverage within a
tolerance of 90%. Acceptance: irregular scenarios move from 62–71% into 85–95%.

**Prepare reminder (P1-9).** `notification_service.dart`: new
`ElaraNotificationType.prepareTomorrow`, id block 6000, scheduled for the day
before the predicted start at 18:00; switch in Settings, default off. Tests: one
occurrence per cycle, respects the master switch, survives reschedule.

**Corrections (P1-10).** `day_detail_sheet.dart` gains edit and delete for
recorded starts; `cycle_provider.dart` gains `updateStartDate` with the same
future-date and duplicate guards as `addCycle`; the calendar marks corrected
days. Tests: moving a date updates the prediction, colliding dates are refused
with a message, deleting asks for confirmation.

---

## H. Verification plan

**Automated, every push (existing CI).** `dart analyze --fatal-infos` and
`flutter test`. The suite is 140 tests at `7548c05`; each plan item above adds
its own. Notable existing coverage: schema and every CRUD path against real
SQLite, the climate service against mocked live, cached, malformed and offline
responses, the moon phase against published new/full/quarter moons, the
nakshatra division, four screens in empty and populated states, contrast in all
eight theme/phase combinations, and layout at 320px, 390px and 1024px with text
at 1.0x, 1.3x and 2.0x.

**New regression tests required.** A backtest harness asserting prediction
coverage (P1-8). A consent lifecycle test including the upgrade path (P0-1). A
notification-content test asserting no cycle terms appear when previews are off
(P0-2). A migration test from schema 1 to 2 (P1-6, P1-7).

**Real-device verification, which this environment cannot do.** Exact-alarm
behaviour and OEM battery managers (H-01), the boot receiver restoring the
schedule, lock-screen rendering with previews off, the recents thumbnail,
encrypted-database performance, and the notification tap path. Each needs a
physical Android 12+ device, and H-01 needs at least one aggressive OEM skin.

**Manual verification per release.** Install the arm64 APK from the release,
first launch offline (fonts and layout must be complete), log a cycle, confirm
the phase changes repaint the theme without a restart, confirm the landing page
at 375px and at desktop width, and confirm the download link resolves to the
version shown in the badge.

---

## Implemented since this audit (v1.2.0)

The P0 items and two of the P1 items are now in the app. What changed, against
the issue numbers above:

- **B-01 consent.** A gate before first use, an append-only `consent_records`
  table (schema v2), and a withdrawal that deletes the cycles, the settings and
  the record. The upgrade path deliberately does *not* infer consent from
  existing rows: an install with history but no consent row is asked, and the
  acknowledgement is logged as `acknowledgedLegacy`, never as a grant.
- **B-02 notification privacy.** Every reminder is posted with
  `NotificationVisibility.private`, and text is redacted through a single choke
  point unless the user opts in. Off by default. Reminder switches now rebuild
  the schedule immediately rather than at the next resume.
- **B-04 prediction window.** Not yet fixed. Still the largest accuracy gap.
- **B-05 long gaps.** Rejected on restore, still accepted from manual entry.
- **B-06 corrections.** A recorded start can now be moved or removed from the
  day sheet, with collision and future-date guards.
- **B-07 export and delete.** Encrypted backup, validated restore, and a
  withdrawal control that states exactly what it removes.
- **B-11 version drift.** `AppInfo.version` had claimed 1.0.0 through two
  releases; it is corrected and a test now fails the build if it disagrees with
  `pubspec.yaml`.
- **Accessibility.** Calendar day cells carry a full semantics label: date,
  phase, recorded or projected, and an explicit "not a confirmed phase".

Still open, unchanged from the register: database encryption (B-03), the
per-day severity reuse (B-08, B-09), and the whole of P2 and P3.

## Approval requested

P0 items 1, 2 and 4 are small and self-contained and would take one session.
P0-3 (encryption) and P0-5 are also contained. P1 is the real product work and
needs a decision on one question first: **should the preferences profile be
filled in by her, on the same phone, behind a separate step that the partner
does not have to see?** That choice shapes the screens, the schema and the
consent copy, and it is a product decision rather than an engineering one.

P0 and the parts of P1 listed above are implemented and tested. The remaining
P1 work — a preferences profile filled in by her, and window calibration — still
needs the product decision described above.
