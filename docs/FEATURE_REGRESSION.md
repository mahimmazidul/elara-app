# Feature regression matrix

Baseline for this audit: **`59412f6`** (`docs: three icon concepts for approval,
and the audit brought up to date`) — the last commit before the P1 UI and
recommendation work began.

Audited at: **`ea21a43`** (start of this pass) and revised through **`ea21a43`+**
as fixes landed. See the final report for the closing SHA.

Method: `git log --diff-filter=D` over the whole history, `git diff 59412f6..HEAD`
read in full, a symbol-by-symbol grep of `lib/` for every feature named in the
brief, and a read of each test file. A passing suite was **not** treated as proof
that a feature survived; each row cites the file and the code path.

Only two files have ever been deleted from this repository:

| Deleted file | Commit | Authorised? |
| --- | --- | --- |
| `assets/fonts/{Inter,SourceSans3}-*.ttf` | `7548c05` | Yes — replaced by DM Sans |
| `lib/widgets/score_bar.dart` | `7548c05` | Yes — project owner asked for numerical relationship scores to be removed |

`lib/screens/today/action_cards.dart` appears in no deletion commit. During the
P1 pass it was `git rm`-ed **unstaged by mistake** and restored from `HEAD` in the
same session before any commit; it is now present, modified in place. No test file
has ever been deleted.

## Status key

- **Preserved** — behaviour identical or equivalent after the change.
- **Improved** — behaviour present and extended.
- **Removed intentionally** — gone, with the approval cited.
- **Regressed** — was lost; fixed in this pass (column records the fix).
- **Unverified** — cannot be confirmed in this sandbox; manual step named.

---

## 1. Menstrual cycle

| Feature | Baseline | Current | Status | Evidence | Action |
| --- | --- | --- | --- | --- | --- |
| Period-start logging | `cycle_provider.dart` `logStart` | same | Preserved | `providers_test.dart` › CycleProvider; `database_helper_test.dart` › cycles CRUD | Keep |
| Period duration | `CycleEntry.duration` | same | Preserved | `cycle_entry.dart`; calendar sheet "Bleeding recorded for 5 days" | Keep |
| Cycle history | `getAllCycles` | same | Preserved | database tests; Insights chart | Keep |
| Cycle-day calculation | `daysBetween`, `phase_day` | same | Preserved | `PhaseChip` "Day 10"; `providers_test.dart` | Keep |
| Phase classification | elara-core `PhaseClassifier` | same | Preserved | `prediction_service.dart` `_classify` | Keep |
| Four-phase colour system | `phaseFill()` per key | same fills | Preserved | `phase_theme_test.dart` — 8 combinations | Keep |
| Future period prediction | elara-core ensemble | same | Preserved | `prediction_service_test.dart` › with regular history | Keep |
| Prediction uncertainty | `windowDays` | same | Preserved, relocated | Today: "Estimated 28 Nov 2026 ± 2 days" | Keep |
| Irregular-cycle handling | elara-core interval widening | same | Preserved | `prediction_service_test.dart` › robustness | Keep |
| Calendar projections | `phase_timeline.dart` | same | Preserved | `calendar.png` — projected days coloured, legend explains | Keep |
| Date corrections | `moveStartDate` | same | Preserved | `cycle_correction_test.dart` (10 tests); "Move date" in `calendar-detail.png` | Keep |
| Cycle insights and statistics | `insights/charts.dart` | same | Preserved | `insights.png` — length history, average ±SD, heat series | Keep |

## 2. Partner care

