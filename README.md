<div align="center">

<img src="docs/icon.png" width="112" height="112" alt="Elara's app icon: a warm white crescent moon with a small gold circle beside it, on a deep plum background">

# Elara

**A quiet Android companion for understanding a menstrual cycle, and for caring
about the person living it.**

[![Android](https://img.shields.io/badge/Android-7.0%2B-3DDC84?logo=android&logoColor=white)](#install)
[![Flutter](https://img.shields.io/badge/Flutter-3.47-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![License: AGPL-3.0](https://img.shields.io/badge/license-AGPL--3.0-blue.svg)](LICENSE)
[![Latest release](https://img.shields.io/github/v/release/mahimmazidul/elara-app?label=release&color=D4956A)](https://github.com/mahimmazidul/elara-app/releases/latest)
[![CI](https://github.com/mahimmazidul/elara-app/actions/workflows/ci.yml/badge.svg)](https://github.com/mahimmazidul/elara-app/actions/workflows/ci.yml)

**Download** · [Website](https://mahimmazidul.github.io/elara-app/) · [Docs](docs/) · [Privacy](docs/PRIVACY_MODEL.md) · [How prediction works](docs/PREDICTION.md)

</div>

---

A calendar can tell you roughly where a cycle is. It cannot tell you how someone
feels, or whether she would rather have company or quiet tonight.

Elara states what it actually knows — the dates it was given — shows how sure it
is with a window instead of a confident single day, and turns the rest into
something a partner can do. The most useful line on the home screen is not the
countdown. It is the one under a suggestion that says *"she told you this"*,
because that is the difference between care and guessing.

Everything stays on one phone, in the app's own storage.

## Screens

<p align="center">
<img src="docs/screenshots/today.png" width="240" alt="Today: an estimated-phase dial, a countdown to the next period with its window, and care suggestions labelled with where they came from">
<img src="docs/screenshots/insights.png" width="240" alt="Insights: three rows — cycle length, how steady it is, and how the prediction was made — each summarising before it makes you open it">
</p>
<p align="center">
<img src="docs/screenshots/settings.png" width="240" alt="Settings: three glass panels of rows, one subject each, every row carrying the line that says whether it needs opening">
<img src="docs/screenshots/today-action.png" width="240" alt="The advice section: a personal suggestion, then general guidance for the phase with its sources">
</p>

<sub>Real renders of the running app over a fixed fictional dataset, from
`tool/screenshots/screenshots_test.dart`. Full-size originals in
[`docs/screenshots/`](docs/screenshots).</sub>

## What it does

- **A phase, with its uncertainty.** Three estimators run on recorded period
  starts — recent mean, recency-weighted mean, dispersion-aware — and agree on a
  date with a window. A short or irregular history widens the window instead of
  hiding it. Cycles from 30 to 120 days are handled; the 28-day default is not
  assumed anywhere.
- **Advice in two layers.** Personal first: what she told you she likes, what she
  reported feeling, what you noticed, what the weather is doing. Then general
  guidance for the phase, each item with its source — WHO on iron and fluids,
  NICE and NHS on cramps and PMS, BIRDEM on what a Bangladeshi plate contains.
  Nothing general can outrank something she actually said.
- **Today is a screen, not a feed.** Hero dial, the countdown, the guidance, then
  three rows — notes, weather, moon and calendars — each opening a page of its
  own. Swipe left or right anywhere on the content to move between tabs.
- **A calendar that admits what it is.** Filled means recorded, dashed means
  predicted, and a day with nothing known shows an em dash rather than a zero.
- **Non-textbook bodies.** Hormonal contraception, pregnancy, loss and a
  deliberate pause each switch prediction off with a stated reason, and keep the
  advice that does not depend on a forecast.
- **Health information, kept apart.** Period pain, heavy bleeding, irregular
  periods, PMS, PMDD, PCOS, endometriosis and pain relief, from dated published
  sources. General guidance, labelled as general on every page.
- **Bangladesh by default.** Heat index rather than air temperature, PM2.5, four
  local seasons, Hijri and nakshatra alongside the Gregorian date, reminder text
  that stays off a lock screen.

## Privacy

One cycle history, on one phone, in the app's own sandbox. Auto Backup is off at
the manifest level, so the history stays where it was written. Export is a
passphrase-encrypted file containing the dates, and one control withdraws consent
and deletes everything. Detail: [`docs/PRIVACY_MODEL.md`](docs/PRIVACY_MODEL.md).

## Install

Android 7.0 or newer. Take the APK from
[releases](https://github.com/mahimmazidul/elara-app/releases/latest) and open it;
Play Protect may ask once about installing from outside the store.

## Develop

```bash
flutter pub get
flutter test                 # the whole suite, no device needed
flutter analyze
flutter run
```

`tool/check_manifest.py` asserts the manifest, the privacy controls, the cutout
mode and the launch colour; CI runs it alongside the tests, the font check and
the screenshot suite. Prediction methodology and its calibration:
[`docs/PREDICTION.md`](docs/PREDICTION.md),
[`docs/PREDICTION_CALIBRATION.md`](docs/PREDICTION_CALIBRATION.md).

## Layout

| Path | What lives there |
| --- | --- |
| `lib/screens/` | One folder per tab, plus the sub-pages behind them |
| `lib/widgets/` | `ElaraGlass`, `ElaraSubPage`, `PhaseDial`, `ElaraListRow`, primitives |
| `lib/theme/` | Palettes, type scale, spacing, motion |
| `lib/data/` | Schema, models, the health content shelf |
| `lib/services/` | Prediction bridge, backup, notifications, care recommender |
| `elara-core/` | The prediction and action engine, a separate Dart package |

## Limits

Elara is a record and an estimate built from it. It works from the dates you
log, which is the whole of its input, and where contraception or a diagnosis is
the question it points you to a clinician: a fertile window guessed from a
calendar makes no day safe, and the app says so where it matters.

## The name

Elara is a mortal woman in Greek myth — daughter of Orchomenus, mother of the
giant Tityos by Zeus — who carried her child hidden beneath the earth. That is
the whole of the classical material, and it says nothing about the moon,
fertility or the body; she is not a lunar goddess in any ancient source, though a
moon of Jupiter carries her name. The name here is a modern, open reading of one
thing the two share: something carried quietly, for a long time, by someone else.
The moon in the interface is a motif for that rhythm, not a claim about the myth.

## Questions

**Where is my data kept?**
On this phone, in the app's own storage. Elara makes two kinds of request: a
weather forecast for the district you pick, and an update check you switch
on yourself. Auto Backup is off at the manifest level, so the history stays where
it was written; moving it to another phone is the encrypted export you run.

**How accurate is the estimate?**
It depends entirely on the history. Three estimators run on your recorded period
starts and the app shows the window they agree on — a steady history gives a day
or two, an irregular one gives a week, and a history too short to say anything
gets an explanation rather than an invented date. It is arithmetic on the dates
you log, and where contraception is the question it points you to a clinician.
Method and calibration: [`docs/PREDICTION.md`](docs/PREDICTION.md).

**What if I am on the pill, pregnant, or have just given birth?**
You tell it once and it stops forecasting, with the reason on the home screen.
Pills, implants, injections and hormonal IUDs stop ovulation, so there is no
cycle to estimate. Everything that does not depend on a forecast — notes,
reminders, health information — stays.

**Is it only for couples?**
No. It is written for one person to use, and the partner-facing suggestions are a
layer on top rather than the point. Alone it is a cycle log that refuses to
pretend to certainty; used together, the suggestions are a way of being useful
without asking someone to explain herself every evening.

**Can I get my data out?**
As one encrypted file under a passphrase you choose, containing the dates and
nothing else. Restore puts it back on the same or a new phone. One button
withdraws consent and deletes everything on this one.

**Why Bangla fonts and Hijri dates?**
Because the phone it is written for is in Bangladesh. Heat index matters more
than air temperature for most of the year, and a calendar showing Hijri and
nakshatra beside the Gregorian date is normal here rather than exotic. The
prediction does not change either way.

**Why not the Play Store?**
A listing would need an account and a data-safety form to say what this page
says: nothing is collected. The APK is built from the same source, signed, and
published on the releases page.

## Credits

Built by [Md. Mazidul Islam Mahim](https://github.com/mahimmazidul). Typeface:
[Hind Siliguri](https://fonts.google.com/specimen/Hind+Siliguri) (SIL OFL).
Ideas and prior art: OpenCiclo (Apache-2.0), Flowlytics (AGPL-3.0), DRIP.
Licensed [AGPL-3.0](LICENSE).
