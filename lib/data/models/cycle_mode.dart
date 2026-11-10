import '../../providers/settings_keys.dart';

/// Why Elara is, or is not, predicting a next period.
///
/// This exists because a calendar estimate is only meaningful when there is a
/// cycle to estimate. Three states in this app's intended population produce
/// bleeding that is not an ovulatory cycle, and for all three the engine's
/// arithmetic is not merely imprecise but inapplicable:
///
///   * hormonal contraception — the combined pill, the implant, the injection
///     and most IUDs suppress ovulation, so bleeding is withdrawal or
///     breakthrough rather than the end of a luteal phase. A phase countdown
///     invented from those dates describes nothing that is happening in her
///     body. In Bangladesh, where around six in ten married women use a modern
///     method and oral pills are the most common one, this is not an edge case;
///     it is plausibly a majority of the women this app is installed for.
///   * pregnancy, a loss, and the months after a birth — bleeding stops, then
///     starts again on a schedule that has nothing to do with the previous one.
///     A countdown that keeps insisting a period is `4 days late` through a
///     miscarriage is the single cruellest thing this app could do.
///   * perimenopause — cycles lengthen and shorten unpredictably, and the
///     honest output is a range with a wide window, which the app can already
///     show, plus the choice to stop being told a date.
///
/// Nothing here diagnoses anything. The mode is a statement about what the app
/// should claim, and the user is the only one who can make it.
enum CycleMode {
  /// Predict from recorded history, as designed.
  predicting,

  /// No forecast, because hormonal contraception means there is no ovulatory
  /// cycle to forecast.
  hormonalContraception,

  /// No forecast for a stated reason: pregnancy, a loss, after a birth, or
  /// something the app does not need to know.
  paused;

  /// Whether a forecast may be produced in this mode. The one place that
  /// decides, so a screen cannot accidentally disagree with the engine.
  bool get predicts => this == CycleMode.predicting;

  /// One line for the settings hub, so the current mode is legible without
  /// opening the page. It states the mode, not a judgement about it.
  String get summary {
    switch (this) {
      case CycleMode.predicting:
        return 'Estimating the next period from recorded history';
      case CycleMode.hormonalContraception:
        return 'No forecast: no ovulatory cycle to estimate';
      case CycleMode.paused:
        return 'Paused: no forecast, nothing removed';
    }
  }

  String get storageKey {
    switch (this) {
      case CycleMode.predicting:
        return 'predicting';
      case CycleMode.hormonalContraception:
        return 'hormonal_contraception';
      case CycleMode.paused:
        return 'paused';
    }
  }

  static CycleMode fromStorageKey(String? key) {
    switch (key) {
      case 'hormonal_contraception':
        return CycleMode.hormonalContraception;
      case 'paused':
        return CycleMode.paused;
      case 'predicting':
        return CycleMode.predicting;
      default:
        // An unreadable value must not silently switch on a claim the user has
        // switched off, and it must not silently switch off the app's main
        // feature either. Nothing stored (`null`) and an explicitly cleared
        // row (`''`) both mean "never chosen", which is the default. A value
        // that is present and unreadable can only come from a version of this
        // app that is newer than this one, so it is treated as a pause: the
        // safe failure for a claim about a body is silence.
        return (key == null || key.isEmpty)
            ? CycleMode.predicting
            : CycleMode.paused;
    }
  }
}

/// The reason a [CycleMode.paused] user is paused. Optional, and the app never
/// requires it: "something else" has to exist, because the app is not entitled
/// to a reason for a miscarriage to stop counting days at someone.
enum PauseReason {
  pregnancy,
  loss,
  postpartum,
  other;

  String get storageKey {
    switch (this) {
      case PauseReason.pregnancy:
        return 'pregnancy';
      case PauseReason.loss:
        return 'loss';
      case PauseReason.postpartum:
        return 'postpartum';
      case PauseReason.other:
        return 'other';
    }
  }

  static PauseReason? fromStorageKey(String? key) {
    switch (key) {
      case 'pregnancy':
        return PauseReason.pregnancy;
      case 'loss':
        return PauseReason.loss;
      case 'postpartum':
        return PauseReason.postpartum;
      case 'other':
        return PauseReason.other;
      default:
        return null;
    }
  }
}

/// Reads the mode out of a settings map, so the engine and the screen agree.
///
/// Kept as a free function rather than a method on [SettingsProvider] because
/// [PredictionService] reads settings straight from the database (it runs in
/// the notification isolate too, where there is no provider tree).
CycleMode cycleModeFromSettings(Map<String, String> settings) =>
    CycleMode.fromStorageKey(settings[SettingsKeys.cycleMode]);

PauseReason? pauseReasonFromSettings(Map<String, String> settings) =>
    PauseReason.fromStorageKey(settings[SettingsKeys.pauseReason]);
