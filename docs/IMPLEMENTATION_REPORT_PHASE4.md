# Implementation report — Phase 4 and the closing work

**Repository:** <https://github.com/mahimmazidul/elara-app>
**Technical reference:** <https://github.com/mahimmazidul/taka> (studied at `fbb4dfa`)
**Report date:** 2026-11-08

This report covers the work recorded in Stages 15–17 of
[`docs/DEVELOPMENT_PROGRESS.md`](DEVELOPMENT_PROGRESS.md), and states plainly
which things were **verified** and which were only **reasoned about**.

---

## 1. The commits

Starting SHA for this stretch: `0105f62` (the execution checklist, the CI
timings, and the Taka comparison).

| SHA | what it is |
| --- | --- |
| `08af389` | Press feedback (`ElaraPressable`) and a quieter page transition (`elaraRoute`), with reduced-motion respect. Also the capture script's recovery fix. |
| `af30e3e` | Hind Siliguri replaces DM Sans; tabular numerals preserved; the SIL OFL licence bundled; every README and website screenshot regenerated. |
| `8c72457` | The suite no longer runs twice; the Gradle cache is in place. |
| `439a4fc` | The notification's small icon is captured from the status bar on a real emulator. |
| `0cdf4be` | The documentation of the two above. |
| `45ef3af` | The text-scale sweep extended to the screens it was missing. |
| `a9b1c1c` | The motion system, described in the README. |

Final SHA at the time of writing: `a9b1c1c`. The repository was at 80
commits at the start of this stretch and 87 at the end.

---

## 2. What was done, and what it was checked against

### 2.1 Purposeful motion, with reduced motion respected (14.3)

**Verified — locally, by nine widget tests (`test/widgets/press_feedback_test.dart`):**

- a pressed surface scales to 0.97 while held;
- the press tint is applied even when animations are removed;
- a list row's tap fires **exactly once** (the pressable wraps the `InkWell`,
  it does not duplicate the handler);
- the page transition fades and rises;
- the page transition has **no transition at all** under reduced motion;
- the transition is under 300 ms.

**Design decisions worth stating:**

- `elaraRoute` takes a `BuildContext`, because whether it should animate
  depends on the platform's setting *at the moment the route is pushed*. The
  five screens that push a route changed signature, and every call site was
  updated.
- The press **tint** survives reduced motion while the **scale** does not. A
  change of colour is not motion, and a control that does not change at all
  reads as unresponsive.
- `MaterialPageRoute`'s zoom was replaced rather than tuned: it shows the
  outgoing screen through the incoming one for the whole transition.

### 2.2 Typography: Hind Siliguri replaces DM Sans (14.4)

**Verified — by real renders, inspected.**

The comparison harness renders the **actual Today and Settings screens**, with
the **actual seeded data**, in each candidate family. The images are in
`tool/fonts/comparison/` and were looked at.

| Criterion | DM Sans (incumbent) | Hind Siliguri |
| --- | --- | --- |
| English refinement | **Better.** Geometric, airy, excellent numerals. | Slightly heavier; fits marginally less per line. |
| Bengali | Set in a *different typeface* — a 40-glyph Noto Sans Bengali subset — visibly lighter and narrower than the English around it. | Same family as the English; the weight and proportion match. |
| Coverage | The subset covers exactly the 27 characters the app prints today. Any new Bengali string renders as tofu — **demonstrated** in the comparison sheet. | 427 glyphs, Latin and Bengali, in four weights. |
| Families in the bundle | Two. | One. |
| Tabular numerals | Had `tnum` added by the build script. | Had **no** `tnum` and proportional digits (the `1` is 323 units, the `0` is 544). **Fixed** by `tool/fonts/build_hind_siliguri.py`. |

**Decision: Hind Siliguri.** The English is a shade heavier; that is the
price of one family, no seam, and a Bengali that was not a fallback.

**Two consequences to state honestly:**

1. **The font swap makes the APK bigger.** The bundle grew from 152 KB to
   1.04 MB (+884 KB raw): four full weights with complete Bengali coverage,
   plus the licence file, against three Latin weights and a 40-glyph subset.
   Measured inside the APK built by run `42621616138`:

   | in the APK | raw | compressed |
   | --- | ---: | ---: |
   | Hind Siliguri Regular | 238,752 | 123,582 |
   | Hind Siliguri Medium | 255,204 | 128,172 |
   | Hind Siliguri SemiBold | 261,400 | 129,942 |
   | Hind Siliguri Bold | 276,700 | 129,890 |
   | **the four together** | **1,032,056** | **511,586 (500 KB)** |

   The old bundle compressed to roughly 130 KB, so the swap costs about
   **370 KB** of extra APK. Against the v1.2.0 arm64 release APK of 21.6 MB
   that is under 2%.

   A smaller alternative exists and was not taken: subsetting Hind Siliguri
   to the characters the app prints would give back most of the 500 KB.
   It was rejected because the point of the change is that the app's
   Bengali is no longer a 27-character subset — that restriction is exactly
   what produced the tofu boxes. Subsetting it again would reintroduce the
   fragility, more quietly this time, because the characters would be there
   until someone typed something new.

