# Production hardening: what changed, what it fixes, what is still open

Date: 10 November 2026. Branch: `fix/production-hardening`, five commits on top
of `main` at `e2d7780`.

Everything here was run, not assumed: Flutter 3.47.9 / Dart 3.13.7 (the versions
`ci.yml` pins), `dart analyze --fatal-infos` clean, and **508 tests passing**
where `main` was passing 472 and failing 9.

---

## 0. The state `main` was actually in

| Claim in the repo | Reality on `main` |
|---|---|
| "Every image is a real render of the running app" | The APK could not be built: `AndroidManifest.xml` contained committed merge-conflict markers |
| "clears WCAG AA in all eight theme × phase combinations, which `test/theme/phase_theme_test.dart` asserts rather than trusts" | 5 of 8 failed the assertion the README cites (worst: 3.38:1 on the light luteal fill) |
| "it survives a 2× font scale" | The phase circle clipped its own label at 2.0× by 2 px — on the Today screen, in the largest element on it |
| "no server to hold anyone's health history" | Android Auto Backup was uploading `elara.db` to the user's Google Drive, by default |
| CI is the gate | CI was green throughout, because it never parsed an Android file |

None of those are opinions. The first is `git grep '<<<<<<<'`; the rest are test
runs and a manifest read.

---

## 1. The five commits

### `17075ef` — make the shipped build readable, unclipped and honest
- **Contrast.** Ink on an accent-filled control was a fixed `#1A2E4A` whatever the
  fill; it is now chosen per fill and pushed until it clears AA. Accent text was
  checked against the card only, so labels landed at 4.08:1 on the page behind
  it; inks now clear every surface they can land on. *(Fixes 5 failing tests.)*
- **Text scale.** The 150 dp phase circle needed 152 dp of content at 2.0×. It now
  grows with the text scale, bounded by the page width, with a flexible label.
  *(Fixes 2 failing tests.)*
- **About.** The update result had lost the release notes, the file size, and the
  sentence *"Elara will not install this for you"* — which matters because this
  app ships as an APK from a GitHub release and the user does the installing.
  Restored as a sheet.
- **A lie removed.** A 503 from GitHub was being described to a phone with four
  bars as "you are offline". The service's own reason is now shown, and the
  offline test uses a request that actually fails.

### `7cf1405` — stop predicting when a prediction would be a fabrication
The physiology. Three states in this app's real population have no ovulatory
cycle to estimate, and the app was confidently describing one to all of them:

- **Hormonal contraception** — pills, implant, injection, hormonal IUDs. Around
  six in ten married women in Bangladesh use a modern method and oral pills are
  the most common, so this is plausibly the majority case, not an edge case.
- **Pregnancy, a loss, after a birth** — the old behaviour counted days through a
  miscarriage and then said the period was late.
- **Perimenopause**, or simply not wanting a date.

Three modes (predicting / hormonal contraception / paused with an optional
reason). One gate — `PredictionService.isPredicting()` — because Today, the
calendar, the day sheet and the reminder scheduler all funnel through `predict()`.
Notifications stop rather than naming a phase the app has said it cannot see; the
calendar falls back to recorded days; Today shows a quiet screen where the claims
go and **the care stays** (her bleeding log, symptoms, his notes, reminders,
weather, and suggestions built from what she has said, which the screen says out
loud).

Two failure-direction choices, made deliberately: an unreadable stored mode is
**paused** (silence is the safe failure for a claim about a body), while a
settings read that errors outright is **predicting** (one transient database
error must not disable the app).

### `8955983` — a build that exists, a database that stays, an engine that stays put
- Manifest conflict markers resolved (both files).
- `allowBackup="false"`, `fullBackupContent="false"`, `dataExtractionRules`, and a
  rules file excluding `root`/`file`/`database`/`sharedpref`/`external` from both
  cloud-backup and device-transfer.
- `FLAG_SECURE`, so the app is out of the recents thumbnail and out of `adb
  screencap`; gated on a `BuildConfig` field that defaults to false so the
  screenshot pipeline is the only build that can be captured.
- `targetSdk` 34 → 36 (Play has refused below 36 since 31 August 2026).
- `elara_core` pinned to a commit instead of `ref: main`.
- **New `tool/check_manifest.py`**, run by `ci.yml` and `android-ci.yml`: fails on
  conflict markers anywhere, Android XML that does not parse, any regression of
  the three backup attributes, or a targetSdk below the Play floor. It found the
  second conflict in `docs/CI_PERFORMANCE.md` on its first run.
- **New `test/content/claims_test.dart`**: fails the build if a shipped string
  says "safe day", promises someone cannot get pregnant, calls ovulation
  confirmed, or claims a diagnosis. Denials are allowed — "Elara does not
  diagnose anything" is the sentence the test protects.
