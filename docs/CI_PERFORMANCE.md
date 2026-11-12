# CI performance

Measured from the GitHub Actions runs, not estimated. Every duration below is
the wall-clock time between a job's `started_at` and `completed_at`.

The point of this file is to record where the time actually goes, so the next
change to a workflow can be judged against a number rather than a hunch.

## Where the time goes today

### The `CI` workflow — run 42614732478, `643a0f2`

| job | duration | outcome |
| --- | ---: | --- |
| Plan the test shards | 6 s | success |
| Static analysis | 45 s | success |
| Test shard 0/4 | 64 s | success |
| Test shard 1/4 | 48 s | success |
| Test shard 2/4 | 36 s | success |
| Test shard 3/4 | 72 s | success |

**Total wall clock: 2 m 2 s.** The shards run in parallel, so the longest
one — shard 3 — sets the floor at 72 s. Adding a fifth shard would not
shorten the run unless shard 3's files were rebalanced.

### The `Android CI` workflow — run 42613036500, `79dbb6b`

| job | duration | outcome |
| --- | ---: | --- |
| Build debug APK | 325 s | success |
| Emulator · API 29 | 281 s | success |
| Emulator · API 33 | 329 s | success |
| Emulator · API 35 | 327 s | success |

**Total wall clock: 11 m 0 s.** The three emulator jobs run in parallel after
the APK job, so the emulator matrix costs 329 s on top of the build.

### The `Screenshots` workflow — run 42613036559, `79dbb6b`

54 s end to end.

---

---

## The known waste, and what was done about it

### The APK job ran the whole test suite a second time

`android-ci.yml`'s `apk` job had `dart analyze --fatal-infos` and
`flutter test` steps. `ci.yml` runs both of those, in parallel, on the same
commit. So every push paid for the 436-test suite twice: once in `CI` and
once in `Android CI`, and the second copy gated the APK.
`android-ci.yml`'s `apk` job had these steps:

```yaml
- name: Analyze
  run: dart analyze --fatal-infos
- name: Test
  run: flutter test --reporter expanded
```

`ci.yml` runs both of those, in parallel, on the same commit. So every push
paid for the 436-test suite twice: once in the `CI` workflow and once in the
`Android CI` workflow, and the second copy gated the APK.

**Measured cost:** the `CI` workflow's analysis plus shards is 45 s + up to
72 s, of which the duplicated portion inside the APK job is roughly 90 s of
the 325 s. The APK itself — Gradle, dexing, packaging — is the rest.

**What was done:** the `apk` job no longer runs the suite, and no longer runs
the analyzer either. Both belong to `ci.yml`, which runs them on the same
commit: `dart analyze --fatal-infos` in the analyze job, and the whole of
`test/` across four shards in parallel.

**Measured — two runs, so the cache's own contribution can be separated from
the de-duplication's.**
**Why the tests were not simply dropped:** the APK must never be built from a
revision that fails its own tests. Dropping the gate entirely would let a
broken revision produce an artifact. Instead the gate moves to the workflow
that owns it, and `main` is only advanced after `ci.yml` is green — which is
already how the branch is protected. The `apk` job keeps the checks that
belong to an *artifact* rather than to the code: that the APK exists, parses
as an APK, is the expected package, and carries the resources it needs.

**What this is worth:** the `apk` job's analyze step was 45 s of the 325 s
and its serial test run was the larger part of the rest — a single-process
`flutter test` over 436 tests, where the sharded version does the same work
across four runners in 72 s.

**Measured — two runs, so the cache's own contribution can be separated
from the de-duplication's.**

| | baseline (`79dbb6b`) | cold cache (`45ef3af`) | warm cache (`61a7c1b`) |
| --- | ---: | ---: | ---: |
| Build debug APK — whole job | 325 s | 276 s | **160 s** |
| — the Gradle build inside it | ~280 s | 199 s | **112 s** |
| `Android CI` wall clock | 11 m 00 s | 11 m 07 s | see below |

The de-duplication was worth 126 s and the Gradle cache 39 s. The workflow's
wall clock did not move (11 m 00 s → 11 m 07 s) because the emulator matrix
decides it: API 35 at 367 s is the floor, and one emulator cannot run three
API levels.
The log confirms the mechanism: the cold run says `Cache not found for input
keys: gradle-Linux-…` and saves the cache at the end; the warm run says
`Cache restored from key: gradle-Linux-874f4c05…` and the Gradle build
drops from 199 s to **112 s**.

