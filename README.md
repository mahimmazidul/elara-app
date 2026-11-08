# Elara

An offline-first cycle companion with local predictions and gentle daily guidance.

Elara is an Android Flutter app. Everything is computed and stored on-device: no
account, no analytics, no cloud. Prediction is provided by
[elara-core](https://github.com/mahimmazidul/elara-core), an ensemble cycle
forecasting engine consumed here as a git dependency.

## Status

| Area | State |
| --- | --- |
| Project init + dependencies | done |
| Data layer (sqflite) | done |
| Climate + prediction services | done |
| State management (provider) | done |
| Design system (`lib/theme`) | done |
| Four screens + onboarding | done |
| Notifications | not started (UI and settings keys only) |
| CI | not started |

## Architecture

```
lib/
  theme/
    elara_theme.dart          every colour, text style and shadow in the app
  data/
    database_helper.dart      sqflite singleton, schema, migrations, CRUD
    date_keys.dart            calendar-date / instant string encodings
    models/                   CycleEntry, ClimateSnapshot + heat index
  services/
    climate_service.dart      Open-Meteo + Open-AQ, 3h cache, seasonal fallback
    prediction_service.dart   history -> elara-core -> app-level ElaraResult
  models/
    elara_result.dart         the single aggregate the UI consumes
  providers/                  cycle, prediction, climate, settings
  utils/
    moon_phase.dart           local moon phase (Meeus series)
    nakshatra.dart            local nakshatra (27-fold ecliptic division)
    hijri_date.dart           Islamic calendar wrapper
    phase_timeline.dart       projects phases across any date range
  widgets/                    card, chip, score bar, food chips, primitives
  screens/
    root_scaffold.dart        four-tab shell
    today/                    Today screen + onboarding
    calendar/                 month grid + day detail sheet
    insights/                 three charts + prediction summary
    settings/                 location, theme, notifications, about
```

## Design system

`lib/theme/elara_theme.dart` is the only file allowed to contain a colour
literal. Screens read tokens through `context.elara`, and a source audit
(`grep -rn "Colors\.\|Color(0x" lib --include=*.dart`) confirms no colour leaks
outside it.

- **Flat by design.** No gradients, no glassmorphism, no neumorphism. One shadow
  exists, `ElaraShadows.card` (0 1px 3px rgba(0,0,0,0.08)); Material elevation is
  never used, so nothing can acquire a heavier one.
- **Typography.** Inter for headings and numerals, Source Sans 3 for body, both
  through `google_fonts`. Numerals use tabular lining figures so values do not
  jitter as they change.
- **Fonts are bundled.** `assets/fonts/` holds the six TTFs. google_fonts checks
  the asset manifest before the network, so a first launch with no connectivity
  still renders in the intended faces. Filenames must end `<Family>-<Variant>`
  because that is how google_fonts matches them.
- **Contrast is measured, not assumed.** Every text/background pair used by the
  app clears WCAG AA 4.5:1 in both modes. Phase colours are decorative; each has
  a `*Text` sibling adjusted in lightness for legibility, and ink on a filled
  phase chip uses `onPhase`, which clears 5.2-9.1:1 light and 5.7-10.0:1 dark.
  The spec's `textSecondary` (#8B7D7B) measures 3.69:1, so it is reserved for
  16px+/medium text and `textSecondaryStrong` (#7D6E6D, 4.54:1) is used for small
  captions.

## Local astronomy

No API is called for the lunar row.

- **Moon phase** — position of the Moon and Sun from truncated Meeus series; the
  phase is the Moon's elongation as a fraction of a turn, and the illuminated
  fraction follows as `(1 − cos θ)/2`. Known new and full moons reproduce to
  within 0.2% illumination, and the result agrees with an independent synodic
  count to within the real ±0.9-day variation in lunation length.
- **Nakshatra** — the Moon's sidereal longitude (Lahiri ayanamsa) divided into
  27 segments of 13°20′. Accuracy is documented in the source: a Moon within
  ~0.4° of a boundary may fall in the neighbouring segment.
- **Hijri** — the `hijri` package, which uses the calculated Umm al-Qura
  calendar. That can be a day off local crescent sighting, so the UI presents it
  as an approximation.

## Honesty notes

Elara is not a medical device and not a contraceptive. Predictions are calendar
estimates; the fertile window cannot confirm ovulation, and confidence scores are
heuristic, not clinically calibrated. The UI says so on the Today screen, in the
Insights summary, and below 0.6 confidence it shows an explicit warning. Where the
environmental data is a seasonal baseline rather than a reading, it is labelled
"estimated".

## Android

`com.mahimmazidul.elara`, minSdk 24, targetSdk 34. Android only — no iOS, web,
desktop targets are configured.

minSdk is 24, not the 21 originally specified: Flutter 3.47 defaults to 24 and
`flutter_local_notifications` 23 declares `minSdk 24`, so a 21 floor fails the
manifest merge. Keeping 21 would mean dropping the notification dependency or
pinning older versions of both.

## Build

```sh
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```
