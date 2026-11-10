import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The system bar style Elara uses, for a given page brightness.
///
/// The app draws edge to edge: the page background runs behind the status and
/// navigation bars instead of stopping at them. For that to look right the
/// bars themselves have to be transparent and the icons have to contrast with
/// whatever is behind them.
///
/// Both parts matter and they pull in opposite directions:
///
///  * `statusBarColor` and `navigationBarColor` are transparent, so the page
///    shows through the bars instead of a grey band.
///  * `statusBarBrightness` (the *background* brightness, confusingly) and
///    `statusBarIconBrightness` are set together. They are opposites: a light
///    page needs dark icons, and `statusBarBrightness: Brightness.light` is
///    what makes the platform draw them dark. Getting only one of the two
///    right is what produces the classic invisible-icon bug.
///
/// `systemNavigationBarContrastEnforced` is turned off because Android would
/// otherwise paint its own translucent scrim over the navigation bar to
/// guarantee contrast — that scrim is exactly the grey band this app is
/// trying to get rid of. The icons' brightness is set explicitly instead, so
/// contrast is the app's decision rather than the platform's.
///
/// [statusBarIconBrightness] and [systemNavigationBarIconBrightness] are
/// separate because a page can be light while the navigation area sits on a
/// darker surface; in practice Elara keeps them the same, but the two are
/// exposed so a screen with a dark footer can override just the navigation
/// bar.
class ElaraSystemUiOverlayStyle {
  const ElaraSystemUiOverlayStyle._();

  /// The overlay style for a page of the given [brightness].
  ///
  /// [brightness] is the brightness of the *page background* behind the bars,
  /// not the brightness of the icons.
  static SystemUiOverlayStyle forBrightness(
    Brightness brightness, {
    Brightness? navigationIconBrightness,
  }) {
    final bool darkPage = brightness == Brightness.dark;
    // On a dark page the icons have to be light, and vice versa.
    final Brightness iconBrightness =
        darkPage ? Brightness.light : Brightness.dark;

    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarBrightness: darkPage ? Brightness.dark : Brightness.light,
      statusBarIconBrightness: iconBrightness,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarContrastEnforced: false,
      systemNavigationBarIconBrightness:
          navigationIconBrightness ?? iconBrightness,
      systemStatusBarContrastEnforced: false,
    );
  }
}

/// Wraps [child] in an [AnnotatedRegion] that fixes the system bar style for
/// the whole subtree.
///
/// This is the app-wide version of the same idea as
/// [ElaraTheme]'s `appBarTheme.systemOverlayStyle`, and it exists because of a
/// concrete defect found on an Android 13 emulator: screens without an
/// `AppBar` — the consent gate, for one — never got an overlay style at all,
/// so the Flutter engine fell back to its own default and painted a grey
/// band behind the status bar even though the window was already drawing
/// edge to edge. The `AppBar`-scoped style could not fix that, because those
/// screens have no `AppBar`.
///
/// Putting the style in an [AnnotatedRegion] around the whole app means every
/// screen inherits it, including any that has no `AppBar`.
class ElaraSystemUiRegion extends StatelessWidget {
  const ElaraSystemUiRegion({
    super.key,
    required this.brightness,
    required this.child,
  });

  /// The brightness of the page background behind the bars.
  final Brightness brightness;

  /// The subtree the style applies to.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: ElaraSystemUiOverlayStyle.forBrightness(brightness),
      child: child,
    );
  }
}