| Feature | Baseline | Current | Status | Evidence | Action |
| --- | --- | --- | --- | --- | --- |
| Action cards (phase prompt) | `action_cards.dart` ← `ActionResult.cards.first` | `action_cards.dart`, redesigned | **Preserved, improved** | `today_action_cards_test.dart`; `today-action.png` "Consider a date night" | Keep |
| Daily guidance | same card, per phase | same | Preserved | `ActionEngine` rule table: 6 phase-specific prompts | Keep |
| Food suggestions | `foodSuggestions` → `FoodChipRow` | same | Preserved | `FoodChipRow` in `ActionCards`; chip in `today-action.png` | Keep |
| Comfort suggestions | phase rules + climate | `CareRecommender._fromClimate` ≥33 °C, `PreferenceCategory.comfort` | **Improved** | `care_recommender_test.dart` | Keep |
| Activity recommendations | phase rules; "date night" for ovulatory | `CareRecommender` activity/dateIdea; `ActionEngine` "Consider a date night" | **Improved** | `care_recommender_test.dart` › every category | Keep |
| Date-night suggestions | `ActionEngine` ovulatory rule | same, rendered in the action card | Preserved | `today-action.png` | Keep |
| Climate-aware recommendations | severity → `ActionEngine` | severity → `ActionEngine` **and** explicit heat/PM2.5 rules | **Improved** | `care_recommender_test.dart` › extreme heat / air quality | Keep |
| Phase-specific practical actions | 6 rules | same 6 rules, now below evidence-based ones | Preserved | `care_recommender.dart` doc: phase voice lives in the card only | Keep |
| Personalised care recommendations | — | `CareRecommender.recommend` over preferences | **New** | `care_recommender_test.dart` (17 tests) | Keep |
| Partner preferences | — | schema v3 `preferences`, `PreferencesProvider` | **New** | `database_helper_test.dart`; today's `today_action_cards_test.dart` asserts her answer reaches the screen | Keep |
| Symptom-aware guidance | — | schema v3 `symptoms`, `SymptomsProvider`, `CareRecommender._fromSymptom` | **New** | `care_recommender_test.dart` | Keep |
| Numerical conversation / romance scores | `ScoreBar` 0–10 bars | **removed from the UI** | Removed intentionally (P1 brief: "no numerical romance/mood/conversation scores") | `score_bar.dart` deleted in `7548c05`; `today_action_cards_test.dart` and `responsive_test.dart` assert no score renders | Keep removed |
| Internal score outputs kept? | `ActionResult.conversationScore/romanceScore` | still produced by elara-core, **not read by the app** | Preserved, deliberately unwired | `action_cards.dart` class comment; `grep` finds no reader | Keep unwired |

### 2.1 Action-card investigation (the specific concern raised)

