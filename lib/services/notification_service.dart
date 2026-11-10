import 'dart:async';
import 'dart:ui' show DartPluginRegistrant;

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:elara_core/elara_core.dart' as core;
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../data/database_helper.dart';
import '../data/date_keys.dart';
import '../models/elara_result.dart';
import '../providers/settings_keys.dart';
import '../utils/phase_timeline.dart';
import 'notification_privacy.dart';
import 'prediction_service.dart';

/// The five reminder kinds Elara can show.
///
/// Each owns a disjoint block of notification ids (see [idBase]) so one type can
/// be cancelled without touching the others and a schedule can never collide
/// with another type's id.
enum ElaraNotificationType {
  dailyBriefing(idBase: 1000, settingKey: SettingsKeys.notifyDailyBriefing),
  pmsWarning(idBase: 2000, settingKey: SettingsKeys.notifyPmsWarning),
  ovulationWindow(
    idBase: 3000,
    settingKey: SettingsKeys.notifyOvulationWindow,
  ),
  periodStart(idBase: 4000, settingKey: SettingsKeys.notifyPeriodStart),
  climateSpike(idBase: 5000, settingKey: SettingsKeys.notifyClimateSpike);

  const ElaraNotificationType({required this.idBase, required this.settingKey});

  /// First id in this type's block; ids run `idBase + index`.
  final int idBase;

  /// Settings key that switches this type on or off.
  final String settingKey;

  /// Android channel id. One channel per type, so a user can also silence a
  /// type from Android's own notification settings and the two levels agree.
  String get channelId => 'elara_$name';

  String get channelName {
    switch (this) {
      case ElaraNotificationType.dailyBriefing:
        return 'Daily briefing';
      case ElaraNotificationType.pmsWarning:
        return 'PMS warning';
      case ElaraNotificationType.ovulationWindow:
        return 'Ovulation window';
      case ElaraNotificationType.periodStart:
        return 'Period start';
      case ElaraNotificationType.climateSpike:
        return 'Climate spike';
    }
  }

  /// Every id this type may use, for cancellation.
  Iterable<int> get ids => Iterable<int>.generate(64, (i) => idBase + i);
}

/// The one thing the UI needs from the reminder layer.
///
/// An interface rather than the concrete service, so Settings can rebuild the
/// schedule after a privacy or data change without a widget test having to stand
/// up an Android plugin.
abstract class NotificationRescheduler {
  /// Cancels what is queued and rebuilds it from current data. Never throws.
  Future<void> reschedule();
}

/// Schedules Elara's reminders on the device. Offline; no network, no Firebase.
///
/// Three decisions shape the implementation:
///
///  * **Content is computed per occurrence, not once.** A single repeating daily
///    alarm keeps the text captured when it was first scheduled, so a week later
///    the briefing would still describe today's phase. Instead each occurrence is
///    scheduled individually with its own text over a short [horizonDays] window,
///    and the whole set is rebuilt whenever the app comes to the foreground and
///    once a day by the AlarmManager callback.
///  * **Exactness is negotiated.** Android 14 gates exact alarms behind a
///    permission. Scheduling uses an exact alarm when the user has granted it and
///    an inexact one otherwise, so reminders still arrive when permission was
///    never granted instead of throwing.
///  * **Failures degrade.** Anything that goes wrong leaves fewer reminders, never
///    a crash: the companion app has to keep working regardless.
///  * **The lock screen is assumed to be public.** Every notification is posted
///    with `NotificationVisibility.private` and, unless the user has explicitly
///    opted in, carries no phase, cycle or symptom wording at all. Redaction is
///    applied in [_schedule], the single choke point, so a new reminder type
///    cannot forget it.
class NotificationService implements NotificationRescheduler {
  NotificationService({
    DatabaseHelper? database,
    PredictionService? predictionService,
    FlutterLocalNotificationsPlugin? plugin,
    DateTime Function()? clock,
  })  : _database = database ?? DatabaseHelper.instance,
        _predictionService = predictionService ?? PredictionService(),
        _plugin = plugin ?? FlutterLocalNotificationsPlugin(),
        _clock = clock ?? DateTime.now;

  final DatabaseHelper _database;
  final PredictionService _predictionService;
  final FlutterLocalNotificationsPlugin _plugin;
  final DateTime Function() _clock;

