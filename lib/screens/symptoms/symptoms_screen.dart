import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/date_keys.dart';
import '../../data/models/symptom.dart';
import '../../providers/symptoms_provider.dart';
import '../../theme/elara_theme.dart';
import '../../widgets/icons.dart';
import '../../widgets/primitives.dart';
import 'symptom_editor.dart';
import '../../widgets/elara_route.dart';

/// The symptom log.
///
/// Deliberately sparse. There is no streak, no daily prompt, no percentage of
/// days logged, and no "you haven't logged anything in three days" — all of
/// those would turn an optional note into an obligation. A day with nothing
/// recorded simply does not appear.
///
/// The list is grouped by day, newest first, because the useful question is "how
/// has this week been", not "what is the all-time count".
class SymptomsScreen extends StatelessWidget {
  const SymptomsScreen({super.key});

  /// The route this screen is pushed with.
  ///
  /// It takes a [BuildContext] because the transition depends on the
  /// platform's animation setting, which is read at push time: when the
  /// setting asks for animations to be removed, the screen arrives with no
  /// transition at all.
  static Route<void> route(BuildContext context) =>
      elaraRoute<void>(context, const SymptomsScreen(), name: 'symptoms');

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    final type = context.type;
    final symptoms = context.watch<SymptomsProvider>();

    final byDay = <DateTime, List<Symptom>>{};
    for (final symptom in symptoms.recent) {
      final day = dateOnly(symptom.date);
      byDay.putIfAbsent(day, () => []).add(symptom);
    }
    final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));

    return Scaffold(
      backgroundColor: tokens.bgPrimary,
      appBar: AppBar(
        title: const Text('Symptoms'),
        backgroundColor: tokens.bgPrimary,
      ),
      body: ListView(
        // An AppBar already sits below the status bar.
        padding: ElaraSpacing.pageInsets(context, underStatusBar: false),
        children: [
          Text(
            'Anything she has mentioned, written down so it is not forgotten. '
            'Recording is optional and a blank day is normal.',
            style: type.body(tokens.textSecondaryStrong),
          ),
          const SizedBox(height: ElaraSpacing.sm),
          Text(
            'Elara does not diagnose anything from these notes, and does not '
            'infer a symptom from the estimated phase.',
            style: type.caption(tokens.textSecondaryStrong),
          ),
          const SizedBox(height: ElaraSpacing.lg),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: () => SymptomEditor.show(context),
              icon: const Icon(ElaraIcons.plus, size: ElaraIcons.size),
              label: const Text('Record a symptom'),
            ),
          ),
          const SizedBox(height: ElaraSpacing.xl),

          if (days.isEmpty)
            Text(
              'Nothing recorded. That is a perfectly ordinary state for this '
              'screen to be in.',
              style: type.body(tokens.textSecondaryStrong),
            )
          else
            for (final day in days) ...[
              ElaraOverline(_dayLabel(day)),
              const SizedBox(height: ElaraSpacing.xs),
              for (final symptom in byDay[day]!)
                ElaraListRow(
                  title: symptom.kind.label,
                  subtitle: [
                    symptom.severityLabel,
                    if (symptom.note != null) symptom.note!,
                  ].join(' \u00b7 '),
                  icon: iconForSymptom(symptom.kind),
                  onTap: () => SymptomEditor.show(context, existing: symptom),
                ),
              const Hairline(margin: ElaraSpacing.md),
            ],

          const SizedBox(height: ElaraSpacing.md),
          Text(
            'Severe or unusual pain, heavy bleeding, or a symptom that keeps '
            'returning is worth a clinician\u2019s opinion rather than a note '
            'in an app.',
            style: type.caption(tokens.textSecondaryStrong),
          ),
        ],
      ),
    );
  }

  static const List<String> _months = [
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

  static String _dayLabel(DateTime day) {
    final today = dateOnly(DateTime.now());
    if (day == today) return 'Today';
    if (day == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return '${day.day} ${_months[day.month - 1]}';
  }
}
