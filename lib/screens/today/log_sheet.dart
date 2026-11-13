import 'package:material_ui/material_ui.dart';

import '../../theme/elara_theme.dart';
import '../../widgets/icons.dart';
import '../../widgets/primitives.dart';
import '../calendar/period_start_flow.dart';
import '../symptoms/symptom_editor.dart';

/// What the centre action of the bottom bar offers.
///
/// The bar had four tabs and no way to record anything, so the one thing the app
/// exists for - keeping a record - was always two taps away, and on a tab you had
/// to know to visit. The centre action is the same button on every tab.
///
/// It offers exactly the two things a person actually writes down: when a period
/// started, and how a day felt. Both already existed as flows, so this is a door
/// rather than a second implementation; nothing here writes data of its own.
Future<void> showLogSheet(BuildContext context) async {
  final choice = await showModalBottomSheet<_LogChoice>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => const _LogSheet(),
  );
  if (choice == null || !context.mounted) return;

  switch (choice) {
    case _LogChoice.periodStart:
      await logPeriodStart(context);
    case _LogChoice.symptom:
      await SymptomEditor.show(context);
  }
}

enum _LogChoice { periodStart, symptom }

class _LogSheet extends StatelessWidget {
  const _LogSheet();

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    final type = context.type;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          ElaraSpacing.lg,
          0,
          ElaraSpacing.lg,
          ElaraSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Log', style: type.subtitle(tokens.textPrimary)),
            const SizedBox(height: ElaraSpacing.xs),
            Text(
              'What would you like to write down?',
              style: type.caption(tokens.textSecondaryStrong),
            ),
            const SizedBox(height: ElaraSpacing.sm),
            ElaraListRow(
              title: 'A period start',
              subtitle: 'Choose the day it began.',
              icon: ElaraIcons.recorded,
              onTap: () => Navigator.of(context).pop(_LogChoice.periodStart),
            ),
            const Hairline(),
            ElaraListRow(
              title: 'A symptom',
              subtitle: 'Note what she felt, and when.',
              icon: ElaraIcons.symptom,
              onTap: () => Navigator.of(context).pop(_LogChoice.symptom),
            ),
          ],
        ),
      ),
    );
  }
}