  /// Days of daily briefings kept scheduled. Seven keeps the text fresh without
  /// filling the alarm queue; Samsung devices reportedly cap AlarmManager at 500
  /// alarms and this stays far below that.
  static const int horizonDays = 7;

  /// Wider window for the once-per-cycle types.
  static const int cycleHorizonDays = 45;

  static const int briefingHour = 8;
  static const int climateHour = 14;

  /// The level the brief asks us to alert on.
  static const double climateSpikeThreshold = 40;

  static const int _backgroundAlarmId = 900;

  /// The notification icon, as a bare drawable resource name.
  ///
  /// Two things were wrong with the previous value, `'@mipmap/ic_launcher'`,
  /// and either one alone makes the status-bar icon fail:
  ///
  ///  * The plugin resolves this string with
  ///    `getIdentifier(name, "drawable", package)`. A launcher icon lives in
  ///    `mipmap`, and the `@mipmap/...` prefix is not a resource name, so the
  ///    lookup returns 0 and the notification is posted with no small icon at
  ///    all — which Android draws as an empty space or a plain white square.
  ///  * Even resolvable, a launcher icon is a full-colour opaque square.
  ///    Android masks a status-bar icon to its alpha channel and tints it, so
  ///    an opaque square becomes a solid block.
  ///
  /// `ic_stat_elara` is a dedicated monochrome vector drawable in
  /// `android/app/src/main/res/drawable/`. Android's naming rule is that
  /// launcher icons go in `mipmap` and everything else in `drawable`; a
  /// notification icon is `drawable`.
  static const String notificationIconName = 'ic_stat_elara';

  /// Defaults handed to the plugin; the per-notification payload carries the
  /// same icon name, so a payload-level mistake cannot reintroduce the bug.
  static const AndroidInitializationSettings _androidInit =
      AndroidInitializationSettings(notificationIconName);

  bool _initialised = false;

  /// Whether reminder text may name the phase or the cycle. Read once per
  /// `rescheduleAll`; false unless the user opted in.
  bool _previewDetails = SettingsKeys.defaultNotifyPreviewDetails;

  /// Prepares the plugin and the timezone database. Safe to call repeatedly.
  Future<void> init() async {
    if (_initialised) return;
    tzdata.initializeTimeZones();
    tz.setLocalLocation(_resolveLocalLocation());
    await _plugin.initialize(
      settings: const InitializationSettings(android: _androidInit),
    );
    await _createChannels();
    _initialised = true;
  }

  /// Resolves the device's timezone to a zone in the bundled database.
  ///
  /// `flutter_timezone` is not a dependency, so the IANA name is not available
  /// and has to be inferred from the current UTC offset. Two instants are
  /// compared — now and roughly six months out — so a zone with the same offset
  /// but different daylight-saving rules is rejected in favour of one matching
  /// at both points. If nothing matches, UTC is used, which is at worst a fixed
  /// offset error for a device in an exotic zone.
  static tz.Location _resolveLocalLocation() {
    final now = DateTime.now();
    final nowOffset = now.timeZoneOffset;
    final laterInstant = now.add(const Duration(days: 182));
    final laterOffset = laterInstant.timeZoneOffset;

    tz.Location? partialMatch;
    for (final location in tz.timeZoneDatabase.locations.values) {
      final atNow = tz.TZDateTime.from(now, location).timeZoneOffset;
      if (atNow != nowOffset) continue;
      final atLater = tz.TZDateTime.from(laterInstant, location).timeZoneOffset;
      if (atLater == laterOffset) return location;
      partialMatch ??= location;
    }
    return partialMatch ?? tz.UTC;
  }

  /// One channel per notification type. Android fixes a channel's settings at
  /// creation, which is why each type gets its own rather than one shared.
  Future<void> _createChannels() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;

