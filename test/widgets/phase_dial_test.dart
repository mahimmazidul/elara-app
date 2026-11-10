import 'package:elara_app/theme/elara_theme.dart';
import 'package:elara_app/widgets/phase_dial.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The dial replaced a filled disc that repeated the phase chip above it.
///
/// What it has to get right is the thing a disc cannot say: where today sits in
/// the cycle, and — just as important — that a missing phase is a state of its
/// own rather than a cycle at zero.
void main() {
  Future<void> pump(
    WidgetTester tester,
    Widget dial, {
    double textScale = 1.0,
    Size size = const Size(390, 844),
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: ElaraTheme.light(),
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(textScale),
          ),
          child: Scaffold(body: Center(child: dial)),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
  }

  testWidgets('reads out the phase, the day and the cycle length',
      (tester) async {
    await pump(
      tester,
      const PhaseDial(
        label: 'Ovulatory',
        phaseKey: 'ovulatory',
        cycleDay: 10,
        cycleLength: 30,
        fill: Color(0xFF8B92E8),
      ),
    );

    expect(find.text('Ovulatory'), findsOneWidget);
    expect(find.text('Day 10 of 30'), findsOneWidget);
  });

  testWidgets('carries one spoken label rather than three fragments',
      (tester) async {
    await pump(
      tester,
      const PhaseDial(
        label: 'Ovulatory',
        phaseKey: 'ovulatory',
        cycleDay: 10,
        cycleLength: 30,
        fill: Color(0xFF8B92E8),
      ),
    );

    expect(
      find.bySemanticsLabel('Ovulatory, day 10 of 30'),
      findsOneWidget,
    );
  });

  testWidgets('an unknown phase says so instead of drawing a sweep',
      (tester) async {
    await pump(
      tester,
      const PhaseDial(
        label: 'Unclassified',
        phaseKey: 'unknown',
        fill: Color(0xFF9AA0A6),
      ),
    );

    expect(find.text('Unclassified'), findsOneWidget);
    expect(find.textContaining('Day'), findsNothing);
    expect(
      find.bySemanticsLabel('Unclassified. No phase for today.'),
      findsOneWidget,
    );
  });

  testWidgets('a long label and 2x text still fit the page', (tester) async {
    await pump(
      tester,
      const PhaseDial(
        label: 'Unclassified',
        phaseKey: 'unknown',
        cycleDay: 12,
        cycleLength: 31,
        fill: Color(0xFF9AA0A6),
      ),
      textScale: 2.0,
      size: const Size(320, 800),
    );

    expect(tester.takeException(), isNull);
    final dial = tester.getSize(find.byType(PhaseDial));
    expect(dial.width, lessThanOrEqualTo(320));
  });

  test('the cycle moon runs new, waxing, full, waning', () {
    expect(PhaseDial.moonFractionFor('menstrual'), 0.0);
    expect(PhaseDial.moonFractionFor('ovulatory'), 0.5);
    expect(
      PhaseDial.moonFractionFor('follicular'),
      inExclusiveRange(0.0, 0.5),
    );
    expect(
      PhaseDial.moonFractionFor('luteal'),
      inExclusiveRange(0.5, 1.0),
    );
  });
}
