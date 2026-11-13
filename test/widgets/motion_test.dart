import 'package:elara_app/theme/elara_motion.dart';
import 'package:elara_app/widgets/motion.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

/// The motion system has one rule above all others: when the platform has
/// asked for animations to be removed, the app does not animate.
///
/// Android's "Remove animations" accessibility setting is reported by the
/// engine as `MediaQueryData.disableAnimations`. An app that keeps animating
/// anyway is choosing a stranger's discomfort over their own setting, so
/// every duration in `ElaraMotion` collapses to zero when it is set.
void main() {
  /// Pumps [child] with the platform's animation setting either on or off.
  Future<void> pumpWith(
    WidgetTester tester,
    Widget child, {
    required bool disableAnimations,
  }) async {
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: MaterialApp(home: Scaffold(body: child)),
      ),
    );
  }

  group('ElaraMotion.reduceMotion', () {
    testWidgets('is false when the platform allows animations',
        (tester) async {
      late bool reduced;
      await pumpWith(
        tester,
        Builder(
          builder: (context) {
            reduced = ElaraMotion.reduceMotion(context);
            return const SizedBox.shrink();
          },
        ),
        disableAnimations: false,
      );

      expect(reduced, isFalse);
    });

    testWidgets('is true when the platform removes animations',
        (tester) async {
      late bool reduced;
      await pumpWith(
        tester,
        Builder(
          builder: (context) {
            reduced = ElaraMotion.reduceMotion(context);
            return const SizedBox.shrink();
          },
        ),
        disableAnimations: true,
      );

      expect(reduced, isTrue);
    });
  });

  group('ElaraMotion.duration', () {
    testWidgets('keeps the duration when animations are allowed',
        (tester) async {
      late Duration resolved;
      await pumpWith(
        tester,
        Builder(
          builder: (context) {
            resolved = ElaraMotion.duration(context, ElaraMotion.medium);
            return const SizedBox.shrink();
          },
        ),
        disableAnimations: false,
      );

      expect(resolved, ElaraMotion.medium);
    });

    testWidgets('collapses to zero when animations are removed',
        (tester) async {
      late Duration resolved;
      await pumpWith(
        tester,
        Builder(
          builder: (context) {
            resolved = ElaraMotion.duration(context, ElaraMotion.medium);
            return const SizedBox.shrink();
          },
        ),
        disableAnimations: true,
      );

      expect(resolved, Duration.zero);
    });

    test('nothing in the app is allowed to run for a third of a second', () {
      // The app is opened many times a day. A slow transition becomes a chore.
      for (final duration in <Duration>[
        ElaraMotion.fast,
        ElaraMotion.medium,
        ElaraMotion.slow,
        ElaraMotion.press,
      ]) {
        expect(
          duration,
          lessThan(const Duration(milliseconds: 300)),
          reason: '$duration is too long for this app',
        );
      }
    });
  });

  group('ElaraAnimatedColor', () {
    testWidgets('does not animate when animations are removed',
        (tester) async {
      const start = Color(0xFF000000);
      const end = Color(0xFFFFFFFF);

      await pumpWith(
        tester,
        const ElaraAnimatedColor(
          color: start,
          child: SizedBox.shrink(),
        ),
        disableAnimations: true,
      );

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: const MaterialApp(
            home: Scaffold(
              body: ElaraAnimatedColor(
                color: end,
                child: SizedBox.shrink(),
              ),
            ),
          ),
        ),
      );

      // With animations removed the colour is the new one on the very first
      // frame after the change - there is no intermediate value to be seen.
      expect(_paintedColour(tester), end);
    });

    testWidgets('animates towards the new colour when animations are allowed',
        (tester) async {
      const start = Color(0xFF000000);
      const end = Color(0xFFFFFFFF);

      await pumpWith(
        tester,
        const ElaraAnimatedColor(
          color: start,
          child: SizedBox.shrink(),
        ),
        disableAnimations: false,
      );

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(),
          child: const MaterialApp(
            home: Scaffold(
              body: ElaraAnimatedColor(
                color: end,
                child: SizedBox.shrink(),
              ),
            ),
          ),
        ),
      );

      // Halfway through, the colour is neither the old one nor the new one:
      // the change is in progress.
      await tester.pump(const Duration(milliseconds: 60));
      final midway = _paintedColour(tester);
      expect(midway, isNot(start));
      expect(midway, isNot(end));

      await tester.pumpAndSettle();
      expect(_paintedColour(tester), end);
    });
  });

  group('ElaraFadeIn', () {
    testWidgets('the content is fully visible immediately when animations are '
        'removed', (tester) async {
      await pumpWith(
        tester,
        const ElaraFadeIn(child: Text('Hello')),
        disableAnimations: true,
      );

      // No fade, no flash: the content is simply there on the first frame,
      // with no FadeTransition at all.
      expect(
        find.descendant(
          of: find.byType(ElaraFadeIn),
          matching: find.byType(FadeTransition),
        ),
        findsNothing,
      );
      expect(find.text('Hello'), findsOneWidget);
    });

    testWidgets('the content fades in when animations are allowed',
        (tester) async {
      await pumpWith(
        tester,
        const ElaraFadeIn(child: Text('Hello')),
        disableAnimations: false,
      );

      final fade = tester.widget<FadeTransition>(
        find.descendant(
          of: find.byType(ElaraFadeIn),
          matching: find.byType(FadeTransition),
        ),
      );
      expect(fade.opacity.value, 0.0);

      await tester.pump(const Duration(milliseconds: 100));
      final half = tester.widget<FadeTransition>(
        find.descendant(
          of: find.byType(ElaraFadeIn),
          matching: find.byType(FadeTransition),
        ),
      );
      expect(half.opacity.value, greaterThan(0.0));
      expect(half.opacity.value, lessThan(1.0));

      await tester.pumpAndSettle();
      final done = tester.widget<FadeTransition>(
        find.descendant(
          of: find.byType(ElaraFadeIn),
          matching: find.byType(FadeTransition),
        ),
      );
      expect(done.opacity.value, 1.0);
    });
  });

  group('ElaraCountUp', () {
    testWidgets('shows the value immediately when animations are removed',
        (tester) async {
      await pumpWith(
        tester,
        ElaraCountUp(
          value: 20,
          builder: (context, value) => Text(value.round().toString()),
        ),
        disableAnimations: true,
      );

      expect(
        find.descendant(
          of: find.byType(ElaraCountUp),
          matching: find.text('20'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('counts to a new value when animations are allowed',
        (tester) async {
      await pumpWith(
        tester,
        ElaraCountUp(
          value: 20,
          builder: (context, value) => Text(value.round().toString()),
        ),
        disableAnimations: false,
      );

      // The value changes: the count-up runs.
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(),
          child: MaterialApp(
            home: Scaffold(
              body: ElaraCountUp(
                value: 5,
                builder: (context, value) => Text(value.round().toString()),
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 140));
      final midway = tester.widget<Text>(
        find.descendant(
          of: find.byType(ElaraCountUp),
          matching: find.textContaining(RegExp(r'^\d+$')),
        ),
      );
      final midwayValue = int.parse(midway.data!);
      expect(midwayValue, greaterThan(5));
      expect(midwayValue, lessThan(20));

      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(ElaraCountUp),
          matching: find.text('5'),
        ),
        findsOneWidget,
      );
    });
  });
}

/// The colour actually painted behind the widget under test.
///
/// `AnimatedContainer` keeps its colour private, so the test reads the
/// decoration off the `Container` it builds rather than off the widget that
/// drives it. This is the colour a person would see.
Color? _paintedColour(WidgetTester tester) {
  // The last decorated container is the innermost one, which is the colour
  // the widget under test actually paints: the outer ones belong to the
  // Scaffold and the MaterialApp's own surfaces.
  Color? found;
  for (final container in tester.widgetList<Container>(find.byType(Container))) {
    final decoration = container.decoration;
    if (decoration is BoxDecoration && decoration.color != null) {
      found = decoration.color;
    }
  }
  if (found != null) return found;
  // With animations removed the widget paints a DecoratedBox directly, so that
  // path has to be read too — otherwise the test would pass by finding nothing
  // and comparing null to null.
  for (final box in tester.widgetList<DecoratedBox>(find.byType(DecoratedBox))) {
    final decoration = box.decoration;
    if (decoration is BoxDecoration && decoration.color != null) {
      found = decoration.color;
    }
  }
  if (found != null) return found;
  for (final box in tester.widgetList<ColoredBox>(find.byType(ColoredBox))) {
    found = box.color;
  }
  return found;
}