1. **What did the original implement?** Two stacked cards. The first rendered
   `ActionResult.cards.first.title` ("Offer practical support", "Check in
   gently", "Make time to connect", "Consider a date night", "Make room for a
   quiet check-in", "Offer support without assumptions") with
   `cards.first.body` and a caveat line. The second rendered
   `foodSuggestions` as chips. Nothing scored.
2. **When did references disappear?** They did not. `ActionCards` was imported
   by `today_screen.dart` continuously from `08f9564` to `59412f6`. In the first
   P1 pass the *new* Today screen stopped importing it and the file was removed
   from the index — the regression this audit was called for.
3. **Which commit changed usage?** The uncommitted P1 working tree (not any
   commit). Restored before `ea21a43`; `ea21a43` is the commit that carries the
   restored-and-redesigned widget.
4. **What happened to the categories?** All six phase prompts and every food
   list are intact — they come from `elara-core`'s `ActionEngine`, which is
   still called from `prediction_service.dart`, `day_detail_sheet.dart` and
   `notification_service.dart`.
5. **Does `CareRecommender` preserve all useful behaviour?** It adds behaviours;
   it does not replace the action card. It deliberately does **not** re-word phase
   guidance, so the two blocks cannot give conflicting advice. Its first pass
   did re-word it — that duplication was removed.
6. **Is `ActionResult` still used?** Yes: `prediction_service.dart` (builds it),
   `today_screen.dart` → `ActionCards`, `day_detail_sheet.dart` (day-specific
   card), `notification_service.dart` (notification text).
7. **Climate-aware actions still generated?** Yes — twice: the severity →
   `ActionEngine` path, and `CareRecommender._fromClimate` for heat ≥38 °C,
   PM2.5 ≥100 and heat ≥33 °C.
8. **Food, comfort, activity, relationship-care still available?** Yes, all
   four; see the rows above and `today-action.png`.
9. **Did tests disappear?** No test file has ever been deleted. The action card
   previously had **no** dedicated widget test — that gap is now closed by
   `test/screens/today_action_cards_test.dart`.
10. **Does Today visibly present practical recommendations?** Yes — first
    screenshot row of `docs/screenshots/contact-sheet.png`.

## 3. Environment

| Feature | Current | Status | Evidence |
| --- | --- | --- | --- |
| Temperature, heat index | `climate_strip.dart`; `_fromClimate` thresholds | Preserved | `climate_service_test.dart` (23); `today.png` shows 33 °C |
| Air quality / PM2.5 | same | Preserved | `climate_service_test.dart` › PM2.5 |
| Seasonal information | `ClimateSnapshot.seasonFor` → "Post-monsoon season" | Improved (no mid-word break) | `today.png`; fix recorded below |
| Location settings | `settings_screen.dart` lat/long, Dhaka default | Preserved | `settings.png` |
| Weather caching | `climate_cache` table, 30 days in screenshot data | Preserved | `climate_service_test.dart` › cache |
| Offline fallback | seasonal baseline, `isFallback` chip "estimated" | Preserved | `climate_service_test.dart` › failure fallback |
| Climate severity → guidance | `SeverityModifier().calculate` → `ActionEngine` | Preserved | `prediction_service.dart` lines 71–92 |

## 4. Calendar and astronomy

| Feature | Current | Status | Evidence |
| --- | --- | --- | --- |
| Gregorian calendar | `calendar_screen.dart`, month grid | Preserved | `calendar.png` |
| Hijri date | `hijri_date.dart` (Umm al-Qura) | Preserved | "Hijri 28 Jumada Al-Awwal 1448" |
| Moon phase + illumination | `moon_phase.dart`, `MoonGlyph` | Preserved | "0% illuminated" |
| Nakshatra | `nakshatra.dart` | Preserved | "Nakshatra Swati" |
| Bangladesh-local dates | `Asia/Dhaka` handling, not hardcoded globally | Preserved | notification tests, `atHour` zone resolution |
| Phase-coloured days | four fills | Preserved | `calendar.png` |
| Recorded vs projected | `isRecorded`, legend note | Preserved | `calendar-detail.png` "Recorded cycle" |
| Day-detail sheet | `day_detail_sheet.dart` | **Regressed → fixed** | was clipped on short screens; now capped at 85 % height and scrollable — `calendar-detail.png` shows date, correction actions **and** the day's action card |
| Bangla lunar names | `MoonPhase.nameBangla` | **New in P1, rendered as tofu** | fixed: Noto Sans Bengali fallback, 43 KB subset — `today-action.png` now reads অমাবস্যা |
| Astronomical vs official Hijri kept separate | yes, labelled | Preserved | footnote line |

## 5. Notifications

| Feature | Current | Status | Evidence |
| --- | --- | --- | --- |
| Daily briefing | `ElaraNotificationType.dailyBriefing` | Preserved | `settings.png`; `notification_privacy_test.dart` |
| PMS warning | `pmsWarning` | Preserved | `settings-privacy.png` |
| Period reminder | `periodStart` | Preserved | same |
| Ovulation reminder | `ovulationWindow` | Preserved | same |
| Climate spike | `climateSpike` | Preserved | same (off by default) |
| Scheduling / rescheduling | `reschedule()` + alarm manager | Preserved | `notification_service.dart` |
| Private previews by default | redaction + `visibility: private` | Preserved | `notification_privacy_test.dart` › redaction, android payload |
| Notification preferences | master switch + five toggles | Preserved | `settings.png` |
| Background rescheduling | `AndroidAlarmManager` alarm 900 | Preserved | code path present; **Unverified on device** (needs a real install) |

## 6. Privacy and data

| Feature | Current | Status | Evidence |
| --- | --- | --- | --- |
| Consent and revocation | `ConsentProvider`, append-only log, v2 migration | Preserved | `consent_provider_test.dart` (13), `consent_schema_test.dart` (8) |
| Database storage | sqflite, schema v3 | Improved (two new tables) | `database_helper_test.dart` (34) › migrations |
| Encrypted backup export | `backup_service.dart`, PBKDF2 210k, AES-GCM | Preserved | `backup_service_test.dart` (11) |
| Backup restore | replaces data, verified passphrase | Preserved | same |
| Data deletion | typed confirmation; reset clears all five tables | Preserved | `consent_gate_test.dart` › deleting everything requires typing a word |
| Privacy settings | `privacy_data_section.dart` | Preserved | `settings-privacy.png` |
| Offline-first | no analytics, no accounts, on-device prediction | Preserved | no network client except Open-Meteo/OpenAQ |

## 7. Product and interface

| Feature | Current | Status | Evidence |
| --- | --- | --- | --- |
| Today | restructured (P1) | Improved | `today.png`, `today-dark.png` |
| Calendar | unchanged layout | Preserved | `calendar.png` |
| Insights | unchanged charts | Preserved | `insights.png` |
| Settings | unchanged, plus bottom-padding fix | Preserved | `settings.png` |
| Onboarding / first run | `OnboardingCard` | Preserved | `screens_test.dart` "Welcome to Elara" |
| Light and dark themes | both | Preserved | `today.png` / `today-dark.png`, `calendar.png` / `calendar-dark.png` |
| Phase-adaptive colours | accent + `phaseWash` | Improved (neutral surfaces) | `phase_theme_test.dart`, `responsive_test.dart` |
| Navigation (bar + rail) | `root_scaffold.dart` | Preserved | `responsive_test.dart` (10) |
| Tablet layout | rail ≥720 dp, 720 dp column | Preserved | `tablet.png` (1024×768) |
| Accessibility | semantics labels on calendar cells | Preserved | `accessibility_test.dart` |
| App icon | crescent + gold circle | Preserved, untouched this pass | `assets/` unchanged |
| Version information | `app_info.dart` from package metadata | Preserved | `app_info_test.dart` |

## 8. Defects found and fixed in this pass

| Defect | Where | Fix |
| --- | --- | --- |
| Bengali lunar name rendered as tofu boxes | `lunar_strip.dart` + fonts | Noto Sans Bengali subset (43 KB) registered as `fontFamilyFallback` |
| Text clipped under the bottom navigation bar | `ElaraSpacing.pageInsets` | reserves the M3 bar height (80 dp) plus safe area; `kBottomNavigationBarHeight` (56) was too small |
| Day-detail sheet overflowed on short screens, hiding the day's action card | `day_detail_sheet.dart` | capped at 85 % height, scrollable — verified in `calendar-detail.png` |
| "Post–monsoon" broke after the hyphen in a narrow third column | `climate_strip.dart` | season moved to its own caption line |
| Phase chip dominated the screen (22 pt in a tall pill) | `phase_chip.dart` | 15 pt subtitle chip, tighter padding |
| Cycle day printed twice ("Day 10" chip + "Day 9 of this cycle") | `today_screen.dart` | removed the duplicate line |
| Climate strip sat above the care section | `today_screen.dart` | care first, climate after — matches the brief's hierarchy |
| Second engine card dropped (`cards[1]`) | `action_cards.dart` | extra cards render when they add information; the "Food idea" duplicate is still filtered |
| Settings overflowed at 1.5× (theme selector, 13 px) and 2.0× (location buttons, 99 px) | `settings_screen.dart` | segmented control → wrapping chips; both location buttons share the row. Found by the new text-scale and width tests, not by eye |
| Selected chips were the luteal purple | `elara_theme.dart` | `chipTheme` uses the neutral raised tint; phase colours stay on phase things |
| Preferences and symptoms had providers and tables but no screen | `screens/preferences/` | new screen: her answers with per-answer sharing, the holder's observations with confirmation, edit and delete; linked from Settings. 8 widget tests |

## 9. Still unverified

| Item | Why | How to verify |
| --- | --- | --- |
| Notification delivery + Android "private" lock-screen behaviour | needs a device / emulator with the platform channels | install the release APK, set a reminder within 24 h, observe the shade and the lock screen |
| Background reschedule alarm firing after a reboot | platform alarm manager | install, reboot, confirm the next briefing appears |
| Tablet layouts other than 1024×768 landscape | one viewport captured | run `test/widgets/responsive_test.dart` matrix (320–1024) — passes; landscape phone/tablet on device not captured |
| Text scaling 1.5× and 2.0× — layout, not just absence of exceptions | `responsive_test.dart` renders every tab at 1.0/1.3/1.5/2.0 and fails on overflow, but a PNG is not captured | manual check at 2.0× on a device |
| Preferences and symptom screens on a real device | the screen is tested and screenshotted as a widget render; the sheet editor and popup menus were not driven through a full gesture path in a test | tap through add / edit / share / delete on a device |
| Clinical review of the medical content | no clinical reviewer involved | requires a clinician; no medical claims are made in the UI in the meantime |
| Prediction calibration on real data | needs a real cycle history | run against a year of real entries; do not claim a coverage target |

## 10. Later passes (superseding rows in sections 6–8)

The table above records the P1 pass. These changes came after it, and where a row
above says "Preserved" it no longer holds.

| Area | Now | Where |
| --- | --- | --- |
| Settings | a hub of ten rows in three groups; every row carries a status line; each opens a page holding one subject | `settings_screen.dart`, `widgets/sub_page.dart` |
| Insights | a hub of three subjects (cycle length, how steady it is, how the prediction was made, heat and the cycle), charts moved onto the pages behind it | `screens/insights/` |
| Today | hero dial, countdown, guidance, then notes / weather / moon as rows opening their own pages; the climate strip and lunar strip are no longer inline | `screens/today/` |
| Navigation | tabs swipe as well as tap; the content follows the finger, resists at both ends, and springs back on a miss | `root_scaffold.dart` › `_SwipeTabs`, `responsive_test.dart` › swipe |
| Surfaces | glass panels on settings, Insights and the sub-pages; no outline, no `BackdropFilter` | `widgets/primitives.dart` › `ElaraGlass` |
| Palette | warm paper and ink replaced the slate-blue/white palette; the website was recoloured with it | `theme/elara_theme.dart`, `docs/index.html` |
| Today's advice | personalised first, then general guidance for the phase with its sources | `data/generic_guidance.dart`, `services/care_recommender.dart` |
| Health sources | the publisher is named and the page opens; raw URLs no longer appear on any page | `medical_topic_screen.dart` |
| README | 479 lines → 127; detail moved into `docs/` | `README.md` |
