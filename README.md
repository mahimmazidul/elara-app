# Elara

Elara is a cycle companion for Android. It reads your cycle, the weather outside
and the shape of the last few months, then tells you what today looks like: which
phase you are in, how many days remain until the next period, and one concrete
thing to do about it. Everything it knows stays on the phone, in a local SQLite
database, and computes there. Open the app on a beach in Kuakata with the network
off and every screen still works, because the forecasting, the astronomy and the
calendar conversion are all local code.

The prediction engine is [elara-core](https://github.com/mahimmazidul/elara-core),
an ensemble forecasting library consumed here as a git dependency. The app is the
part that turns its numbers into something a person can act on.

## What today looks like

The Today tab answers one question per visit. It opens with the current phase as a
coloured chip next to the cycle day, then a countdown to the next estimated period
with the confidence window spelled out, so a slightly irregular month reads as
honestly uncertain rather than falsely precise.

Below that sits the day's action card: movement, food and rest guidance drawn from
the phase and the environmental severity, phrased for the day you are having. A
heat index above forty overrides the gentle suggestions and tells you to sit still
and drink water, which is the correct advice in Khulna in May.

The lunar strip carries the moon phase, the nakshatra and the Hijri date. All
three are computed from the current date by the app itself.

## The calendar

The month grid is coloured by predicted phase, projected forward from your last
recorded start using the current forecasted cycle length, so future months show
real phases instead of one cycle of colour followed by blanks. Tapping any day
opens a sheet with the phase, the cycle day and the severity for that date.
Recording a period start is one button in the header.

## Insights

Three charts and a plain-language summary. Cycle lengths are plotted in order so
a lengthening trend is visible at a glance. The second chart shows the mean and
the sample standard deviation, which is the number that decides whether the
prediction is allowed to be tight or has to widen. The third plots the last thirty
days of heat index with phase bands behind it, which is the clearest way to see
how a hot week lands in your luteal phase.

With fewer than two completed cycles the charts say so directly rather than
drawing an empty axis.

## How the forecast is made

elara-core runs several estimators over your recorded starts and reconciles them
into one date with a confidence window. The window is derived from your own
variability: when consecutive cycles differ by less than a day and a half it stays
at one day either side, and beyond that it opens to two. Until three cycles exist
the engine keeps the window wide on purpose.

The forecast feeds the phase classifier, which works out where today falls inside
the current cycle, and the action engine, which converts that phase plus the
environmental severity into a suggestion. All of it is deterministic, so the same
history and the same day produce the same answer.

## Weather and air

Elara reads temperature, humidity, sunshine and PM2.5 for your coordinates from
Open-Meteo and Open-AQ, computes the Steadman heat index locally, and caches the
result for three hours. When a lookup fails it falls back to a seasonal baseline
built for Bangladesh, and labels the figure as an estimate in the interface so a
monsoon average is never mistaken for a measurement.

The severity modifier combines heat, air quality, hydration and sunshine into one
number that nudges the day's guidance up or down.

## Reminders

Five kinds of notification, each switched on and off separately in settings:

The morning briefing arrives at eight with the phase, the conversation score and
one food suggestion. A PMS warning begins the morning the late luteal phase
starts, once per cycle. The ovulation window opens on the first day of the
ovulatory phase, also once per cycle. A period reminder lands on the predicted
first day. The climate alert fires at two in the afternoon when the heat index
passes forty.

Each reminder is scheduled individually and rebuilt whenever the app comes to the
foreground, so the text describes the cycle as it stands rather than as it stood
the day the schedule was created. The whole schedule is restored after a reboot.

## The app itself

Four tabs, a warm palette and one shadow. Every colour, text style and radius in
the app lives in `lib/theme/elara_theme.dart`, reachable from any widget through
`context.elara`, and the light and dark palettes are tuned so phase text clears
WCAG AA against its own background in both. Inter and Source Sans 3 are bundled
with the app, so the first launch is fully styled with the network off.

## How it is put together

```
lib/
  theme/elara_theme.dart      every colour, text style, radius and shadow
  data/                       sqflite schema, migrations, models
  services/                   climate, prediction, notifications
  models/elara_result.dart    the single aggregate the UI reads
  providers/                  cycle, prediction, climate, settings
  utils/                      moon phase, nakshatra, Hijri, phase timeline
  screens/                    today, calendar, insights, settings
  widgets/                    shared primitives
```

State is held in four providers over one shared database connection. The
prediction provider watches the cycle and settings revisions and recomputes when
either changes, so logging a period updates the calendar, the insights and the
reminder schedule without any screen knowing about the others.

Database access goes through a single helper with a versioned migration list and a
refusal to open a database written by a newer version of the app, which turns a
downgrade into a clear error instead of silent corruption.

## Running it

```
flutter pub get
flutter run
```

## Tests and analysis

```
flutter test
dart analyze --fatal-infos
```

The suite runs one hundred and twelve tests. They cover the schema and every CRUD
path against a real SQLite engine, the climate service against mocked weather for
live, cached, malformed and offline cases, the prediction service across
irregular and out-of-order history, the moon phase against published new, full and
quarter moons, the nakshatra division, the four screens in their empty and
populated states, and the provider graph. Both commands pass clean, and CI runs
them on every push and pull request.

## Releases

Pushing a tag like `v1.0.0` starts the release workflow. It runs analysis and the
test suite, decodes the signing key from repository secrets, builds a signed app
bundle and APK, publishes them on a GitHub release with notes generated from the
commits since the previous tag, and updates the landing page at
[mahimmazidul.github.io/elara-app](https://mahimmazidul.github.io/elara-app/) with
the new version and download link.

## License

GNU Affero General Public License v3.0. The full text is in [LICENSE](LICENSE).
