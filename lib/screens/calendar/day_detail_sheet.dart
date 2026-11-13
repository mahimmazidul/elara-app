import 'package:elara_core/elara_core.dart' as core;
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../data/date_keys.dart';
import '../../providers/cycle_provider.dart';
import '../../providers/reminders_provider.dart';
import '../../providers/symptoms_provider.dart';
import '../reminders/care_reminder_editor.dart';
import '../symptoms/symptom_editor.dart';
import '../../theme/elara_theme.dart';
import '../../widgets/icons.dart';
import '../../utils/phase_timeline.dart';
import '../../widgets/phase_chip.dart';
import '../../widgets/primitives.dart';
import '../../widgets/food_chip_row.dart';

/// Bottom sheet for a tapped calendar day: phase, guidance, food, and—when the
/// day is a recorded start—the correction controls.
///
/// Correcting a date used to be impossible: the only write path was "log
/// today", so a start entered a day out could only be deleted, and the deletion
/// made the calendar look like the period had never been recorded. The sheet
/// now offers move and remove for the exact row the day represents.
///
/// The scores are recomputed for that specific day by running elara-core's
/// [core.ActionEngine] against the day's phase and today's environmental
/// severity. Severity is not available per future day (no forecast is cached
/// that far ahead), so today's conditions are used and the sheet says so.
class DayDetailSheet extends StatelessWidget {
  const DayDetailSheet({super.key, required this.day, required this.severity});

  final PhaseDay day;
  final core.SeverityResult? severity;

