<div align="center">

# Elara

**An offline-first Android companion for understanding a menstrual cycle and
offering better care.**

[![CI](https://github.com/mahimmazidul/elara-app/actions/workflows/ci.yml/badge.svg)](https://github.com/mahimmazidul/elara-app/actions/workflows/ci.yml)
[![Release](https://github.com/mahimmazidul/elara-app/actions/workflows/release.yml/badge.svg)](https://github.com/mahimmazidul/elara-app/actions/workflows/release.yml)
[![Licence: AGPL-3.0](https://img.shields.io/badge/licence-AGPL--3.0-blue.svg)](LICENSE)

[Download the latest release](https://github.com/mahimmazidul/elara-app/releases/latest) ·
[Product site](https://mahimmazidul.github.io/elara-app/) ·
[Report an issue](https://github.com/mahimmazidul/elara-app/issues)

</div>

---

## What Elara is

Elara helps a partner understand menstrual-cycle patterns, remember the dates
that matter, prepare thoughtful gestures, and offer care that is actually
wanted. It runs entirely on one phone. There is no account, no sync, no
analytics, and no server holding anyone's health history.

The philosophy is narrow on purpose. A calendar can tell you roughly where a
cycle is. It cannot tell you how someone feels, what she wants, or whether she
would welcome company tonight. Elara is built around that distinction: it
describes the calendar honestly, explains its own uncertainty, and turns every
suggestion into a prompt to ask rather than a verdict to act on.

Elara does **not** claim to predict a woman's personality, emotions, consent,
romantic interest, or willingness to be close. It has no scores for a
relationship, because a relationship is not a quantity. It is not a
contraceptive and cannot confirm ovulation.

## The name

Elara is a figure in Greek mythology: a mortal princess, daughter of Orchomenus
of Boeotia in the usual account, and the mother of the giant Tityos by Zeus.
Fearing Hera's jealousy, Zeus hid the pregnant Elara beneath the earth, and she
gave birth there; Tityos is sometimes called a son of Gaia for that reason. The
earliest surviving mention is in Hesiod's *Catalogue of Women*, and the story is
told more fully by Apollodorus; Strabo records a cave on Euboea called Elarion
after her.

That is the whole of the classical material, and it is worth being exact about
what it does not say. Elara is not a lunar goddess in any ancient source, and
nothing in the myth concerns the moon, fertility, or the body. She is a mortal
woman remembered for one thing: carrying a child in hiding.

The name is a modern creative interpretation, offered openly as one. The app is
not dedicated to the mythological figure and makes no claim to continue her
cult. What the two share is a metaphor: Elara carried something quietly and for
a long time, and this app is about paying attention to something that is carried
by someone else. The moon in the interface is a design motif for that quiet
rhythm, not a claim about the myth. (A moon of Jupiter also carries the name,
named after her; that is a coincidence of astronomy, not a source for this
app's identity.)

## Who it is for

A partner who wants to be useful rather than intrusive: someone who would
rather know that the predicted date is coming than be surprised by it, and who
would rather ask what is welcome than guess from a chart.

It assumes a shared decision. This is someone else's health information, so the
app asks, records the answer, and lets it be withdrawn. It is not designed for
tracking a third party without their knowledge, and the product does not have a
mode for it.

## Features

What is in the released app today:

- **Cycle prediction from an ensemble of estimators.** Several independent
  prediction strategies are combined, and the app shows the estimate together
  with a stated window rather than a single confident date.
- **Phase classification** into menstrual, follicular, ovulatory and luteal,
  with a colour per phase that is also used for the app theme.
- **Phase-adaptive theming.** The accent follows the current phase and the page
  surfaces take a light tint of it, so the app reflects the cycle without
  becoming a colour wash. With no data the theme is neutral.
- **A month calendar** that distinguishes recorded days from projected ones,
  colouring real history more strongly than forecasts.
- **Daily guidance in words.** One suggestion and a short explanation, with a
  reminder that it is an invitation to ask, not a forecast about a person.
- **Corrections.** A recorded start can be moved or removed from the day sheet.
- **Insights** with a cycle-length history, sample standard deviation, and a
  readable summary of how steady the cycle is.
- **Environmental context.** Heat index and air quality for the chosen location,
  used to colour the guidance and cached for offline use.
- **Local astronomical detail**: moon phase, nakshatra and Hijri date, all
  computed on the device with no network call.
- **Notifications** for the daily briefing, the late luteal phase, the estimated
  fertile window, the expected period, and heat or air-quality spikes.
- **Private by default.** Reminders are marked private for the lock screen and
  carry no cycle wording unless you ask for it.
- **Encrypted backup and restore.** Export is encrypted with a passphrase you
  choose and is handed to your own share sheet.
- **Consent and deletion.** A gate before first use, a record of when it was
  given, and one control that withdraws it and deletes everything.

Planned work is listed under [Roadmap](#roadmap) and is not in the app yet.

## Screenshots

Taken from the app by `tool/screenshots/screenshots_test.dart` and refreshed by
CI, so they cannot drift from the build.

<table>
  <tr>
    <td align="center"><img src="docs/screenshots/today.png" width="220" alt="Today screen: phase chip, days until the next predicted period, today's climate, and a guidance card"><br><sub><b>Today</b></sub></td>
    <td align="center"><img src="docs/screenshots/calendar.png" width="220" alt="Month calendar with each day shaded by phase and a legend explaining recorded versus projected days"><br><sub><b>Calendar</b></sub></td>
    <td align="center"><img src="docs/screenshots/insights.png" width="220" alt="Insights screen with a cycle length history chart and an average with standard deviation"><br><sub><b>Insights</b></sub></td>
  </tr>
  <tr>
    <td align="center"><img src="docs/screenshots/settings.png" width="220" alt="Settings screen with location, theme and per-notification switches"><br><sub><b>Settings</b></sub></td>
    <td align="center"><img src="docs/screenshots/today-dark.png" width="220" alt="The Today screen in the dark palette"><br><sub><b>Today, dark</b></sub></td>
    <td align="center"><img src="docs/screenshots/today-action.png" width="220" alt="The guidance cards on the Today screen in light mode"><br><sub><b>Guidance</b></sub></td>
  </tr>
  <tr>
    <td align="center"><img src="docs/screenshots/settings-privacy.png" width="220" alt="The privacy and data card in Settings: consent status with a withdraw control, a reminder-privacy switch that is off, and export and restore buttons"><br><sub><b>Privacy and data</b></sub></td>
    <td align="center"><img src="docs/screenshots/today-action-dark.png" width="220" alt="The guidance cards in the dark palette"><br><sub><b>Guidance, dark</b></sub></td>
    <td></td>
  </tr>
</table>

<p align="center">
  <img src="docs/screenshots/tablet.png" width="640" alt="The Insights tab on a tablet, with a navigation rail on the left and content in a centred column">
  <br>
  <sub>Above 720dp the tab bar becomes a navigation rail and the content keeps a readable measure.</sub>
</p>

## How the prediction works

Cycle dates are the only input. From a series of recorded period starts, the
engine derives completed cycle lengths, then produces a point estimate and an
uncertainty window for the next start.

Three independent estimators run against the same history. One reasons from the
recent lengths with an explicit statistical model, one weights recent cycles more
heavily than older ones, and one is conservative about short histories. Each
reports its own confidence, and their outputs are combined into a
confidence-weighted consensus rather than an average of opinions.

Two rules keep the combination honest:

- **An observed start beats a forecast.** If the user records a period, that date
  is a fact and no estimator's opinion can outvote it. The prediction is the
  observation, with a window of zero.
- **No engine may contradict itself.** Every estimator must return a date and a
  cycle length that agree with each other; the fusion layer throws if one does
  not, rather than quietly preferring the more convenient number.

The **window** is what the app shows beside the estimate, and it comes from the
observed variability of the user's own history, widened when there are few
cycles to learn from. It is presented as a range, never as a guarantee, and the
app never implies that the predicted day is confirmed.

Phase classification is a separate step: given a start date and a cycle length,
each date is classified into a phase. When a period is overdue, the classifier
refuses to wrap silently into the next cycle, because a prediction that quietly
restarts is worse than one that admits it is stale.

**What is deliberately absent.** No machine learning. A learned model would need
either data that leaves the device, which this app will not do, or a training set
that does not exist for a single user's history. The statistical approach is
measurable, explainable, and can be checked with the tests below. If a learned
model could be shown to improve accuracy measurably without either of those
costs, this decision would be revisited.

The engine lives in a separate repository,
[elara-core](https://github.com/mahimmazidul/elara-core), so it can be tested
independently of the UI.

## Offline first, and privacy

The app works with the radio off. Cycle history, settings, the prediction, the
astronomy, and the guidance are all computed on the device with no network
access. Two things use the internet, both optional and both benefiting from
cache:

- **Open-Meteo** for the heat index, and **Open-AQ** for air quality. Only the
  coordinates you enter are sent, never cycle data. The air-quality lookup
  prefers a monitoring station in the same country and falls back to a
  neighbouring one, so it works outside Bangladesh but is most accurate where
  stations are dense.
- Nothing else. There is no analytics SDK, no crash reporter, no advertising
  identifier, and no account system.

Data handling, concretely:

- Cycle history lives in a private SQLite database inside the app's sandbox.
- Nothing is uploaded. There is no backup to a server, so an uninstalled app is
  a deleted history.
- Notifications are posted with `NotificationVisibility.private`, and their text
  contains no cycle wording unless you turn that on. Off is the default.
- The export file is encrypted with AES-256-GCM under a key stretched from a
  passphrase you choose using PBKDF2. Elara does not store the passphrase: a
  forgotten passphrase means an unreadable file, which is the honest trade.
- Consent is recorded with a timestamp and can be withdrawn. Withdrawing deletes
  the cycle history, the settings and the record itself, and closes the app
  behind the consent gate again.

## Supported versions and installation

- **Android 7.0 (API 24) and newer.** No other platform is supported: there is
  no iOS, web or desktop build.
- Install from the [latest release](https://github.com/mahimmazidul/elara-app/releases/latest).
  Four APKs are published: `arm64-v8a` for almost every phone made since 2015,
  `armeabi-v7a` for older 32-bit devices, `x86_64` for emulators, and a
  `universal` build that works everywhere and is the one to choose if unsure.
  There is also an `.aab` for store distribution.
- Releases are signed; the release workflow verifies the signature by parsing
  the APK before publishing.
- No permissions are requested beyond notifications, exact alarms for punctual
  reminders, and boot-completed so the schedule survives a restart. Location is
  typed in, not read from the device.

## Development setup

Requirements: Flutter with Dart 3.10 or newer (the CI uses the 3.47 stable line)
and an Android SDK for running on a device or emulator. No Android SDK is needed
for the test suite.

```bash
git clone https://github.com/mahimmazidul/elara-app.git
cd elara-app
flutter pub get
flutter test          # runs the whole suite on the Dart VM
flutter run           # needs a connected Android device or emulator
```

`elara-core` is a git dependency pinned by ref in `pubspec.yaml`, so `pub get`
resolves it without any extra setup.

## Architecture

```
lib/
  main.dart              provider graph, theme wiring, the consent gate
  data/                  SQLite schema, migrations, models
  providers/             ChangeNotifier state: cycles, prediction, settings, consent
  screens/               one directory per tab, plus consent
  services/              prediction, climate, notifications, backup
  theme/                 every colour, type style and spacing value
  utils/                 phase timeline, moon phase, nakshatra, Hijri date
  widgets/               shared primitives
```

Three decisions shape most of the code:

**One provider graph, wired in `main.dart`.** Providers are ordered by
dependency, and nothing constructs its own database connection. A mutation bumps
a revision counter and its dependents recompute, so there is exactly one path
from "user logged a date" to "the calendar, the theme and the notification
schedule are current".

**All colour lives in `lib/theme/elara_theme.dart`.** No widget hardcodes a
colour. The palette is derived per phase, and every ink is contrast-corrected
against the surface it will sit on, so adding a phase cannot quietly produce
text below the WCAG AA ratio. A test asserts this for all eight theme and phase
combinations.

**The storage layer is the only place that speaks SQL.** `DatabaseHelper` owns
the schema, the migrations and every query. Migrations are an ordered list where
each entry upgrades exactly one version, and a downgrade throws rather than
letting an older build read a newer file.

Dependencies, and why each is there:

| Package | Purpose |
| --- | --- |
| `elara_core` | The prediction and phase engine, as a git dependency. |
| `provider` | State management, small and testable. |
| `sqflite` | Local SQLite storage. |
| `flutter_local_notifications`, `android_alarm_manager_plus`, `timezone` | Scheduled reminders that survive a reboot. |
| `fl_chart` | The cycle-length and climate charts. |
| `http` | Weather and air quality only. |
| `intl`, `hijri` | Date formatting and the Hijri calendar. |
| `cryptography` | AES-GCM and PBKDF2 for the encrypted backup. Pure Dart. |
| `share_plus` | Hands the encrypted backup to the system share sheet. |

The bundled typeface is DM Sans at 400, 500 and 700, built by
`tool/fonts/build_fonts.py`. Upstream ships proportional digits without a
tabular-figure feature, so the script adds a real `tnum` lookup; without it the
tabular numerals the design asks for would silently do nothing.

## Testing and releases

```bash
dart analyze --fatal-infos   # must be clean
flutter test                 # the whole suite
```

Test suites live under `test/`, grouped by layer: `data/` for the schema,
migrations and every CRUD path against real SQLite; `providers/` for the state
machines including consent; `services/` for prediction, climate, backups and
notification privacy; `widgets/` for the screens at several sizes and text
scales; `theme/` for contrast in every phase and theme.

The screenshots are generated by a test (`tool/screenshots/screenshots_test.dart`)
and refreshed by CI, so the images in this README come from the build rather
than from a designer's mockup.

Releases are cut by the Release workflow, which builds per-ABI APKs and an AAB,
verifies the signature, and publishes a GitHub release. The version shown in
Settings comes from `lib/app_info.dart`, and a test fails the build if it
disagrees with `pubspec.yaml`.

## Limitations

Stated plainly, because the alternative is someone trusting a number they
should not:

- **Prediction accuracy depends on cycle regularity.** A cycle that varies by a
  week cannot be predicted to the day, whatever the app displays. The stated
  window widens when the history is variable, and for irregular cycles the true
  date falls outside that window more often than for regular ones.
- **Phases are calendar estimates, not measurements.** No hormone is measured. An
  "ovulatory phase" label means a date arithmetic put it there, not that
  ovulation was detected or confirmed.
- **Short histories are weak.** With one or two recorded cycles the estimate is
  little more than a population average.
- **Elara is not a medical device and not a contraceptive.** It must not be used
  to avoid or to achieve pregnancy, and it cannot diagnose anything. Unusual
  bleeding, severe pain, or a cycle that changes suddenly are reasons to see a
  clinician, not to consult an app.
- **Android only**, and only API 24 and above.
- **No sync.** Losing the phone loses the history unless an encrypted backup was
  exported. That is the cost of not having a server.
- **Consent cannot be verified.** Elara records that the user said they had
  talked with their partner. It cannot check that, and it says so on screen.
- **Aggressive battery managers** on some Android skins can delay or drop
  background alarms. Reminders are rebuilt whenever the app is opened.

## Roadmap

Released: everything described under [Features](#features).

Next, in rough priority order. None of this is in the app yet.

- Preferences the partner can fill in herself, so guidance reflects what she
  actually finds helpful instead of what a date suggests.
- Symptom logging, used only to soften or skip a suggestion.
- Calibrating the prediction window so the stated range reflects measured
  coverage rather than an estimate of it.
- A reminder the day before a predicted start, to prepare rather than react.
- Optional encryption of the local database.

## Contributing

Issues and pull requests are welcome at
[github.com/mahimmazidul/elara-app](https://github.com/mahimmazidul/elara-app).

Before opening a pull request, run `dart analyze --fatal-infos` and
`flutter test`, and add a test for anything that touches data, privacy or the
prediction. The project conventions worth knowing:

- No colour outside `lib/theme/elara_theme.dart`.
- No new dependency without a stated reason in the pull request.
- No numerical scores describing a person, anywhere in the UI, notifications, or
  exports.
- No feature that could be used to monitor someone's cycle without their
  knowledge.
- Wording should describe the calendar and offer a suggestion, never assert how
  someone feels.

## Licence

Elara is released under the [GNU Affero General Public License v3.0](LICENSE).
You are free to use, study, modify and distribute it, and if you run a modified
version as a network service you must offer its source under the same terms.