- `docs/PRIVACY_MODEL.md` gains section 4a, stating what was true and what is now
  true, rather than quietly editing section 1.

### `dc3a812` — say what the recorded history implies about the date above it
Two notes under the estimate: a wide window named as a range, and a latest
interval about twice her own median named as what it usually is — an unrecorded
period. Both computed from her own history, never against a textbook 28-day
cycle, and the gap note fades as the median moves. It changes no date, window or
confidence; changing the point estimate is a different job with its own gate.

### `3bc06a0` — paint the rounded fill, and let the screenshot finish its fade
Two defects nothing threw on, so nothing caught them, and every image in `docs/`
recorded them as normal:

- `ElaraAnimatedColor` painted a plain rectangle and the **child** drew the
  rounded shape on top in the same colour, so the shape was invisible: the phase
  circle on Today was a 150×150 square, and the phase chip was square-cornered.
  It now takes and paints the radius.
- The screenshot harness advanced the real clock but only 50 ms of the fake one,
  so every capture landed a few frames into the entrance fade: the Today heading
  at ~25% opacity, the chip's fill halfway between two phase colours. The
  screenshots are regenerated, and the three new quiet-mode screens are captured
  in the same pass.

Worth stating plainly, because it is the pattern in this whole pass: the suite
was green, the README said "real render of the running app", and the app was
drawing the wrong shape in the wrong colour.

### `elara-core` — `fix/honest-dispersion` (patch supplied separately)
`FlowlyticsEngine` filtered cycle lengths to 15–50 days **and then computed the
standard deviation from the filtered list**. A cycle length is exactly the
observation that makes a cycle irregular, so dropping it made an irregular
history report the uncertainty of a regular one: a 63-day interval produced a
two-day window.

- the band now guards location only;
- dispersion is a sample SD (n−1) over every completed interval;
- when every recorded cycle is outside the band, the band is inapplicable and the
  observations are used — so a regularly 57-day cycle predicts 57 days instead of
  the 28-day baseline (this closes the long-cycle finding in
  `docs/PREDICTION.md` §3 for that component);
- the window is capped at 60 days rather than 4.

Core: 122 tests pass, analyzer clean. Point estimates for in-band histories are
unchanged; confidence bands move one step for three-cycle histories because
Bessel's correction now applies.

---

## 2. To land this

```sh
# 1. the app
git checkout fix/production-hardening
flutter pub get
dart analyze --fatal-infos
flutter test                      # 508 passing
python3 tool/check_manifest.py

# 2. the engine
cd ../elara-core && git am ../elara-core-flowlytics-dispersion.patch
dart test                         # 122 passing
# push, then bump the pinned SHA in elara-app/pubspec.yaml in its own PR
```

Then re-test **on a real API 36 device**, because raising `targetSdk` changes
exact-alarm and foreground-service behaviour and the failure mode is silent:
reminders simply stop. MIUI/HyperOS and ColorOS first — they are the phones this
app will actually run on, and their background killers are the most aggressive.

---

## 3. What is still open, honestly

Not done, in the order I would do it:

1. **Bangla.** `assets/fonts/` bundles Hind Siliguri, a Bengali-first typeface,
   and `lib/` has zero `flutter_localizations` and zero ARB files. The app shipped
   the typeface and not the language, in a country where the app's whole value is
   careful wording. This is the single largest remaining gap.
2. **The state-space model.** Missing logs are still scored as long cycles; the
   new note *labels* that, it does not fix it. The fix is a latent-state model
   with "no entry made" as a modelled outcome and an asymmetric interval, gated on
   its own backtest.
3. **The ensemble ablation.** 3.03 MAE vs 3.13 for its best member, inside its own
   bootstrap interval, while a plain median of prior cycles scores 2.98 on the
   ≥1-cycle subset. Publish the ablation; keep the ensemble only if it clears.
4. **Spotting, LH strips, cervical mucus, BBT.** The engine already understands
   all four (`DripEngine`, `FlowSymptoms.spotting`); no UI collects any of them,
   and the highest-value input in this product category is one tap a day.
5. **A prospective local cohort.** Utah 1990–2013 is methodologically excellent
   and demographically irrelevant to a Bangladeshi product. Utah is also CC BY-NC,
   which is a licensing problem for a shipped default constant.
6. **Database encryption** — unchanged, still plain SQLite, per
   `docs/PRIVACY_MODEL.md` §4. Physically seizing an unlocked phone still reads
   everything.
7. **R8/minify** is still off. The fix is a keep-rule plus a smoke test on the
   minified artifact, not another year of leaving it off.