2. A side effect is an improvement: the font bundles a **real 600**, so a
   caller asking for semibold now gets semibold rather than a rounded 700.

**Licensing — a gap closed.** The app previously bundled DM Sans and Noto
Sans Bengali **with no licence file at all**. `assets/fonts/OFL.txt` now
ships with the SIL Open Font License 1.1.

**Not tested:** Roboto (carries no Bengali, so it would not solve the actual
problem, and is already on every Android device); an iOS-style direction
(Apple's SF fonts cannot be redistributed, which the brief rules out);
Kalpurush (a single-weight display face, not a text family).

### 2.3 The icon system (14.7 of the four-piece list)

**Already complete, and verified.** ~45 named glyphs in `ElaraIcons`, with a
7-test enforcement suite. Only six raw Material icons remain outside the
vocabulary, all in `root_scaffold.dart` for the bottom-navigation tabs, which
is the one place where a filled/outlined pair is wanted.

### 2.4 The text-scale sweep (14.3 of the four-piece list)

**Verified — 68 layouts, all passing.**

- The existing sweep: symptoms, reminders, preferences, the health-information
  list and a topic, at 320 and 390 dp × 1.0/1.3/1.5/2.0 — 40 layouts.
- The new sweep: the **consent gate** and the **day-detail sheet** at 320,
  390 and 1024 dp × 1.0/1.3/1.5/2.0, plus the consent gate on a 430 dp
  phone — 28 layouts.

The two screens added are the ones that are *not* routes and were therefore
missed: the consent gate (the first thing a person sees, with every string
written by hand) and the day-detail sheet (a modal, so height-constrained
rather than width-constrained, with its own maximum-height rule). The 1024 dp
column is a different layout path, not a wider version of the same one: the
navigation rail appears at 720 dp.

### 2.5 The notification's small icon (14.7)

**The resource was already correct:** `ic_stat_elara` is a 24 dp monochrome
vector, inset to 21 dp, in the crescent-and-gold-dot shape, with `raw/keep.xml`
preserving it against the resource shrinker.

**What was missing was the evidence.** The new
`tool/android_ui/notification_icon.sh` asks the system to post a notification
on Elara's behalf using the app's own icon resource, waits for it, captures
the status bar, and crops and magnifies the top strip three times so the mark
can be judged. The crop is pure Python, because a runner has no image tools.
It also checks the status bar's own dump and records what it found, so a
capture showing no notification cannot be mistaken for evidence.

The crop-and-magnify code was **tested locally** against a real device
capture before being committed.

### 2.6 CI efficiency (14.6, 14.7)

| change | before | after |
| --- | --- | --- |
| Tests per push | 436, **run twice** | 436, run once |
| The APK job's analyze + serial test | 45 s + the whole suite in one process | removed |
| Gradle cache | **not cached** | `~/.gradle/caches` and `~/.gradle/wrapper`, keyed on the Android build files |

**The gate is not removed, it moves.** `ci.yml` already runs the analyzer and
the whole suite on the same commit, in parallel. `main` is only advanced once
`ci.yml` is green. The APK job keeps the checks that belong to an *artifact*
rather than to the code: that the APK exists, parses, is the expected package,
and carries the notification and launcher icons in its packaged resources.

**Measured — two runs, so the cache's contribution can be separated from
the de-duplication's:**

| | baseline (`79dbb6b`) | cold cache (`45ef3af`) | warm cache (`61a7c1b`) |
| --- | ---: | ---: | ---: |
| Build debug APK — whole job | 325 s | 276 s | **160 s** |
| — the Gradle build inside it | ~280 s | 199 s | **112 s** |
| `Android CI` wall clock | 11 m 00 s | 11 m 07 s | the emulators decide it |

The log confirms the mechanism: the cold run says `Cache not found for input
keys: gradle-Linux-…` and saves the cache at the end; the warm run says
`Cache restored from key: gradle-Linux-874f4c05…` and the Gradle build
drops from 199 s to 112 s.

**Together the two changes took the APK job from 325 s to 160 s — 165 s, or
51%.** The de-duplication was worth 126 s of that and the Gradle cache
39 s.

**The workflow's wall clock did not move**, because the emulator matrix is
now the only thing that decides it: the longest one, API 35 at 367 s, is the
floor. One emulator cannot run three API levels, and the three jobs already
run in parallel. That is the honest reading, and it is worth stating rather
than quoting the saving as if the pipeline had got faster.

---

## 3. Taka: what was taken and what was not

Studied at `fbb4dfa`, at the source level.

| Taka | Verdict |
| --- | --- |
| `Pressable` (110 ms, scale 0.972) | **Adopted in spirit** — `ElaraPressable`, at 0.97 and 90 ms, with the reduced-motion rule Taka lacks. |
| `slideFadeRoute` (fade + 5.5% slide + 0.985 scale) | **Adopted in spirit** — `elaraRoute`, a fade and a 4% rise, with no transition at all under reduced motion. |
| `Screen.scale` / `Screen.font()` (font size × screen width) | **Rejected.** This is exactly what the brief forbids: solving responsiveness by multiplying fixed font sizes by screen width. |
| `ContentWidth` / `gutter` | **Already present** in Elara as `ElaraContentWidth`. |
| `MainActivity.kt` (an empty `FlutterActivity`) | **Not copied.** Taka has no native edge-to-edge; Elara's implementation, proven on device, is better. |
| No `disableAnimations` handling anywhere | **Not copied.** Elara's `ElaraMotion.reduceMotion` is better, and the new route and pressable both honour it. |
| Raw `Icons.` call sites | **Not copied.** Elara's named vocabulary is better. |
| Hind Siliguri at four weights, with `OFL.txt` | **Adopted**, after evaluating it against DM Sans on real renders. |

---

## 4. The failures that were avoided

Recorded because the point of the checklist is that they were learned from,
not repeated.

| failure | what it cost | the fix |
| --- | --- | --- |
| The foreground check grepped `mCurrentFocus`, which the emulator's window dump does not have | the app was relaunched before every capture, resetting the scroll — so no capture ever reached the bottom of a screen | the check now scans the *activity* dump for a resumed/focus line containing the package, verified against a real dump |
| One missed tap pushed the app out of itself | every later Settings capture ran against the wrong screen, and three captures were photographs of the Android app drawer | `go_to_settings` puts the app back on a known screen before each capture |
| A tap that landed on the wrong control | a picture of the Insights tab was committed under the name "Care reminders" | the capture script now checks that the expected text is on screen before it shoots |
| The suite ran twice per push | ~90 s of every push, and the Android build waited for the slower copy | the duplicate is removed; the gate moves to `ci.yml` |

---

## 5. Verified facts and stated assumptions

**Verified, by observation:**

- 436 tests across four shards, and `dart analyze --fatal-infos` clean, on
  the commits that carried the typography change (`8c72457`, `45ef3af`).
- The 40 existing text-scale layouts and the 28 new ones all pass.
- The nine new motion tests pass.
- The 21 theme tests pass, including the two new ones.
- The status-bar sampler measured a difference of **0.0** — the strip and the
  page are the same colour — on API 29, 33 and 35.
- The font comparison renders, and the six images were inspected.
- The PNG crop-and-magnify code was tested locally against a real capture.
- Every emulator script passes `tool/android_ui/check_scripts.py`.

**Assumed, or not yet measured:**

- The APK job's new duration is now **measured**: 325 s → 160 s, of which
  126 s was the de-duplication and 39 s the Gradle cache. The workflow's
  wall clock did not move, because the emulators decide it.
- The release APK's new size. The font's contribution to the debug APK is
  measured at 500 KB compressed, about 370 KB more than the old bundle. The
  release APKs have not been rebuilt since — the release workflow skips a
  version that has not changed, and changing the version is the owner's
  decision.
- The notification icon's appearance in the status bar. The capture is
  automated, and the first attempt at it **did not work** — the notification
  was never posted, and the script reported success anyway. The syntax is
  fixed and the run has to be repeated before the icon can be said to draw.
- Nothing here was tested on a physical device. Every runtime claim in this
  report comes from an emulator.

---

## 6. Remaining work

1. **Re-run the device screenshots** after the two capture-script fixes, and
   confirm that `10-about.png` is the About block and that the notification
   icon actually draws in the status bar.
2. **Rebuild the release APKs** once the version is decided, and read the
   size from them. The font's contribution is measured at 500 KB
   compressed, about 370 KB more than the bundle it replaced.
4. **Update the website** with the new screenshots and the current version.
5. **Release.** `v1.2.0` is the current published release. A new one is
   **not** published automatically — the project owner's authorisation is
   required, and the version, the source revision, the tag and the published
   artifacts have to agree before it is.
