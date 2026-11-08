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
| UI | not started |

## Architecture

```
lib/
  data/
    database_helper.dart      sqflite singleton, schema, migrations, CRUD
  services/
    climate_service.dart      Open-Meteo + Open-AQ, 3h cache, seasonal fallback
    prediction_service.dart   history -> elara_core -> app-level ElaraResult
  providers/
    cycle_provider.dart       cycle list, add/delete
    prediction_provider.dart  current prediction, lifecycle refresh
    climate_provider.dart     current climate snapshot
    settings_provider.dart    typed settings, persisted on change
```

## Honesty notes

Elara is not a medical device and not a contraceptive. Predictions are calendar
estimates; the fertile window cannot confirm ovulation, and confidence scores are
heuristic, not clinically calibrated. The UI is expected to say so plainly.

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
