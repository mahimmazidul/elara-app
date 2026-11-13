import 'package:elara_app/widgets/elara_route.dart';
import 'package:elara_app/widgets/motion.dart';
import 'package:elara_app/widgets/primitives.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

/// The press feedback and the page transition.
///
/// Both are new, and both have one rule above all others: when the platform
/// has asked for animations to be removed, neither of them animates.
///
/// Android's "Remove animations" accessibility setting is reported by the
/// engine as `MediaQueryData.disableAnimations`. An app that keeps animating
/// anyway is choosing a stranger's discomfort over their own setting.
void main() {
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

  group('ElaraPressable', () {
    testWidgets('scales down while the finger is down', (tester) async {
      await pumpWith(
        tester,
        ElaraPressable(
          onTap: () {},
          child: const SizedBox(width: 100, height: 100),
        ),
        disableAnimations: false,
      );

      expect(find.byType(AnimatedScale), findsOneWidget);

      final gesture =
          await tester.startGesture(tester.getCenter(find.byType(SizedBox)));
      await tester.pump();

      final scale = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
      expect(scale.scale, lessThan(1.0));

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('does not animate when animations are removed',
        (tester) async {
      await pumpWith(
        tester,
        ElaraPressable(
          onTap: () {},
          child: const SizedBox(width: 100, height: 100),
        ),
        disableAnimations: true,
      );

      // No AnimatedScale at all: the surface does not move.
      expect(find.byType(AnimatedScale), findsNothing);

      // But the tap still works. Turning off animations is a request for
      // less movement, not for an interface that stops responding.
      var tapped = false;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            home: Scaffold(
              body: ElaraPressable(
                onTap: () => tapped = true,
                child: const SizedBox(width: 100, height: 100),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(SizedBox).first);
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets('the pressed tint is applied even without animations',
        (tester) async {
      await pumpWith(
        tester,
        ElaraPressable(
          onTap: () {},
          pressedColour: const Color(0x22000000),
          child: const SizedBox(width: 100, height: 100),
        ),
        disableAnimations: true,
      );

      final gesture =
          await tester.startGesture(tester.getCenter(find.byType(SizedBox)));
      await tester.pump();

      // A change of colour is not motion, so it survives the setting.
      final box = tester.widget<ColoredBox>(
        find.descendant(
          of: find.byType(ElaraPressable),
          matching: find.byType(ColoredBox),
        ),
      );
      expect(box.color, const Color(0x22000000));

      await gesture.up();
      await tester.pump();
    });
  });

  group('ElaraListRow', () {
    testWidgets('a row with a tap gives press feedback', (tester) async {
      await pumpWith(
        tester,
        ElaraListRow(title: 'A row', onTap: () {}),
        disableAnimations: false,
      );

      expect(find.byType(ElaraPressable), findsOneWidget);
    });

    testWidgets('a row without a tap does not', (tester) async {
      await pumpWith(
        tester,
        const ElaraListRow(title: 'A row'),
        disableAnimations: false,
      );

      expect(find.byType(ElaraPressable), findsNothing);
    });

    testWidgets('the tap fires exactly once', (tester) async {
      var taps = 0;
      await pumpWith(
        tester,
        ElaraListRow(title: 'A row', onTap: () => taps++),
        disableAnimations: false,
      );

      await tester.tap(find.text('A row'));
      await tester.pump();

      // The pressable wraps an InkWell; the tap must not be handled twice.
      expect(taps, 1);
    });
  });

  group('elaraRoute', () {
    testWidgets('fades and rises when animations are allowed',
        (tester) async {
      await pumpWith(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              elaraRoute<void>(context, const Text('Second')),
            ),
            child: const Text('Open'),
          ),
        ),
        disableAnimations: false,
      );

      await tester.tap(find.text('Open'));
      await tester.pump();

      expect(find.byType(FadeTransition), findsWidgets);
      expect(find.byType(SlideTransition), findsWidgets);
    });

    testWidgets('has no transition when animations are removed',
        (tester) async {
      await pumpWith(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              elaraRoute<void>(context, const Text('Second')),
            ),
            child: const Text('Open'),
          ),
        ),
        disableAnimations: true,
      );

      await tester.tap(find.text('Open'));
      await tester.pump();

      // The second screen is simply there, with no transition at all.
      expect(find.text('Second'), findsOneWidget);
      expect(find.byType(FadeTransition), findsNothing);
      expect(find.byType(SlideTransition), findsNothing);
    });

    testWidgets('the transition is under a third of a second', (tester) async {
      await pumpWith(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              elaraRoute<void>(context, const Text('Second')),
            ),
            child: const Text('Open'),
          ),
        ),
        disableAnimations: false,
      );

      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final route = ModalRoute.of(
        tester.element(find.text('Second')),
      );
      expect(route, isNotNull);
      expect(
        route!.transitionDuration,
        lessThan(const Duration(milliseconds: 300)),
        reason: 'a screen change should not take a third of a second',
      );
    });
  });
}
