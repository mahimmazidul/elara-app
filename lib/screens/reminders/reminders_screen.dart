import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/date_keys.dart';
import '../../data/models/care_reminder.dart';
import '../../providers/reminders_provider.dart';
import '../../theme/elara_theme.dart';
import '../../widgets/icons.dart';
import '../../widgets/primitives.dart';
import 'care_reminder_editor.dart';
import '../../widgets/elara_route.dart';

/// Everything planned, in date order.
///
/// Deliberately a list rather than a planner: no streaks, no completion rate, no
/// "you have 3 things overdue" score. A reminder that passed is shown as past,
/// and can be ticked or removed without ceremony.
class RemindersScreen extends StatelessWidget {
  const RemindersScreen({super.key});

  /// The route this screen is pushed with.
  ///
  /// It takes a [BuildContext] because the transition depends on the
  /// platform's animation setting, which is read at push time.
  static Route<void> route(BuildContext context) =>
      elaraRoute<void>(context, const RemindersScreen(), name: 'reminders');

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    final type = context.type;
    final provider = context.watch<RemindersProvider>();
    final today = dateOnly(DateTime.now());
    final all = provider.all;
    final pending = all.where((r) => !r.done).toList();
    final done = all.where((r) => r.done).toList();

    final past = pending.where((r) => r.date.isBefore(today)).toList();
    final upcoming = pending.where((r) => !r.date.isBefore(today)).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Care reminders')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => CareReminderEditor.show(context, initialDate: today),
        icon: const Icon(ElaraIcons.plus),
        label: const Text('Plan something'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: ElaraSpacing.readableWidth,
            ),
            child: ListView(
              padding: ElaraSpacing.pageInsets(
                context,
              ).copyWith(bottom: ElaraSpacing.xxl),
              children: [
                Text(
                  'Small, practical things: supplies before they run out, an '
                  'errand, an evening she would enjoy. These are notes for a '
                  'day, kept apart from anything the app estimates.',
                  style: type.caption(tokens.textSecondaryStrong),
                ),
                const SizedBox(height: ElaraSpacing.lg),

                if (all.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: ElaraSpacing.xl),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Nothing planned yet.',
                          style: type.title(tokens.textPrimary, size: 18),
                        ),
                        const SizedBox(height: ElaraSpacing.xs),
                        Text(
                          'Adding something is optional. If you would rather '
                          'not plan ahead, Elara works the same without it.',
                          style: type.body(tokens.textSecondaryStrong),
                        ),
                      ],
                    ),
                  ),

                if (past.isNotEmpty) ...[
                  const ElaraOverline('Past'),
                  const SizedBox(height: ElaraSpacing.xs),
                  for (final reminder in past)
                    _ReminderRow(
                      reminder: reminder,
                      dateLabel: _pastLabel(reminder.date, today),
                    ),
                  const SizedBox(height: ElaraSpacing.lg),
                ],

                if (upcoming.isNotEmpty) ...[
                  const ElaraOverline('Coming up'),
                  const SizedBox(height: ElaraSpacing.xs),
                  for (final reminder in upcoming)
                    _ReminderRow(
                      reminder: reminder,
                      dateLabel: _upcomingLabel(reminder.date, today),
                    ),
                  const SizedBox(height: ElaraSpacing.lg),
                ],

                if (done.isNotEmpty) ...[
                  const ElaraOverline('Done'),
                  const SizedBox(height: ElaraSpacing.xs),
                  for (final reminder in done)
                    _ReminderRow(
                      reminder: reminder,
                      dateLabel: _pastLabel(reminder.date, today),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  static const List<String> _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static String _upcomingLabel(DateTime date, DateTime today) {
    if (date == today) return 'Today';
    if (date == today.add(const Duration(days: 1))) return 'Tomorrow';
    return '${date.day} ${_months[date.month - 1]}';
  }

  static String _pastLabel(DateTime date, DateTime today) {
    if (date == today) return 'Today';
    return '${date.day} ${_months[date.month - 1]}';
  }
}

class _ReminderRow extends StatelessWidget {
  const _ReminderRow({required this.reminder, required this.dateLabel});

  final CareReminder reminder;
  final String dateLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    final provider = context.read<RemindersProvider>();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        IconButton(
          tooltip: reminder.done ? 'Mark as not done' : 'Mark as done',
          onPressed: () => provider.setDone(reminder, !reminder.done),
          icon: Icon(
            reminder.done ? ElaraIcons.confirmed : ElaraIcons.pending,
            size: 20,
            color: reminder.done ? tokens.accent : tokens.textSecondaryStrong,
          ),
        ),
        Expanded(
          child: ElaraListRow(
            title: reminder.title,
            subtitle: reminder.note == null
                ? dateLabel
                : '$dateLabel · ${reminder.note}',
            onTap: () => CareReminderEditor.show(
              context,
              initialDate: reminder.date,
              existing: reminder,
            ),
          ),
        ),
      ],
    );
  }
}