**So the two changes together took the APK job from 325 s to 160 s — 165 s,
or 51%.** The de-duplication was worth 126 s of that and the Gradle cache
39 s. Neither is the whole story, and the document says which is which.

**The wall clock barely moved, and saying so matters.** The emulators
dominate completely: the longest one, API 35 at 367 s, sets the floor. The
matrix cannot be made to share — one emulator cannot run three API levels —
and the three jobs already run in parallel. So the saving is real but it is
*inside* the APK job, on a wall clock that the emulators decide.

The emulator jobs also got slower by 11–40 s in the same run, which is
noise from a shared runner rather than a regression: the same scripts, on
the same code, and the API 29 job was unchanged at 280 s against 281 s.

### The emulator jobs each boot their own emulator

Three API levels, three boots, each 281–329 s. The boot itself is the
dominant cost inside those jobs. The three jobs are already parallel, so the
matrix costs one boot's wall clock rather than three.

### The `Device screenshots` workflow rebuilds the APK

It builds its own debug APK (~4 minutes) rather than downloading the one
`Android CI` uploaded. Deliberate duplication: the two workflows run in
parallel, so sharing an artifact would make the second wait for the first.
dominant cost inside those jobs: `reactivecircus/android-emulator-runner`
logs a boot of roughly 50 s on API 33, and the rest is the script's own
sleeps and captures.

The three jobs are already parallel, so the matrix costs one boot's wall
clock rather than three. There is no shared-emulator option that would be
faster: a single emulator cannot run three API levels.

### The `Device screenshots` workflow rebuilds the APK

It builds its own debug APK (about 4 minutes) rather than downloading the
one `Android CI` uploaded. That is a deliberate duplication: the two
workflows run in parallel, so sharing an artifact between them would make the
second one wait for the first — and the device screenshots are the evidence
that the *installed* app looks right, which is worth four minutes of build
time to have independently.

### The screenshot workflows run on their own commits

`Screenshots` and `Device screenshots` commit their own output, so each
push produces a follow-up commit. That follow-up commit does not re-trigger
them: `Screenshots` excludes `docs/screenshots` from its trigger paths and
commits with `[skip ci]`.

---

## Caching

| what | cached by | notes |
| --- | --- | --- |
| Flutter SDK | `subosito/flutter-action@v2`, `cache: true` | keyed on the pinned version, so it is reused across every run |
| Pub packages | the same action's pub cache | invalidated by `pubspec.lock` |
| Gradle | `actions/cache@v4` in `android-ci.yml` and `device-screenshots.yml` | keyed on the Android build files; see below |

**The Gradle cache is now in place.** The APK job's time includes downloading
the Gradle distribution and every Android dependency. Gradle's own cache
lives in `~/.gradle` and was restored by no workflow; it now is, in both
workflows that build an APK.

Two details matter:

  * the cache covers `~/.gradle/caches` and `~/.gradle/wrapper`, not the
    whole of `~/.gradle`. The dependency cache is content-addressed and
    self-validating, so a stale entry cannot silently produce a different
    build; a stale *wrapper* would still be re-fetched if the distribution
    it points at changed.
  * the key is a hash of the Android build files, so a change to
    `build.gradle.kts` produces a new key and a clean download, and an
    unchanged build reuses the previous run's cache. The `restore-keys`
    prefix means a build-file change still starts from the nearest
    previous cache rather than from nothing.

The effect cannot be read from the first run, which is cold by definition.
On run `42619094029` the log confirms it was cold — `Cache not found for
input keys: gradle-Linux-…` — and the cache was saved at the end of the job.
The number to compare is the *second* run's APK job against the **199 s**
that the cache-less, de-duplicated build already achieved.

---

## Failures that cost time, and how they are avoided now

