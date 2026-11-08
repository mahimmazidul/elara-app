import 'package:elara_core/elara_core.dart' as core;

import '../data/date_keys.dart';

/// Maps elara-core's six phases onto the four colours the design system has.
///
/// The luteal early/late split is a behavioural distinction (see the action
/// engine's rules); visually both are "luteal", so they share a colour while the
/// label keeps the distinction.
String phaseKeyOf(core.CyclePhase phase) {
  switch (phase) {
    case core.CyclePhase.menstrual:
      return 'menstrual';
    case core.CyclePhase.follicular:
      return 'follicular';
    case core.CyclePhase.ovulatory:
      return 'ovulatory';
    case core.CyclePhase.lutealEarly:
    case core.CyclePhase.lutealLate:
      return 'luteal';
    case core.CyclePhase.unknown:
      return 'unknown';
  }
}

/// Human label for a phase.
String phaseLabelOf(core.CyclePhase phase) {
  switch (phase) {
    case core.CyclePhase.menstrual:
      return 'Menstrual';
    case core.CyclePhase.follicular:
      return 'Follicular';
    case core.CyclePhase.ovulatory:
      return 'Ovulatory';
    case core.CyclePhase.lutealEarly:
      return 'Luteal (early)';
    case core.CyclePhase.lutealLate:
      return 'Luteal (late)';
    case core.CyclePhase.unknown:
      return 'Not classified';
  }
}

/// One day's phase within a projected timeline.
class PhaseDay {
  const PhaseDay({
    required this.date,
    required this.phase,
    required this.cycleDay,
    required this.cycleIndex,
    required this.isRecorded,
    this.phaseResult,
  });

  final DateTime date;
  final core.CyclePhase phase;
  final int cycleDay;

  /// 0 = the cycle that is currently running, 1 = the next projected one, and
  /// negative for cycles before the most recent recorded start.
  final int cycleIndex;

  /// True when this day falls in a cycle the user actually recorded, false when
  /// it is a projection forward. The calendar uses this to render predicted
  /// days differently from known ones.
  final bool isRecorded;

  /// The classifier's full result for this day (fertile window, ovulation day,
  /// signed day counts). Null when the day could not be classified. Callers that
  /// need more than the phase enum — the day-detail sheet does — must read this
  /// rather than reconstructing a PhaseResult by hand.
  final core.PhaseResult? phaseResult;

  String get key => phaseKeyOf(phase);
  String get label => phaseLabelOf(phase);
}

/// Projects the cycle across a date range.
///
/// elara-core's [core.PhaseClassifier] classifies a date inside one cycle and
/// deliberately refuses to wrap around when a period is overdue. A calendar
/// needs the opposite: the projected phases for future months. This helper
/// supplies that by shifting the last recorded start forward by whole cycle
/// lengths and asking the same classifier about each projected cycle — so the
/// phase maths still comes from elara-core in one place, and the projection
/// logic (which cycle is a given date in) lives here.
class PhaseTimeline {
  PhaseTimeline({
    required DateTime lastPeriodStart,
    required this.cycleLength,
    this.periodDuration,
    this.today,
  }) : lastPeriodStart = dateOnly(lastPeriodStart);

  final DateTime lastPeriodStart;
  final int cycleLength;
  final int? periodDuration;

  /// "Now", used to decide [PhaseDay.isRecorded] and the current cycle index.
  final DateTime? today;

  /// elara-core refuses to classify a cycle shorter than 15 days.
  static const int minimumClassifiableCycleLength = 15;

  bool get canClassify => cycleLength >= minimumClassifiableCycleLength;

  /// The phase on [date], or unknown when it cannot be classified.
  PhaseDay dayFor(DateTime date) {
    final day = dateOnly(date);
    final offset = daysBetween(lastPeriodStart, day);

    if (!canClassify || offset < 0) {
      return PhaseDay(
        date: day,
        phase: core.CyclePhase.unknown,
        cycleDay: offset < 0 ? 0 : offset + 1,
        cycleIndex: offset < 0 ? -1 : 0,
        isRecorded: offset < 0,
        phaseResult: null,
      );
    }

    final cycleIndex = offset ~/ cycleLength;
    final cycleStart =
        dateOnly(lastPeriodStart.add(Duration(days: cycleIndex * cycleLength)));

    // Ask elara-core about this projected cycle.
    core.PhaseResult? result;
    try {
      result = core.PhaseClassifier().classify(
        lastPeriod: core.CycleRecord(
          startDate: cycleStart,
          periodDuration: _safeDuration,
        ),
        cycleLength: cycleLength,
        date: day,
      );
    } on ArgumentError {
      result = null;
    }

    final referenceToday = today == null ? null : dateOnly(today!);
    final isRecorded = referenceToday == null
        ? cycleIndex <= 0
        : !day.isAfter(referenceToday) && cycleIndex <= 0;

    return PhaseDay(
      date: day,
      phase: result?.phase ?? core.CyclePhase.unknown,
      cycleDay: result?.cycleDay ?? (offset - cycleIndex * cycleLength) + 1,
      cycleIndex: cycleIndex,
      isRecorded: isRecorded,
      phaseResult: result,
    );
  }

  int? get _safeDuration {
    final duration = periodDuration;
    if (duration == null || duration < 1) return null;
    // core rejects a period longer than the cycle.
    return duration > cycleLength ? null : duration;
  }

  /// Every day in [from]..[to], inclusive.
  ///
  /// Named `daysInRange` rather than `daysBetween` on purpose: this class is a
  /// public API and a method called `daysBetween` would shadow the top-level
  /// day-counting helper of the same name inside its own body.
  List<PhaseDay> daysInRange(DateTime from, DateTime to) {
    final start = dateOnly(from);
    final end = dateOnly(to);
    if (end.isBefore(start)) return const [];
    final total = daysBetween(start, end) + 1;
    return List<PhaseDay>.generate(total, (i) {
      return dayFor(start.add(Duration(days: i)));
    });
  }

  /// The month grid for [month], padded to whole weeks starting Monday.
  ///
  /// Returns nulls for the leading/trailing cells outside the month so the grid
  /// keeps its shape without painting neighbouring months' days.
  List<PhaseDay?> monthGrid(DateTime month, {int firstWeekday = DateTime.monday}) {
    final firstOfMonth = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;

    // DateTime.weekday: Monday = 1 ... Sunday = 7.
    final leading = (firstOfMonth.weekday - firstWeekday + 7) % 7;

    final cells = <PhaseDay?>[];
    for (var i = 0; i < leading; i++) {
      cells.add(null);
    }
    for (var day = 1; day <= daysInMonth; day++) {
      cells.add(dayFor(DateTime(month.year, month.month, day)));
    }
    // Pad the final week so the grid is rectangular.
    while (cells.length % 7 != 0) {
      cells.add(null);
    }
    return cells;
  }
}
