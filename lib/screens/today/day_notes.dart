import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/date_keys.dart';
import '../../data/models/symptom.dart';
import '../../providers/reminders_provider.dart';
import '../../providers/symptoms_provider.dart';
import '../../theme/elara_theme.dart';
import '../../widgets/icons.dart';
import '../reminders/care_reminder_editor.dart';
import '../symptoms/symptom_editor.dart';
import '../symptoms/symptoms_screen.dart';

/// The day's notes on Today: what she has mentioned recently, and what is
/// planned for today or tomorrow.
///
/// Kept as two quiet lines rather than cards. Both are things the user might act
/// on, so they belong on Today, but neither should compete with the guidance
/// section above them — a reminder to buy a hot water bottle is not the point of
/// the screen, it is a detail worth not forgetting.
///
/// Rendered only when there is something to say: an empty state here would be
/// noise, and a day with nothing noted is normal.
class DayNotes extends StatelessWidget {
  const DayNotes({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    final type = context.type;
    final symptoms = context.watch<SymptomsProvider>();
    final reminders = context.watch<RemindersProvider>();
    final today = dateOnly(DateTime.now());

    // Recent symptoms: today and yesterday only. A headache from last week is
    // history, not something to act on now.
    final recent = symptoms.recent
        .where((s) => !dateOnly(s.date).isBefore(
              today.subtract(const Duration(days: 1)),
            ))
        .toList();

    final planned = reminders.upcoming(days: 1);

    if (recent.isEmpty && planned.isEmpty) {
      // Nothing to report, but a way in, so the feature is discoverable without
      // being pushed.
      return Align(
        alignment: Alignment.centerLeft,
        child: Wrap(
          spacing: ElaraSpacing.lg,
          children: [
            TextButton.icon(
              onPressed: () => SymptomEditor.show(context),
              icon: const Icon(ElaraIcons.symptom, size: 16),
              label: const Text('Record a symptom'),
            ),
            TextButton.icon(
              onPressed: () => Navigator.of(context).push(SymptomsScreen.route(context)),
              icon: const Icon(ElaraIcons.disclosure, size: 16),
              label: const Text('Symptom log'),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (recent.isNotEmpty) ...[
          Row(
            children: [
              Icon(
                ElaraIcons.symptom,
                size: ElaraIcons.size,
                color: tokens.textSecondaryStrong,
              ),
              const SizedBox(width: ElaraSpacing.sm),
              Expanded(
                child: Text(
                  'She mentioned ${_symptomLine(recent)}',
                  style: type.body(tokens.textSecondaryStrong),
                ),
              ),
            ],
          ),
          const SizedBox(height: ElaraSpacing.xs),
        ],
        if (planned.isNotEmpty) ...[
          for (final reminder in planned)
            Row(
              children: [
                Icon(
                  ElaraIcons.notification,
                  size: ElaraIcons.size,
                  color: tokens.textSecondaryStrong,
                ),
                const SizedBox(width: ElaraSpacing.sm),
                Expanded(
                  child: Text(
                    '${_when(reminder.date, today)}: ${reminder.title}',
                    style: type.body(tokens.textSecondaryStrong),
                  ),
                ),
                TextButton(
                  onPressed: () => CareReminderEditor.show(
                    context,
                    initialDate: reminder.date,
                    existing: reminder,
                  ),
                  child: const Text('Edit'),
                ),
              ],
            ),
        ],
        const SizedBox(height: ElaraSpacing.xs),
        Align(
          alignment: Alignment.centerLeft,
          child: Wrap(
            spacing: ElaraSpacing.lg,
            children: [
              TextButton.icon(
                onPressed: () => SymptomEditor.show(context),
                icon: const Icon(ElaraIcons.plus, size: 16),
                label: const Text('Record a symptom'),
              ),
              TextButton.icon(
                onPressed: () => CareReminderEditor.show(
                  context,
                  initialDate: today.add(const Duration(days: 1)),
                ),
                icon: const Icon(ElaraIcons.plus, size: 16),
                label: const Text('Plan something'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// "cramps today, and fatigue yesterday" — names, not a score.
  static String _symptomLine(List<Symptom> symptoms) {
    final today = dateOnly(DateTime.now());
    final parts = <String>[];
    for (final symptom in symptoms) {
      final day = dateOnly(symptom.date);
      final when = day == today ? 'today' : 'yesterday';
      parts.add('${symptom.kind.label.toLowerCase()} $when');
    }
    if (parts.length == 1) return parts.first;
    return '${parts.take(parts.length - 1).join(', ')} and ${parts.last}';
  }

  static String _when(DateTime date, DateTime today) {
    final day = dateOnly(date);
    if (day == today) return 'Today';
    if (day == today.add(const Duration(days: 1))) return 'Tomorrow';
    if (day.isBefore(today)) return 'Overdue';
    return 'Coming up';
  }
}