| failure | what it cost | the fix |
|---|---|---|
| Gradle distribution CDN returned 504 | a whole failed 5-minute run | three-attempt retry in the build step |
| sqlite3 native library truncated on download | another whole failed run | `sqflite_common_ffi` pinned to `>=2.3.0 <2.4.0` |
| `${{ env.SHARDS }}` inside a job `name:` | a run with zero jobs | shard count in each job's own `env:` block |
| bash continuations under `/usr/bin/sh` | emulator step died instantly | flow moved into `tool/android_ui/*.sh` |
| `artifact/app-debug.apk` did not exist | emulator booted, then install failed | `tool/android_ui/find_apk.sh` looks in both places |
| `$ACTIVITY` undefined in `navigation.sh` | all three emulator jobs died | `tool/android_ui/check_scripts.py` checks every variable |
| screenshot workflow push non-fast-forward | run failed after doing all work | both screenshot workflows retry the push against the new head |
| the emulator step died with exit 255, mid-run, with the logcat unwritten | a failed run whose own evidence did not explain it | the script names its failing line, reconnects adb, and writes its log and the live logcat into the artifact |
| --- | --- | --- |
| Gradle distribution CDN returned 504 | a whole failed 5-minute run | a three-attempt retry in the build step, with the delay growing |
| the sqlite3 native library was truncated on download | another whole failed run | `sqflite_common_ffi` pinned to `>=2.3.0 <2.4.0` in `446b4f9` |
| `${{ env.SHARDS }}` inside a job `name:` | a run with zero jobs, 0 s of work but a full diagnosis | the shard count is in each job's own `env:` block |
| an inline workflow script used bash continuations under `/usr/bin/sh` | the emulator step died instantly | the flow moved into `tool/android_ui/first_launch.sh` |
| `artifact/app-debug.apk` did not exist in the job that builds in place | the emulator booted, then the install failed | `tool/android_ui/find_apk.sh` looks in both places |
| `$ACTIVITY` was used in `navigation.sh` without being defined | all three emulator jobs died at their last step | `tool/android_ui/check_scripts.py` checks every variable is assigned, and runs in CI |
| the screenshot workflow's push was a non-fast-forward | the run failed after doing all its work | both screenshot workflows retry the push against the new head |
| `capture_screens.sh` aborted with exit 255 and no line number | a failed run that could not be diagnosed from outside the repository | the script has an ERR trap that names its line, `adb_run` reconnects instead of dying, stdout is teed into `evidence/capture-script.log`, and the logcat is streamed from the launch rather than dumped at the end |
| `capture_screens.sh` tapped "Open preferences" and "Open health information" | four releases of captures that were silently missing 06 and 09 | `tool/android_ui/check_scripts.py` checks that every label a script taps is a string in `lib/` |
| the About and Privacy blocks scrolled for a word that is on a page they never opened | 10-about and 11-privacy have never existed | the About row is tapped before the Developer row is looked for, and both pages are backed out of |

The emulator-script check is the one that generalises. The other failures
were each specific to one line of one script; the check catches the whole
class. Its label check is the same idea applied to the app's own strings: a
tap on a word no widget renders cannot succeed, and that is now a lint error
rather than a line in a log that a green run still scrolls past.

---

## Measurements to compare against after the next change

| metric | before | after |
| --- | --- | --- |
| `CI` wall clock | 2 m 2 s | (re-measure after this milestone) |
| APK job — whole | 325 s | **160 s** (measured, warm cache) |
| APK job — Gradle build alone | ~280 s | **112 s** (measured, warm cache) |
| `Android CI` wall clock | 11 m 0 s | 11 m 07 s (cold cache; emulators decide) |
| longest emulator job | 329 s | **367 s** (API 35; the wall-clock floor) |
| `Screenshots` | 54 s | unchanged |
| tests per push | 436, run twice | **436, run once** (measured) |

**What is left.** The emulators dominate once the APK job is trimmed, and
they cannot be made to share: one emulator cannot run three API levels, and
the three jobs already run in parallel. If the wall clock has to come down
further, the matrix has to shrink — a coverage decision, not a speed one.
| `CI` wall clock | 2 m 2 s | 2 m 2 s (unchanged) |
| APK job — whole | 325 s | **160 s** (measured, run `42621616138`, warm cache) |
| APK job — Gradle build alone | ~280 s | **112 s** (measured, same run) |
| `Android CI` wall clock | 11 m 0 s | 11 m 07 s (cold cache); the emulators decide it |
| longest emulator job | 329 s | **367 s** (API 35; the wall-clock floor) |
| `Screenshots` | 54 s | unchanged |
| `Device screenshots` | ~4 min build | to be measured with the warm Gradle cache |
| tests per push | 436, run twice | **436, run once** (measured) |

**What the numbers say.** The APK job went from 325 s to 160 s — 165 s,
51% — and the Gradle build inside it from ~280 s to 112 s. The workflow's
wall clock did not move, because the emulator matrix is now the only thing
that matters. That is the honest reading, and it is worth stating plainly
rather than quoting the saving as if the pipeline had got faster.

**What is left.** The emulators, and they are not reducible without giving
up an API level. That is a coverage decision, and it is not one to make
without saying so.

The emulators dominate once the APK job is trimmed, and they cannot be made
to share: one emulator cannot run three API levels, and the three jobs
already run in parallel. If the wall clock has to come down further, the
matrix has to shrink — which is a coverage decision, not a speed one, and
it is not a change to make without saying so.
