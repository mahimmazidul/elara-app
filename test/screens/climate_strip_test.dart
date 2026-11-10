import 'package:elara_app/data/models/climate_snapshot.dart';
import 'package:elara_app/screens/today/climate_strip.dart';
import 'package:elara_app/theme/elara_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The climate section has to reflow rather than overflow.
///
/// It puts two measured figures side by side with a divider between them, and
/// the figures carry a unit ("°C", "µg/m³") that is already wide. At a large
/// text scale the two columns no longer fit, and the divider is a fixed
/// height that would cut the taller column in half.
///
/// These tests cover the widths the design brief names and the text scales
/// Android actually offers.
void main() {
  ClimateSnapshot snapshotFor(DateTime date) => ClimateSnapshot(
        date: date,
        temperature: 33,
        humidity: 78,
        heatIndex: 39,
        sunshineHours: 7,
        pm25: 118,
        aqiCategory: 'Unhealthy for sensitive groups',
        isFallback: true,
      );

  Future<void> pumpStrip(
    WidgetTester tester, {
    required Size size,
    required double textScale,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScale),
        ),
        child: MaterialApp(
          theme: ElaraTheme.light(phaseKey: 'luteal'),
          home: Scaffold(
            body: SingleChildScrollView(
              child: ClimateStrip(
                snapshot: snapshotFor(DateTime(2026, 11, 8)),
                phaseKey: 'luteal',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  group('climate strip reflows', () {
    for (final width in <double>[320, 360, 390, 430]) {
      testWidgets('lays out at ${width.toInt()}dp', (tester) async {
        await pumpStrip(
          tester,
          size: Size(width, 844),
          textScale: 1.0,
        );
        expect(tester.takeException(), isNull, reason: '${width.toInt()}dp');
      });
    }

    for (final scale in <double>[1.5, 2.0]) {
      testWidgets('survives a ${scale}x text scale', (tester) async {
        await pumpStrip(
          tester,
          size: const Size(320, 844),
          textScale: scale,
        );
        expect(tester.takeException(), isNull, reason: '${scale}x at 320dp');
      });
    }

    testWidgets('the season name is readable at 2x text', (tester) async {
      await pumpStrip(
        tester,
        size: const Size(320, 844),
        textScale: 2.0,
      );

      // The season is a caption under the figures, not a third column, so it
      // must still be on screen and must not be ellipsised away.
      final season = find.textContaining('season');
      expect(season, findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the estimated badge does not crowd the heading',
        (tester) async {
      await pumpStrip(
        tester,
        size: const Size(320, 844),
        textScale: 2.0,
      );

      expect(find.text('estimated'), findsOneWidget);
      // The overline is rendered in capitals, so the search is for the
      // upper-cased form of the heading.
      expect(find.text('TODAY\u2019S CLIMATE'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
