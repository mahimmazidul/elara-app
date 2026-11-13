import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:elara_app/theme/system_overlay_style.dart';

void main() {
  group('ElaraSystemUiOverlayStyle', () {
    test('a light page gets transparent bars and dark icons', () {
      final style = ElaraSystemUiOverlayStyle.forBrightness(Brightness.light);

      expect(style.statusBarColor, Colors.transparent);
      expect(style.statusBarBrightness, Brightness.light);
      expect(style.statusBarIconBrightness, Brightness.dark);
      expect(style.systemNavigationBarColor, Colors.transparent);
      expect(style.systemNavigationBarIconBrightness, Brightness.dark);
    });

    test('a dark page gets transparent bars and light icons', () {
      final style = ElaraSystemUiOverlayStyle.forBrightness(Brightness.dark);

      expect(style.statusBarColor, Colors.transparent);
      expect(style.statusBarBrightness, Brightness.dark);
      expect(style.statusBarIconBrightness, Brightness.light);
      expect(style.systemNavigationBarColor, Colors.transparent);
      expect(style.systemNavigationBarIconBrightness, Brightness.light);
    });

    test('the platform is not allowed to add its own contrast scrim', () {
      for (final brightness in Brightness.values) {
        final style = ElaraSystemUiOverlayStyle.forBrightness(brightness);
        expect(style.systemNavigationBarContrastEnforced, isFalse,
            reason: 'the scrim is the grey band this app is removing');
        expect(style.systemStatusBarContrastEnforced, isFalse);
        expect(style.systemNavigationBarDividerColor, Colors.transparent);
      }
    });

    test('the navigation bar icons can be overridden on their own', () {
      final style = ElaraSystemUiOverlayStyle.forBrightness(
        Brightness.light,
        navigationIconBrightness: Brightness.light,
      );

      expect(style.systemNavigationBarIconBrightness, Brightness.light);
      // The status bar is unaffected by that override.
      expect(style.statusBarIconBrightness, Brightness.dark);
    });
  });

  group('ElaraSystemUiRegion', () {
    testWidgets('applies the style to the whole subtree', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ElaraSystemUiRegion(
            brightness: Brightness.dark,
            child: SizedBox.shrink(),
          ),
        ),
      );

      final region = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
        find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
      );

      expect(region.value.statusBarColor, Colors.transparent);
      expect(region.value.statusBarIconBrightness, Brightness.light);
      expect(region.value.statusBarBrightness, Brightness.dark);
    });

    testWidgets('a light page region asks for dark icons', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ElaraSystemUiRegion(
            brightness: Brightness.light,
            child: SizedBox.shrink(),
          ),
        ),
      );

      final region = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
        find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
      );

      expect(region.value.statusBarIconBrightness, Brightness.dark);
      expect(region.value.statusBarBrightness, Brightness.light);
    });
  });
}
