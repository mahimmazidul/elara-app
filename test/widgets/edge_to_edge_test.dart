import 'package:elara_app/theme/elara_theme.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

/// The window draws edge to edge, so the page background reaches the physical
/// edges of the display and the content stays clear of the system bars.
///
/// These assertions cover the Flutter half of that contract. The native half
/// — a transparent window, `setDecorFitsSystemWindows(false)` — is in
/// `MainActivity.kt`, and the whole arrangement is checked on a real emulator
/// by the Android CI workflow, which captures the status bar in the
/// screenshot.
void main() {
  group('system bar overlay style', () {
    test('the light theme asks for dark status bar icons', () {
      final style = ElaraTheme.light().appBarTheme.systemOverlayStyle;
      expect(style, isNotNull);
      expect(style!.statusBarColor, Colors.transparent);
      expect(style.systemNavigationBarColor, Colors.transparent);
      expect(style.statusBarIconBrightness, Brightness.dark);
      expect(style.systemNavigationBarIconBrightness, Brightness.dark);
    });

    test('the dark theme asks for light status bar icons', () {
      final style = ElaraTheme.dark().appBarTheme.systemOverlayStyle;
      expect(style, isNotNull);
      expect(style!.statusBarColor, Colors.transparent);
      expect(style.systemNavigationBarColor, Colors.transparent);
      expect(style.statusBarIconBrightness, Brightness.light);
      expect(style.systemNavigationBarIconBrightness, Brightness.light);
    });

    test('the navigation bar is not given a contrast scrim', () {
      // Android 10+ draws a translucent scrim behind a transparent
      // navigation bar unless this is switched off, and that scrim is the
      // grey band this change removes.
      for (final theme in [ElaraTheme.light(), ElaraTheme.dark()]) {
        final style = theme.appBarTheme.systemOverlayStyle!;
        expect(style.systemNavigationBarContrastEnforced, isFalse);
        expect(style.systemNavigationBarDividerColor, Colors.transparent);
      }
    });
  });

  group('theme', () {
    test('the scaffold background is the page colour, not a system colour', () {
      // The window background behind the app is this colour; if the Flutter
      // scaffold painted something else, the top and bottom edges would show
      // a seam.
      final light = ElaraTheme.light().scaffoldBackgroundColor;
      final dark = ElaraTheme.dark().scaffoldBackgroundColor;
      // The palette is the source of truth: this asserts the scaffold follows
      // it, and tool/check_manifest.py asserts the Android launch colour does
      // the same. Hard-coding the literals here made three copies of one
      // colour, and two of them went stale.
      expect(light, ElaraPalette.light.bgPrimary);
      expect(dark, ElaraPalette.dark.bgPrimary);
    });

    test('the app bar is transparent over the page', () {
      // An app bar with its own opaque background would paint a band across
      // the status bar, which is exactly the disconnected look being fixed.
      final theme = ElaraTheme.light();
      expect(theme.appBarTheme.backgroundColor, theme.scaffoldBackgroundColor);
      expect(theme.appBarTheme.scrolledUnderElevation, 0);
    });
  });
}
