# Prediction reliability: what was checked, and what was changed

Date of this pass: 2026-11-08. Engine: `elara-core` at the revision pinned in
`pubspec.yaml`. **No prediction algorithm was changed in this pass** — neither
in `elara-core` nor in this repository. The only behavioural change is an input
guard (section 4) that refuses an entry no cycle could have produced.

## 1. What the app claims, and where the numbers come from

The app shows a predicted next-period date, a window in days around it, and a
phase for each day. The claims the interface is allowed to make are:

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

## 3. The finding worth recording

Consistently long cycle spacing is not tracked at all. Probing the ensemble
with evenly spaced starts:

| True spacing | Predicted length | Window | Confidence |
|---:|---:|---:|---:|
| 30 d | 30 d | ±2 | 0.89 |
| 45 d | 44 d | ±4 | 0.49 |
| 60 d | 37 d | ±14 | 0.10 |
| 75 d | 38 d | ±18 | 0.07 |
| 90 d | 41 d | ±23 | 0.06 |
| 120 d | 41 d | ±29 | 0.04 |

Two things are going on, and only one of them is a problem:

1. **Correctly signalled uncertainty.** Confidence collapses (0.89 → 0.04) and
   the window widens (±2 → ±29). The app surfaces both, so a user with a long
   cycle sees a wide window and an unclassified/low-confidence phase rather
   than a firm date. That behaviour is honest and was left alone.
2. **A window around a shrunken point.** The point estimate is pulled toward a
   plausible range, so for 60-day spacing it sits near 37 days — about 23 days
   early — and a symmetric ±14-day window never reaches the actual date. The
   low confidence is right; the *placement* means the interval covers almost
   nothing. This also appears as the 21-day MAE / 100% gross-miss row above,
   which is the realistic case of someone recording every other period.

Changing this means changing `elara-core` (the fusion point estimate or an
asymmetric window), which is a different repository with its own backtest gates
(`test/backtest/EXPERIMENT_PLAN.md` and `IMPROVEMENT.md`). Under this
milestone's rules — "verify before changing algorithms", "improve calibration
only where evidence supports", "handle any `elara-core` change explicitly with
its tests" — the correct action here was to measure, record and stop, not to
patch a heuristic on synthetic evidence.

**Recommendation for a future pass, with its own gate:** evaluate an asymmetric
window (or a window anchored to the lower plausible bound) for cycles whose
recorded lengths exceed ~45 days, on the real cohort, against the existing
window; adopt only if it improves coverage without widening the radius for
typical users.

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
- Long-cycle placement (section 3) is a known, recorded weakness.
- The confidence score is heuristic and is displayed as such.
- Nothing here is clinical validation, and the app says so in-app.
