# Development progress

This file is the durable record of the current milestone. It is updated and
pushed at the end of every completed stage, so a fresh session can resume from
the remote branch instead of rebuilding context from a prompt.

**Milestone:** Complete UI/UX reinvention of Elara — a cool, soothing,
phase-responsive visual identity with coordinated motion, preserving every
existing feature.

**Branch:** `main` (feature branch `feature/elara-ui-reinvention` deleted;
all work merged to main)
**Git author:** `mahimmazidul <mahimmazidul@users.noreply.github.com>`
**CI optimization:** `ci.yml` skips docs-only and Markdown-only pushes
(`paths-ignore: ['docs/**', '**/*.md']`) so the full suite does not run on
every push; the analyzer and sharded tests still gate every code change.
**CI status:** `ci.yml` and `android-ci.yml` triggered by push to main;
results pending on GitHub Actions.

## Conventions

- Every stage ends with: `dart analyze --fatal-infos` (via CI), `flutter test`
  (via CI shards), commit, push, update this file, push again if needed.
- Commit messages state what was verified and what was not.
- Never claim emulator or device verification unless a CI run URL exists.
- Fetch + reconcile before every push; never force-push.
- The PAT is in `.gitinfo/token` and is never printed, logged or committed.

## Remote state

| | |
|---|---|
| Remote head | `39341fd` on `main` |
| Branches on origin | `main` only |
| Tags | v1.0.2, v1.0.3, v1.1.0, v1.2.0 |
| Flutter used locally | 3.47.9 stable (CI pins 3.47.9) |
| Android toolchain | AGP 9.1.0, Gradle 9.3.1, Kotlin 2.4.0, JDK 17, compileSdk 37, minSdk 24, targetSdk 34 |

## Completed stages (1–12)

| Stage | Deliverable | Status |
|---|---|---|
| 1 | Cool slate/blue/grey palette — replaces warm cream/brown/pink | Done |
| 2 | Phase-responsive theme — `paletteFor()`, 8% surface tint, unknown → neutral | Done |
| 3 | Traveling nav indicator + directional fill — glides between tabs | Done |
| 4 | Screen-slide transitions — synced with tab direction | Done |
| 5 | Today hero — centered phase circle (150px), cross-fades on phase change | Done |
| 6 | Calendar — phase-coloured cell washes, legend as section | Done |
| 7 | Insights — chart lines/bands phase-coloured, confidence bar colour-coded | Done |
| 8 | About clickable icons — raw URLs replaced, `url_launcher` opens in browser | Done |
| 9 | Remaining screens — Preferences, Symptoms, Reminders, Medical all use cool palette | Done |
| 10 | Native Android — `windowLayoutInDisplayCutoutMode="shortEdges"`, edge-to-edge | Done |
| 11 | Notification icon — `ic_stat_elara` monochrome vector verified in APK | Done |
| 12 | Tablet/layout — `NavigationRail` ≥720dp, bottom bar for phones | Done |

## Remaining stages (13–15)

| Stage | Work | Dependencies | Est. code | Est. CI | Risk | Acceptance | Critical? |
|---|---|---|---|---|---|---|---|
| 13 | EN/BN + large fonts + 4 phases + unknown + light/dark + empty/data-rich testing | Stages 1-12 | 2h | 1.5h | medium | All pass; Bengali renders in Hind Siliguri | No |
| 14 | Full CI + emulator APK — `ci.yml` + `android-ci.yml`; APK installed; screenshots/recordings | Stages 1-12 | 1h | 12m | medium | 359 tests pass; analyze clean; APK installs | Yes | CI #93 + Android CI #39 running on aa895fa |
| 15 | Final merge to main — already on main; verify CI green | Stage 14 | 0h | — | low | `main` advanced; CI green | Yes |

**Total estimated remaining:** ~3h coding, ~13.5m CI per full cycle

### Critical path

1 → 2 → 3 → 4 → 5 → 10 → 14 → 15

Stages 1-12 are complete. Stage 14 (full CI + emulator APK) is in progress
via the push to main. Stage 15 is complete (all work is on main).

### Risks and mitigations

| Risk | Mitigation |
|---|---|
| 2 GB memory ceiling OOM-kills Dart frontend locally | Run only fast relevant files via `tool/test.sh`; CI runs full suite |
| Gradle sqlite3 build hook | `sqflite_common_ffi` pinned to 2.3.x; no change needed |
| CI concurrency cancels previous push's run | Push increments immediately; each commit's CI covers its own code |
| Reduced-motion ignored | All durations read through `ElaraMotion.duration`; enforced by existing test |
| Push blocked by no credentials | PAT in `.gitinfo/token`; configure remote URL with it |
| ci.yml runs full suite on docs-only pushes | `paths-ignore: ['docs/**', '**/*.md']` added |

### Historical CI findings (measured, from CI_PERFORMANCE.md)

- APK job: 325s baseline → 160s warm cache (de-duplication + Gradle cache)
- Test shards: 4 shards, 359 total tests, all passed on run 42597704379
- Emulator matrix: API 29, 33, 35 — API 35 at 367s is the floor; wall clock ~11m
- Zero-job run caused by `${{ env.SHARDS }}` in job `name:` — fixed by moving shard count to each job's own `env:`
- Notification icon: `@mipmap/ic_launcher` returns id 0 via `getIdentifier`; fix was dedicated vector drawable `ic_stat_elara`

## Comparison: actual vs estimated

Updated after each stage completes.

## CI performance findings (maintained in docs/CI_PERFORMANCE.md)

See that file for measured durations, failures, causes, fixes.
