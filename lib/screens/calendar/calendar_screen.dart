import 'package:elara_core/elara_core.dart' as core;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/date_keys.dart';
import '../../providers/cycle_provider.dart';
import '../../providers/prediction_provider.dart';
import '../../providers/reminders_provider.dart';
import '../../providers/symptoms_provider.dart';
import '../../theme/elara_theme.dart';
import '../../utils/phase_timeline.dart';
import '../../widgets/phase_chip.dart';
import '../../widgets/primitives.dart';
import 'day_detail_sheet.dart';
import '../../widgets/icons.dart';

/// Month calendar coloured by predicted phase.
///
/// The grid is built from [PhaseTimeline], which projects the current cycle
/// forward using elara-core's classifier, so future months get real phases
/// instead of one cycle's worth followed by blanks.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _visibleMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _visibleMonth = DateTime(now.year, now.month);
  }

  void _shiftMonth(int delta) {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + delta);
    });
  }

  /// Records a period start, on the day it happened rather than the day you
  /// remembered.
  ///
  /// This used to write today's date and nothing else, so a start that began
  /// three days ago could not be entered at all. The alternative was to log it
  /// today and be wrong by three days, and every estimate afterwards would
  /// carry that error. A picker with today already selected costs one tap in
  /// the common case and fixes the case that matters.
  Future<void> _logPeriodStart() async {
    final cycles = context.read<CycleProvider>();
    final today = dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: today,
      firstDate: DateTime(today.year - 2, today.month, today.day),
      lastDate: today,
      helpText: 'Which day did it start?',
    );
    if (picked == null || !mounted) return;

    final start = dateOnly(picked);
    final stored = await cycles.addCycle(startDate: start);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          stored == null
              ? (cycles.lastError ?? 'Could not log the period start.')
              : 'Logged ${_formatShortDate(start)} as a period start.',
        ),
      ),
    );

    if (stored != null) {
      final prediction = context.read<PredictionProvider>();
      // The provider graph also reacts to the revision bump; forcing here keeps
      // the calendar in step even if that path is still mid-frame.
      await prediction.refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    final type = context.type;

    final cycles = context.watch<CycleProvider>();
    final result = context.watch<PredictionProvider>().result;
    final latest = cycles.latest;

    // Without a forecast there is no cycle length to project, so the grid falls
    // back to plain dates with recorded starts marked.
    PhaseTimeline? timeline;
    if (latest != null && result != null) {
      timeline = PhaseTimeline(
        lastPeriodStart: latest.startDate,
        cycleLength: result.cycleLength,
        periodDuration: latest.duration,
        today: DateTime.now(),
      );
    }

    final cells =
        timeline?.monthGrid(_visibleMonth) ?? _unphasedGrid(_visibleMonth);

    return Column(
      children: [
        Padding(
          padding: ElaraSpacing.pageInsets(
            context,
          ).copyWith(bottom: ElaraSpacing.sm),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Calendar',
                      style: type.headline(tokens.textPrimary, size: 28),
                    ),
                    const SizedBox(height: ElaraSpacing.xxs),
                    Text(
                      timeline == null
                          ? 'Log a period start to see phases'
                          : 'Coloured by predicted phase',
                      style: type.caption(tokens.textSecondaryStrong),
                    ),
                  ],
                ),
              ),
              // Period start action, top right.
              //
              // A labelled button and the heading cannot share one row on a
              // 320 dp screen. The Row gave the heading an Expanded share and
              // the button what was left, which came to about 144 dp, so the
              // label rendered as "+ Period s…" in the 320x640 device capture -
              // ellipsised text in a primary action reads as a bug, not as a
              // narrow layout. Below this width the button keeps its icon and
              // drops its label; the icon carries an accessible name, so the
              // words are still there for anyone not reading the screen.
              if (MediaQuery.sizeOf(context).width < 380)
                Tooltip(
                  message: 'Period start',
                  child: FilledButton(
                    onPressed: _logPeriodStart,
                    style: FilledButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(44, 44),
                    ),
                    child: const Icon(
                      ElaraIcons.plus,
                      size: 20,
                      semanticLabel: 'Period start',
                    ),
                  ),
                )
              else
                Flexible(
                  child: FilledButton.icon(
                    onPressed: _logPeriodStart,
                    icon: const Icon(ElaraIcons.plus, size: 18),
                    label: const Text(
                      'Period start',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
            ],
          ),
        ),

        // Month navigation.
        Padding(
          padding: ElaraSpacing.pageInsets(context).copyWith(top: 0, bottom: 0),
          child: Row(
            children: [
              IconButton(
                onPressed: () => _shiftMonth(-1),
                icon: const Icon(ElaraIcons.previous),
                color: tokens.textSecondaryStrong,
                tooltip: 'Previous month',
              ),
              Expanded(
                child: Center(
                  child: Text(
                    _formatMonthYear(_visibleMonth),
                    style: type.title(tokens.textPrimary, size: 16),
                  ),
                ),
              ),
              IconButton(
                onPressed: () => _shiftMonth(1),
                icon: const Icon(ElaraIcons.next),
                color: tokens.textSecondaryStrong,
                tooltip: 'Next month',
              ),
            ],
          ),
        ),

        Expanded(
          child: ListView(
            padding: ElaraSpacing.pageInsets(context).copyWith(top: 0),
            children: [
              const _WeekdayHeader(),
              const SizedBox(height: ElaraSpacing.sm),
              _MonthGrid(
                cells: cells,
                hasTimeline: timeline != null,
                symptomDays: context.watch<SymptomsProvider>().markerDays(),
                reminderDays: context.watch<RemindersProvider>().markerDays(),
                onTapDay: (day) => DayDetailSheet.show(
                  context,
                  day: day,
                  severity: result?.severity,
                ),
              ),
              const SizedBox(height: ElaraSpacing.xl),
              const _Legend(),
            ],
          ),
        ),
      ],
    );
  }

  /// Fallback grid when no forecast exists: dates only.
  List<PhaseDay?> _unphasedGrid(DateTime month) {
    final firstOfMonth = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leading = (firstOfMonth.weekday - DateTime.monday + 7) % 7;
    final cells = <PhaseDay?>[];
    for (var i = 0; i < leading; i++) {
      cells.add(null);
    }
    for (var d = 1; d <= daysInMonth; d++) {
      final date = DateTime(month.year, month.month, d);
      cells.add(
        PhaseDay(
          date: date,
          phase: core.CyclePhase.unknown,
          cycleDay: 0,
          cycleIndex: 0,
          isRecorded: true,
        ),
      );
    }
    while (cells.length % 7 != 0) {
      cells.add(null);
    }
    return cells;
  }
}

