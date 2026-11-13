import 'package:elara_app/screens/care/partner_guide_screen.dart';
import 'package:elara_app/theme/elara_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('Today opens the guide at its estimated phase', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ElaraTheme.light(),
        home: const PartnerGuideScreen(currentPhaseKey: 'luteal'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('What helps, by phase'), findsOneWidget);
    expect(find.text('Luteal'), findsOneWidget);
    expect(find.text('ESTIMATED FOR TODAY'), findsOneWidget);
    expect(find.text('Some notice a pattern; no one is a calendar.'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the guide has a useful first page without a current estimate',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ElaraTheme.light(),
        home: const PartnerGuideScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Menstrual'), findsOneWidget);
    expect(find.text('ESTIMATED FOR TODAY'), findsNothing);
    expect(find.textContaining('Dates can suggest a phase'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
