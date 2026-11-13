import 'package:material_ui/material_ui.dart';

import '../../data/date_keys.dart';
import '../../theme/elara_theme.dart';
import '../../widgets/icons.dart';
import '../../widgets/primitives.dart';
import '../../widgets/sub_page.dart';
import '../../providers/reminders_provider.dart';
import '../../providers/symptoms_provider.dart';
import '../reminders/reminders_screen.dart';
import '../symptoms/symptoms_screen.dart';
import 'package:provider/provider.dart';
import 'day_notes.dart';

/// Notes and plans: what she has recorded recently and what is coming up.
///
/// These were two quiet lines at the bottom of Today, which was the right
/// weight for them and the wrong place: below the guidance, below the weather,
/// below the calendars, on a screen that had already asked the reader to scroll
/// twice. They are things someone came to Today to *do*, so they belong one tap
/// from the top rather than at the end of a scroll.
class NotesPage extends StatelessWidget {
  const NotesPage({super.key});

  static Route<void> route(BuildContext context) {
    return MaterialPageRoute<void>(builder: (_) => const NotesPage());
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    final type = context.type;

    return ElaraSubPage(
      title: 'Notes and plans',
      subtitle:
          'Symptoms she has recorded and reminders you have written. Both stay '
          'on this phone.',
      children: [
        DayNotes(),
        const SizedBox(height: ElaraSpacing.lg),

        // The two full screens, reached from here so a reader who came looking
        // for the record does not have to go back to the hub to find the log.
        ElaraGlassGroup(
          children: [
            ElaraListRow(
              title: 'Symptom history',
              subtitle: _symptomSummary(context),
              icon: ElaraIcons.symptom,
              onTap: () =>
                  Navigator.of(context).push(SymptomsScreen.route(context)),
            ),
            ElaraListRow(
              title: 'Care reminders',
              subtitle: _reminderSummary(context),
              icon: ElaraIcons.notification,
              onTap: () =>
                  Navigator.of(context).push(RemindersScreen.route(context)),
            ),
          ],
        ),
        const SizedBox(height: ElaraSpacing.lg),
        Text(
          'A symptom recorded here is what the suggestions on Today read. '
          'Nothing is inferred from a day with no records: an empty log is a '
          'normal log.',
          style: type.caption(tokens.textSecondaryStrong),
        ),
      ],
    );
  }

  static String _symptomSummary(BuildContext context) {
    final recent = context.watch<SymptomsProvider>().recent;
    if (recent.isEmpty) return 'Nothing recorded yet';
    final days = recent.map((s) => dateOnly(s.date)).toSet().length;
    return days == 1 ? 'Recorded on 1 day' : 'Recorded on $days days';
  }

  static String _reminderSummary(BuildContext context) {
    final upcoming = context.watch<RemindersProvider>().upcoming();
    if (upcoming.isEmpty) return 'Nothing planned';
    if (upcoming.length == 1) return '1 planned in the next week';
    return '${upcoming.length} planned in the next week';
  }
}