class _WeekdayHeader extends StatelessWidget {
  const _WeekdayHeader();

  static const List<String> _labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    return Row(
      children: [
        for (final label in _labels)
          Expanded(
            child: Center(
              child: Text(
                label,
                style: context.type
                    .overline(tokens.textSecondaryStrong)
                    .copyWith(fontSize: 11),
              ),
            ),
          ),
      ],
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.cells,
    required this.hasTimeline,
    required this.onTapDay,
    this.symptomDays = const {},
    this.reminderDays = const {},
  });

  final List<PhaseDay?> cells;
  final bool hasTimeline;
  final void Function(PhaseDay day) onTapDay;

  /// Days carrying at least one reported symptom, and days carrying at least one
  /// care reminder. Both are drawn as small marks under the date, so a day can
  /// show a logged symptom without pretending to be a phase.
  final Set<DateTime> symptomDays;
  final Set<DateTime> reminderDays;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < cells.length; i += 7) {
      final week = cells.sublist(i, (i + 7).clamp(0, cells.length));
      rows.add(
        Row(
          children: [
            for (final cell in week)
              Expanded(
                child: cell == null
                    ? SizedBox(height: _cellHeight(context))
                    : _DayCell(
                        day: cell,
                        hasTimeline: hasTimeline,
                        hasSymptom: symptomDays.contains(dateOnly(cell.date)),
                        hasReminder: reminderDays.contains(dateOnly(cell.date)),
                        onTap: () => onTapDay(cell),
                      ),
              ),
          ],
        ),
      );
    }
    return Column(children: rows);
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.hasTimeline,
    required this.onTap,
    this.hasSymptom = false,
    this.hasReminder = false,
  });

  final PhaseDay day;
  final bool hasTimeline;
  final VoidCallback onTap;
  final bool hasSymptom;
  final bool hasReminder;

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    final type = context.type;
    final isToday = dateOnly(day.date) == dateOnly(DateTime.now());
    final phaseKey = day.key;
    final hasPhase = hasTimeline && phaseKey != 'unknown';

    // A screen reader should hear more than a number. The label spells out the
    // date, whether the day is a recorded or a projected phase, and whether it
    // is today, because colour is doing all of that work visually and is not
    // available to everyone.
    final semanticsLabel = [
      _formatShortDate(day.date),
      hasPhase ? day.label : 'no phase',
      day.isRecorded ? 'recorded' : 'projected',
      if (isToday) 'today',
      if (!day.isRecorded) 'not a confirmed phase',
      if (hasSymptom) 'symptom recorded',
      if (hasReminder) 'reminder set',
    ].join(', ');

    return Semantics(
      label: semanticsLabel,
      button: true,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ElaraRadii.chip),
        child: SizedBox(
          height: _cellHeight(context),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: _dotSize(context),
                height: _dotSize(context),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  // Predicted phases are a light wash; unclassified days stay
                  // bare so a guess never looks as solid as a known phase.
                  color: hasPhase
                      ? tokens.phaseWash(phaseKey, opacity: 0.30)
                      : tokens.transparent,
                  borderRadius: BorderRadius.circular(ElaraRadii.chip),
                ),
                child: Text(
                  '${day.date.day}',
                  style: type.number(
                    hasPhase ? tokens.phaseText(phaseKey) : tokens.textPrimary,
                    size: 14,
                    weight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              // A row of small marks under the date: today, a recorded symptom,
              // a care reminder. Three 4px dots rather than badges, so the date
              // stays the thing you read first.
              SizedBox(
                height: 4,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isToday) _Mark(color: tokens.accent),
                    if (hasSymptom) ...[
                      if (isToday) const SizedBox(width: 2),
                      _Mark(color: tokens.phaseText('menstrual')),
                    ],
                    if (hasReminder) ...[
                      if (isToday || hasSymptom) const SizedBox(width: 2),
                      _Mark(color: tokens.textSecondaryStrong),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One 4px dot in the mark row under a date.
class _Mark extends StatelessWidget {
  const _Mark({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 4,
      height: 4,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  static const List<(String, String)> _entries = [
    ('menstrual', 'Menstrual'),
    ('follicular', 'Follicular'),
    ('ovulatory', 'Ovulatory'),
    ('luteal', 'Luteal'),
  ];

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    return ElaraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ElaraOverline('Phases'),
          const SizedBox(height: ElaraSpacing.sm),
          Wrap(
            spacing: ElaraSpacing.lg,
            runSpacing: ElaraSpacing.sm,
            children: [
              for (final (key, label) in _entries)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PhaseSwatch(phaseKey: key),
                    const SizedBox(width: ElaraSpacing.xs),
                    Text(
                      label,
                      style: context.type.label(tokens.textSecondaryStrong),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: ElaraSpacing.sm),
          Text(
            'Future days are projections from the last recorded start; '
            'they are not confirmed phases.',
            style: context.type.caption(tokens.textSecondaryStrong),
          ),
        ],
      ),
    );
  }
}

const List<String> _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

String _formatMonthYear(DateTime month) =>
    '${_monthNames[month.month - 1]} ${month.year}';

String _formatShortDate(DateTime date) =>
    '${date.day} ${_monthNames[date.month - 1].substring(0, 3)} ${date.year}';

/// Height of one calendar cell.
///
/// Scales with the user's text size so large-text settings do not clip the day
/// number, and never drops below the 48dp minimum touch target.
double _cellHeight(BuildContext context) {
  final scaled = MediaQuery.textScalerOf(context).scale(46);
  return scaled < 48 ? 48 : scaled;
}

/// Size of the day-number pill inside a cell, scaled the same way.
double _dotSize(BuildContext context) {
  final scaled = MediaQuery.textScalerOf(context).scale(30);
  return scaled < 30 ? 30 : scaled;
}