  /// Shows the sheet for [day].
  static Future<void> show(
    BuildContext context, {
    required PhaseDay day,
    core.SeverityResult? severity,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => DayDetailSheet(day: day, severity: severity),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    final type = context.type;

    // A day before the first recorded start has no phase to act on.
    final result = _actionFor(context);
    final phaseKey = day.key;

    return SafeArea(
      // Scrollable and height-capped. On a 320px-wide phone at a large text
      // scale the sheet is taller than the screen, and without this the action
      // guidance at the bottom was simply cut off with an overflow warning.
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            ElaraSpacing.lg,
            0,
            ElaraSpacing.lg,
            ElaraSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _formatDate(day.date),
                          style: type.title(tokens.textPrimary, size: 20),
                        ),
                        const SizedBox(height: ElaraSpacing.xxs),
                        Text(
                          day.isRecorded ? 'Recorded cycle' : 'Projected',
                          style: type.caption(tokens.textSecondaryStrong),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: ElaraSpacing.md),
              PhaseChip(label: day.label, phaseKey: phaseKey, compact: true),
              const SizedBox(height: ElaraSpacing.lg),

              // Only a recorded start can be corrected; a projected day has no
              // row behind it and pretending otherwise would be a lie.
              if (day.isRecorded) _CorrectionRow(date: day.date),

              // ---- what was reported on this day, and what is planned for it
              _SymptomSection(date: day.date),
              const SizedBox(height: ElaraSpacing.lg),
              _ReminderSection(date: day.date),
              const SizedBox(height: ElaraSpacing.lg),

              if (result == null)
                Text(
                  'This day falls before the first recorded period, so Elara '
                  'cannot say which phase it was in.',
                  style: type.body(tokens.textSecondaryStrong),
                )
              else ...[
                if (result.cards.isNotEmpty) ...[
                  const ElaraOverline('A place to start'),
                  const SizedBox(height: ElaraSpacing.sm),
                  Text(
                    result.cards.first.title,
                    style: type.subtitle(tokens.textPrimary, size: 15),
                  ),
                  const SizedBox(height: ElaraSpacing.xs),
                  Text(
                    result.cards.first.body,
                    style: type.body(tokens.textSecondaryStrong),
                  ),
                  const SizedBox(height: ElaraSpacing.lg),
                ],
                const ElaraOverline('Food'),
                const SizedBox(height: ElaraSpacing.sm),
                FoodChipRow(foods: result.foodSuggestions, phaseKey: phaseKey),
                const SizedBox(height: ElaraSpacing.md),
                Text(
                  'An invitation to ask, not a prediction about anyone\u2019s mood.',
                  style: type.caption(tokens.textSecondaryStrong),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Runs the action engine for this day, or returns null when the day has no
  /// classified phase or no severity was supplied.
  ///
  /// Uses the day's real [core.PhaseResult] from the classifier — including its
  /// genuine fertile window and ovulation day — so nothing here is
  /// reconstructed or approximated.
  core.ActionResult? _actionFor(BuildContext context) {
    final sever = severity;
    final phaseResult = day.phaseResult;
    if (sever == null || phaseResult == null) return null;
    if (phaseResult.phase == core.CyclePhase.unknown) return null;

    try {
      return core.ActionEngine().recommend(phase: phaseResult, severity: sever);
    } catch (_) {
      return null;
    }
  }

  static String _formatDate(DateTime date) {
    const months = [
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
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

/// Symptoms reported on this day, with a way to add or correct one.
class _SymptomSection extends StatelessWidget {
  const _SymptomSection({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    final type = context.type;
    final symptoms = context.watch<SymptomsProvider>();
    final onDay = symptoms.on(date);
    final isFuture = date.isAfter(DateTime.now());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ElaraOverline('Reported that day'),
        const SizedBox(height: ElaraSpacing.xs),
        if (onDay.isEmpty)
          Text(
            isFuture ? 'This day has not happened yet.' : 'Nothing recorded.',
            style: type.body(tokens.textSecondaryStrong),
          )
        else
          for (final symptom in onDay)
            ElaraListRow(
              title: symptom.kind.label,
              subtitle: [
                symptom.severityLabel,
                if (symptom.note != null) symptom.note!,
              ].join(' · '),
              icon: iconForSymptom(symptom.kind),
              onTap: () => SymptomEditor.show(context, existing: symptom),
            ),
        if (!isFuture)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => SymptomEditor.show(context, initialDate: date),
              icon: const Icon(ElaraIcons.plus, size: 16),
              label: const Text('Record a symptom'),
            ),
          ),
      ],
    );
  }
}

/// Care reminders for this day: the planning half of the sheet.
class _ReminderSection extends StatelessWidget {
  const _ReminderSection({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    final type = context.type;
    final reminders = context.watch<RemindersProvider>();
    final onDay = reminders.on(date);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ElaraOverline('Planned for that day'),
        const SizedBox(height: ElaraSpacing.xs),
        if (onDay.isEmpty)
          Text(
            'Nothing planned. Supplies, an errand, an evening she would '
            'enjoy. Anything worth remembering.',
            style: type.body(tokens.textSecondaryStrong),
          )
        else
          for (final reminder in onDay)
            ElaraListRow(
              title: reminder.title,
              subtitle: reminder.note,
              icon: reminder.done
                  ? ElaraIcons.confirmed
                  : ElaraIcons.notification,
              trailingText: reminder.done ? 'Done' : null,
              onTap: () => CareReminderEditor.show(
                context,
                initialDate: date,
                existing: reminder,
              ),
            ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () =>
                CareReminderEditor.show(context, initialDate: date),
            icon: const Icon(ElaraIcons.plus, size: 16),
            label: const Text('Plan something'),
          ),
        ),
      ],
    );
  }
}

/// Move or remove the recorded start this day represents.
class _CorrectionRow extends StatefulWidget {
  const _CorrectionRow({required this.date});

  final DateTime date;

  @override
  State<_CorrectionRow> createState() => _CorrectionRowState();
}

class _CorrectionRowState extends State<_CorrectionRow> {
  bool _busy = false;

  Future<void> _move() async {
    final cycles = context.read<CycleProvider>();
    final entry = cycles.entryOn(widget.date);
    if (entry == null) return;

    final today = dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: widget.date,
      // A period cannot start in the future, and three years back matches the
      // range onboarding offers.
      firstDate: DateTime(today.year - 3),
      lastDate: today,
      helpText: 'Move this period start',
    );
    if (picked == null || !mounted) return;

    setState(() => _busy = true);
    final ok = await cycles.moveStartDate(entry.id!, dateOnly(picked));
    if (!mounted) return;
    setState(() => _busy = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Moved to ${_formatDate(dateOnly(picked))}.'
              : (cycles.lastError ?? 'Could not move that date.'),
        ),
      ),
    );
    if (ok && Navigator.of(context).canPop()) Navigator.of(context).pop();
  }

  Future<void> _remove() async {
    final cycles = context.read<CycleProvider>();
    final entry = cycles.entryOn(widget.date);
    if (entry == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.elara.bgCard,
        surfaceTintColor: context.elara.transparent,
        title: Text(
          'Remove this start?',
          style: context.type.title(context.elara.textPrimary, size: 18),
        ),
        content: Text(
          'The period recorded on ${_formatDate(widget.date)} will be removed '
          'and the prediction recalculated from what remains.',
          style: context.type.body(context.elara.textSecondaryStrong),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep it'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Remove',
              style: context.type.subtitle(context.elara.dangerText, size: 14),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    final ok = await cycles.deleteCycle(entry.id!);
    if (!mounted) return;
    setState(() => _busy = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'Removed.' : (cycles.lastError ?? 'Could not remove it.'),
        ),
      ),
    );
    if (ok && Navigator.of(context).canPop()) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    final type = context.type;
    final entry = context.watch<CycleProvider>().entryOn(widget.date);
    if (entry == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: ElaraSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ElaraOverline('This recorded start'),
          const SizedBox(height: ElaraSpacing.xs),
          Text(
            entry.duration == null
                ? 'No length recorded.'
                : 'Bleeding recorded for ${entry.duration} days.',
            style: type.caption(tokens.textSecondaryStrong),
          ),
          const SizedBox(height: ElaraSpacing.sm),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _move,
                  icon: const Icon(ElaraIcons.editDate, size: 16),
                  label: const Text('Move date'),
                ),
              ),
              const SizedBox(width: ElaraSpacing.sm),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _remove,
                  icon: const Icon(ElaraIcons.delete, size: 16),
                  label: const Text('Remove'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _formatDate(DateTime date) {
  const months = [
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
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}