    for (final type in ElaraNotificationType.values) {
      await android.createNotificationChannel(
        AndroidNotificationChannel(
          type.channelId,
          type.channelName,
          description: 'Elara reminders: ${type.channelName.toLowerCase()}',
          importance: Importance.defaultImportance,
        ),
      );
    }
  }

  /// Asks for the OS notification permission (Android 13+).
  Future<bool> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return false;
    try {
      return await android.requestNotificationsPermission() ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Whether the OS will accept notifications from Elara at all.
  Future<bool> areNotificationsEnabled() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return false;
    try {
      return await android.areNotificationsEnabled() ?? false;
    } catch (_) {
      return false;
    }
  }

  /// True when exact alarms may be used; false means reminders fall back to
  /// inexact scheduling and can drift by a few minutes.
  Future<bool> canScheduleExact() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return false;
    try {
      return await android.canScheduleExactNotifications() ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Asks the OS for exact-alarm permission. Only needed for to-the-minute
  /// delivery; declining keeps reminders, just less punctually.
  Future<void> requestExactAlarmPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    try {
      await android?.requestExactAlarmsPermission();
    } catch (_) {
      // Ignored: the fallback is an inexact schedule.
    }
  }

  /// [NotificationRescheduler]: rebuilds the schedule from current data.
  @override
  Future<void> reschedule() => rescheduleAll();

  /// Rebuilds every reminder from current data and settings.
  ///
  /// Cancels first: the cycle position, the predicted date and the user's
  /// switches can all have changed since the last run, so adding to the existing
  /// set would leave stale notifications behind.
  ///
  /// Never throws.
  Future<void> rescheduleAll() async {
    try {
      await init();
      await cancelAll();

      _previewDetails = await _settingBool(
        SettingsKeys.notifyPreviewDetails,
        SettingsKeys.defaultNotifyPreviewDetails,
      );

      if (!await _notificationsAllowed()) {
        await cancelBackgroundReschedule();
        return;
      }

      final result = await _currentPrediction();
      if (result == null) return;

      final latestStart = await _latestStartDate(result);
      if (latestStart == null) return;

      final timeline = PhaseTimeline(
        lastPeriodStart: latestStart,
        cycleLength: result.cycleLength,
        today: _clock(),
      );

      final mode = (await canScheduleExact())
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle;

      // Severity is computed once and reused for the week: it depends on the
      // climate, which does not shift meaningfully between mornings, and one
      // lookup per day would mean a network round trip per alarm.
      final severity = result.severity;

      if (await _isTypeEnabled(ElaraNotificationType.dailyBriefing)) {
        await _scheduleDailyBriefings(result, timeline, severity, mode);
      }
      if (await _isTypeEnabled(ElaraNotificationType.pmsWarning)) {
        await _schedulePmsWarning(timeline, mode);
      }
      if (await _isTypeEnabled(ElaraNotificationType.ovulationWindow)) {
        await _scheduleOvulationWindow(timeline, mode);
      }
      if (await _isTypeEnabled(ElaraNotificationType.periodStart)) {
        await _schedulePeriodStart(result, mode);
      }
      if (await _isTypeEnabled(ElaraNotificationType.climateSpike)) {
        await _scheduleClimateSpike(result, mode);
      }

      await _ensureBackgroundReschedule(mode);
    } catch (error, stack) {
      debugPrint('Elara: rescheduleAll failed: $error\n$stack');
    }
  }

  Future<bool> _notificationsAllowed() async {
    if (!await _settingBool(SettingsKeys.notificationEnabled, true)) {
      return false;
    }
    return areNotificationsEnabled();
  }

  Future<bool> _isTypeEnabled(ElaraNotificationType type) =>
      _settingBool(type.settingKey, _defaultFor(type));

  static bool _defaultFor(ElaraNotificationType type) {
    switch (type) {
      case ElaraNotificationType.dailyBriefing:
        return SettingsKeys.defaultNotifyDailyBriefing;
      case ElaraNotificationType.pmsWarning:
        return SettingsKeys.defaultNotifyPmsWarning;
      case ElaraNotificationType.ovulationWindow:
        return SettingsKeys.defaultNotifyOvulationWindow;
      case ElaraNotificationType.periodStart:
        return SettingsKeys.defaultNotifyPeriodStart;
      case ElaraNotificationType.climateSpike:
        return SettingsKeys.defaultNotifyClimateSpike;
    }
  }

  Future<bool> _settingBool(String key, bool fallback) async {
    try {
      final raw = await _database.getSetting(key);
      if (raw == 'true') return true;
      if (raw == 'false') return false;
      return fallback;
    } catch (_) {
      return fallback;
    }
  }

  Future<ElaraResult?> _currentPrediction() async {
    try {
      return await _predictionService.predict();
    } catch (_) {
      return null;
    }
  }

  /// The last recorded period start, which the phase projection anchors on.
  ///
  /// Read from the database rather than derived from the forecast, because
  /// derivation would silently be wrong the moment the engine's notion of "next
  /// start" changes (an observed start, for instance).
  Future<DateTime?> _latestStartDate(ElaraResult result) async {
    try {
      final latest = await _database.getLatestCycle();
      if (latest != null) return latest.startDate;
    } catch (_) {
      // Fall through to the derived value.
    }
    return result.nextPeriodDate.subtract(Duration(days: result.cycleLength));
  }

  // -------------------------------------------------------------- scheduling --

  /// One briefing per day at 08:00 for the next [horizonDays] days, each with
  /// that day's own phase, conversation score and first food suggestion.
  Future<void> _scheduleDailyBriefings(
    ElaraResult result,
    PhaseTimeline timeline,
    core.SeverityResult? severity,
    AndroidScheduleMode mode,
  ) async {
    final today = dateOnly(_clock());

    for (var offset = 0; offset < horizonDays; offset++) {
      final day = today.add(Duration(days: offset));
      final fireAt = _atHour(day, briefingHour);
      if (!fireAt.isAfter(_clock())) continue;

      final phaseDay = timeline.dayFor(day);
      final action = _actionFor(phaseDay.phaseResult, severity);

      final phaseLabel =
          phaseDay.phaseResult == null ? 'Elara' : phaseLabelOf(phaseDay.phase);
      final cycleDay = phaseDay.phaseResult?.cycleDay;

      final body = StringBuffer();
      if (action != null) {
        // No scores in a notification: this text can land on a lock screen, and
        // a number out of ten reads as a verdict on a person.
        body.write(
          action.cards.isNotEmpty
              ? action.cards.first.title
              : 'A quiet check-in might be welcome today.',
        );
        if (action.foodSuggestions.isNotEmpty) {
          body.write(' ${action.foodSuggestions.first} could be a kind idea.');
        }
      } else {
        body.write('No guidance for today \u2014 the phase could not be '
            'classified.');
      }

      await _schedule(
        id: ElaraNotificationType.dailyBriefing.idBase + offset,
        type: ElaraNotificationType.dailyBriefing,
        title: cycleDay == null ? phaseLabel : '$phaseLabel \u00b7 day $cycleDay',
        body: body.toString(),
        when: fireAt,
        mode: mode,
        payload: 'briefing:${dateKey(day)}',
      );
    }
  }

  /// 08:00 on the first morning of the late luteal phase.
  ///
  /// One reminder, not one per day: the phase lasts several days and repeating
  /// it every morning would be noise rather than a warning.
  Future<void> _schedulePmsWarning(
    PhaseTimeline timeline,
    AndroidScheduleMode mode,
  ) async {
    final today = dateOnly(_clock());

    for (var offset = 0; offset < cycleHorizonDays; offset++) {
      final day = today.add(Duration(days: offset));
      final fireAt = _atHour(day, briefingHour);
      if (!fireAt.isAfter(_clock())) continue;
      if (timeline.dayFor(day).phase != core.CyclePhase.lutealLate) continue;

      await _schedule(
        id: ElaraNotificationType.pmsWarning.idBase,
        type: ElaraNotificationType.pmsWarning,
        title: 'The late luteal phase is starting',
        body: 'The days before a period can be harder. Offer support without '
            'assuming what is needed.',
        when: fireAt,
        mode: mode,
        payload: 'pms:${dateKey(day)}',
      );
      return;
    }
  }

  /// 08:00 on the first day of the ovulatory phase.
  Future<void> _scheduleOvulationWindow(
    PhaseTimeline timeline,
    AndroidScheduleMode mode,
  ) async {
    final today = dateOnly(_clock());

    for (var offset = 0; offset < cycleHorizonDays; offset++) {
      final day = today.add(Duration(days: offset));
      final fireAt = _atHour(day, briefingHour);
      if (!fireAt.isAfter(_clock())) continue;
      if (timeline.dayFor(day).phase != core.CyclePhase.ovulatory) continue;

      await _schedule(
        id: ElaraNotificationType.ovulationWindow.idBase,
        type: ElaraNotificationType.ovulationWindow,
        title: 'Ovulatory phase begins',
        body: 'The estimated fertile window opens today. This is a calendar '
            'estimate, not confirmation of ovulation.',
        when: fireAt,
        mode: mode,
        payload: 'ovulation:${dateKey(day)}',
      );
      return;
    }
  }

  /// 08:00 on the predicted first day of the next period.
  Future<void> _schedulePeriodStart(
    ElaraResult result,
    AndroidScheduleMode mode,
  ) async {
    final predicted = dateOnly(result.nextPeriodDate);
    final fireAt = _atHour(predicted, briefingHour);
    if (!fireAt.isAfter(_clock())) return;

    final window = result.windowDays;
    await _schedule(
      id: ElaraNotificationType.periodStart.idBase,
      type: ElaraNotificationType.periodStart,
      title: 'Period expected today',
      body: window > 0
          ? 'Elara estimated this date with a \u00b1$window day window.'
          : 'Estimated from the recorded cycles.',
      when: fireAt,
      mode: mode,
      payload: 'period:${dateKey(predicted)}',
    );
  }

  /// 14:00 today and tomorrow when the heat index exceeds 40.
  ///
  /// Uses figures already on hand: a live reading where one was fetched,
  /// otherwise the seasonal estimate. A background isolate cannot be relied on
  /// to fetch, so the notification says which it is instead of implying a reading.
  Future<void> _scheduleClimateSpike(
    ElaraResult result,
    AndroidScheduleMode mode,
  ) async {
    final today = dateOnly(_clock());

    for (var offset = 0; offset < 2; offset++) {
      final day = today.add(Duration(days: offset));
      final fireAt = _atHour(day, climateHour);
      if (!fireAt.isAfter(_clock())) continue;

      final prediction = offset == 0 ? result : await _predictionForDate(day);
      if (prediction == null) continue;

      final heatIndex = prediction.environment.heatIndex;
      if (heatIndex <= climateSpikeThreshold) continue;

      final qualifier =
          prediction.environment.isFallback ? ' (seasonal estimate)' : '';
      await _schedule(
        id: ElaraNotificationType.climateSpike.idBase + offset,
        type: ElaraNotificationType.climateSpike,
        title: 'Heat index above ${climateSpikeThreshold.toInt()}\u00b0C'
            '$qualifier',
        body: 'Feels like ${heatIndex.toStringAsFixed(0)}\u00b0C today. '
            'Water and a cooler room may help.',
        when: fireAt,
        mode: mode,
        payload: 'climate:${dateKey(day)}',
      );
    }
  }

  Future<void> _schedule({
    required int id,
    required ElaraNotificationType type,
    required String title,
    required String body,
    required tz.TZDateTime when,
    required AndroidScheduleMode mode,
    String? payload,
  }) async {
    // The one place every reminder passes through, which is why redaction lives
    // here rather than at each of the five call sites.
    final shown = NotificationPrivacy(previewDetails: _previewDetails)
        .apply(title: title, body: body);

    try {
      await _plugin.zonedSchedule(
        id: id,
        title: shown.title,
        body: shown.body,
        scheduledDate: when,
        notificationDetails: NotificationDetails(
          android: androidDetailsFor(
            channelId: type.channelId,
            channelName: type.channelName,
          ),
        ),
        androidScheduleMode: mode,
        payload: payload,
      );
    } catch (error) {
      // One failed alarm must not abandon the rest of the schedule.
      debugPrint('Elara: could not schedule $id (${type.name}): $error');
    }
  }

  // ----------------------------------------------------------- showing now --

  /// Posts one notification immediately, rather than scheduling it.
  ///
  /// This exists for the verification, not for the app. The small icon is
  /// drawn by the system, from the alpha channel of a drawable, in the
  /// status bar - so nothing inside the app shows it, and the only way to
  /// know it draws is to post a notification and look at the status bar.
  ///
  /// It has to be posted by the app. The system's own `cmd notification post`
  /// command resolves a drawable from *its* package, not another app's, so
  /// it cannot post a notification carrying Elara's icon - and a
  /// notification carrying the system's default icon would look plausible
  /// and prove nothing.
  ///
  /// The notification is real: the app's own channel, the app's own icon,
  /// the app's own redaction. What it does not do is tell the app to send
  /// anything about a person's cycle.
  Future<void> showNow({
    String title = 'Elara',
    String body = 'Notification icon check',
  }) async {
    await init();
    await _plugin.show(
      // An id that cannot collide with a scheduled reminder. The scheduled
      // ids are the base of each type plus a day offset.
      id: 999999,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          // An existing channel, not a new one. Android fixes a channel's
          // settings when it is created, and posting to a channel that was
          // never created fails quietly - the notification simply does not
          // appear, which is exactly what the first attempt looked like.
          ElaraNotificationType.dailyBriefing.channelId,
          ElaraNotificationType.dailyBriefing.channelName,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          icon: notificationIconName,
          visibility: NotificationVisibility.public,
        ),
      ),
    );
  }

  // ------------------------------------------------------------- cancelling --

  /// Cancels every reminder of one type, leaving the others untouched.
  Future<void> cancelType(ElaraNotificationType type) async {
    try {
      await init();
      final pending = await _plugin.pendingNotificationRequests();
      for (final request in pending) {
        if (type.ids.contains(request.id)) {
          await _plugin.cancel(id: request.id);
        }
      }
    } catch (error) {
      debugPrint('Elara: could not cancel ${type.name}: $error');
    }
  }

  /// Cancels every Elara reminder. Scoped to this app's id blocks rather than
  /// `cancelAll`, so ids added by a future feature are not swept away.
  Future<void> cancelAll() async {
    try {
      await init();
      final pending = await _plugin.pendingNotificationRequests();
      for (final request in pending) {
        if (_isElaraId(request.id)) {
          await _plugin.cancel(id: request.id);
        }
      }
    } catch (error) {
      debugPrint('Elara: could not cancel reminders: $error');
    }
  }

  static bool _isElaraId(int id) =>
      ElaraNotificationType.values.any((type) => type.ids.contains(id));

  // ------------------------------------------------------------- background --

  /// Registers a daily AlarmManager wake-up that rebuilds the schedule.
  ///
  /// This is what keeps reminders current when the app is not opened; without
  /// it the seven scheduled briefings would simply run out. Idempotent: the
  /// existing alarm is cancelled before the new one is registered.
  Future<void> _ensureBackgroundReschedule(AndroidScheduleMode mode) async {
    try {
      await AndroidAlarmManager.initialize();
      await AndroidAlarmManager.cancel(_backgroundAlarmId);
      await AndroidAlarmManager.periodic(
        const Duration(days: 1),
        _backgroundAlarmId,
        backgroundRescheduleCallback,
        // 03:00 so the refreshed schedule is in place before the 08:00 briefing.
        startAt: _atHour(
          dateOnly(_clock()).add(const Duration(days: 1)),
          3,
        ).toLocal(),
        exact: mode == AndroidScheduleMode.exactAllowWhileIdle,
        wakeup: true,
        rescheduleOnReboot: true,
      );
    } catch (error) {
      debugPrint('Elara: background reschedule unavailable: $error');
    }
  }

  /// Entry point run by AlarmManager in a background isolate.
  ///
  /// That isolate has its own plugin registration, so the binding and the plugin
  /// registrant must both be initialised before sqflite or the notification
  /// plugin can be used.
  @pragma('vm:entry-point')
  static Future<void> backgroundRescheduleCallback() async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    await NotificationService().rescheduleAll();
  }

  /// Cancels the background wake-up, used when notifications are switched off.
  Future<void> cancelBackgroundReschedule() async {
    try {
      await AndroidAlarmManager.cancel(_backgroundAlarmId);
    } catch (error) {
      debugPrint('Elara: could not cancel the background alarm: $error');
    }
  }

  // ----------------------------------------------------------------- helpers --

  Future<ElaraResult?> _predictionForDate(DateTime date) async {
    try {
      return await _predictionService.predict(date: date);
    } catch (_) {
      return null;
    }
  }

  static core.ActionResult? _actionFor(
    core.PhaseResult? phase,
    core.SeverityResult? severity,
  ) {
    if (phase == null || severity == null) return null;
    if (phase.phase == core.CyclePhase.unknown) return null;
    try {
      return core.ActionEngine().recommend(phase: phase, severity: severity);
    } catch (_) {
      return null;
    }
  }

  /// The given local calendar day at [hour]:00, in the resolved zone.
  static tz.TZDateTime _atHour(DateTime day, int hour) => tz.TZDateTime(
        tz.local,
        day.year,
        day.month,
        day.day,
        hour,
      );

  /// Releases the HTTP client held by the prediction service.
  void dispose() => _predictionService.dispose();
}
