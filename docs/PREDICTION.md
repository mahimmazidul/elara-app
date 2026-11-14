# Prediction reliability: what was checked, and what was changed

First pass: 2026-11-08. Second pass: 2026-11-10, in which the engine **was**
changed (section 3), for the reason recorded there. Engine: `elara-core` at the
revision pinned in `pubspec.yaml`.

The first pass changed no algorithm — neither in `elara-core` nor in this
repository — and its only behavioural change was an input guard (section 4) that
refuses an entry no cycle could have produced. The second pass measured the
weakness that pass recorded, then fixed it in `elara-core` (`9d35ae7`).

## 1. What the app claims, and where the numbers come from

The app shows a predicted next-period date, a window in days around it, and a
phase for each day. The engine is `elara-core` — Elara's own ensemble, developed
from OpenCiclo and Flowlytics as upstream sources, pinned to a commit in
`pubspec.yaml` so the estimates a release ships are reproducible from this
repository. The claims the interface is allowed to make are:

- the date is an **estimate** derived from recorded history;
- the window is an **uncertainty radius**, not a confidence interval with a
  stated probability;
- the confidence figure the engine returns is a **heuristic score**, not a
  calibrated probability. `elara-core`'s fusion code says so itself
  (`ElaraFusion` — "Scores are not clinically calibrated").

The only evaluation on real data is `elara-core`'s own walk-forward backtest on
the Utah/Creighton cohort (`test/backtest/REPORT.md` in that repository). This
app does not re-derive those numbers, does not hardcode them in the interface,
and does not describe its intervals as validated.

## 2. What was verified in this pass

A synthetic-cohort report was added at
`tool/prediction/calibration_report.dart`, writing
[`docs/PREDICTION_CALIBRATION.md`](PREDICTION_CALIBRATION.md). It measures, per
cohort: MAE, median absolute error, share within ±2 days, exact-day rate, mean
window radius, share of outcomes inside the returned window, gross misses
beyond 7 days, and signed bias.

Headline results (80 synthetic people × 36 cycles per cohort):

| Cohort | MAE | Mean window | In window | Gross misses |
|---|---:|---:|---:|---:|
| Very regular (28 ± 1) | 0.71 d | ±2.1 | 100.0% | 0.0% |
| Typical (30 ± 3) | 1.82 d | ±3.5 | 94.7% | 0.0% |
| Irregular (32 ± 8) | 4.41 d | ±6.3 | 78.1% | 15.8% |
| Irregular and long (45 ± 14) | 8.03 d | ±8.1 | 58.4% | 48.1% |
| Long gap in history | 4.41 d | ±3.5 | 91.8% | 2.9% |
| Mistyped dates (two) | 3.77 d | ±5.1 | 87.4% | 11.8% |
| Alternating records (60-day spacing) | 21.20 d | ±14.1 | 10.8% | 100.0% |

These are **synthetic** cohorts. They show how the engine responds to a
distribution; they say nothing about calibration for real users.

## 3. The finding worth recording, and its fix

The first pass found that consistently long cycle spacing was not tracked at
all. Six evenly spaced starts produced a point estimate pulled toward a plausible
range — 60-day spacing predicted 37 days, ±14 — so the interval was symmetric
around a date about 23 days early and covered almost nothing. Confidence was
right to collapse; the *placement* was the defect. The realistic form of that
case is someone recording every other period, which appeared in the table above
as a 21-day MAE with 100% gross misses.

The cause was one line of thought, not a modelling choice: the dispersion used to
size the window was measured over the recent intervals **that fall inside the
engine's plausible band**, and only those. The filter that produced the estimate
also defined away the noise in it, so an every-other-period history looked
internally consistent.

`elara-core` `9d35ae7` measures dispersion over **every** logged interval while
the band still guards the location of the estimate; the window is
`ceil(SD).clamp(1, 60)` on the sample (n − 1) standard deviation. The probe in
`tool/prediction/calibration_report.dart` now generates the table below, so it
can be reproduced rather than remembered:

| Recorded spacing | Predicted length | Window | Confidence |
|---:|---:|---:|---:|
| 30 d | 30 d | ±2 | 0.89 |
| 45 d | 44 d | ±4 | 0.49 |
| 60 d | 58 d | ±6 | 0.36 |
| 75 d | 73 d | ±7 | 0.29 |
| 90 d | 88 d | ±9 | 0.25 |
| 120 d | 117 d | ±12 | 0.19 |

And on the walk-forward cohorts, same seed, before → after:

| Cohort | MAE | In window | Gross misses |
|---|---|---|---|
| Missing records | 21.20 → **3.58** d | 10.8% → **93.5%** | 100.0% → **9.4%** |
| Long gap | 4.41 → 4.39 d | 91.8% → 96.8% | 2.9% → 2.9% |
| Irregular | 4.41 → 4.41 d | 78.1% → 83.2% | 15.8% → 15.8% |
| Typical range | 1.82 → 1.83 d | 94.7% → 95.4% | 0.0% → 0.0% |
| Very regular | 0.71 → 0.74 d | 100.0% → 100.0% | 0.0% → 0.0% |

The window widened where the history is genuinely uncertain and barely moved
where it is not: ±2.1 → ±2.2 days for the very-regular cohort. The point estimate
on an every-other-period history is still about three days early; what changed is
that the range now covers it.

The remaining, unmeasured recommendation stands: an **asymmetric** window for
long cycles might recover the last of that bias, and should be evaluated on the
real cohort before adoption, not on synthetic evidence.

## 4. Behaviour the app already has, and what it prevents

- **Recorded vs estimated is distinct everywhere**: a confirmed start is shown
  as recorded; projections are labelled estimates with their own wording.
- **Overdue is stated, not hidden.** A pending start moves the countdown to
  "late" with the number of days, rather than silently rolling the prediction
  forward.
- **Corrections refresh the prediction.** Editing or deleting a start rebuilds
  the timeline, which is the verified behaviour in
  `test/providers/cycle_correction_test.dart`.
- **No phase is inferred for a day the timeline cannot place.** Those days are
  shown as unclassified with an explanation, rather than being filled in by
  interpolation (`utils/phase_timeline.dart`).
- **Implausible intervals are refused.** A start fewer than ten days after the
  previous recorded start is rejected with the gap named and a suggestion to
  correct the earlier date instead; logging the same day twice updates that
  entry's duration. Newly added in this pass, with tests in
  `test/providers/cycle_correction_test.dart`. Long gaps are *not* rejected:
  a long cycle is a legitimate pattern, and refusing it would push users to
  enter a date they know is wrong.

## 5. Limits that must not be papered over

- No real-user calibration was performed in this pass, and the synthetic table
  must not be presented as one.
- Long-cycle placement improved in `9d35ae7` but is not solved: the point
  estimate on an every-other-period history is still a few days early, and the
  window carries the correction rather than the model.
- The confidence score is heuristic and is displayed as such.
- Nothing here is clinical validation, and the app says so in-app.
