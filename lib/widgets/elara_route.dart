import 'package:material_ui/material_ui.dart';

import '../theme/elara_motion.dart';

/// The route every screen in the app is pushed with.
///
/// Flutter's stock [MaterialPageRoute] animates the Material "zoom" on
/// Android: the new screen grows out of the middle of the old one, over
/// about 300 ms. On a dense screen — one with a table of symptoms, or a
/// list of dates — that zoom makes the content underneath visible through
/// the incoming screen for the whole transition, and the eye has nothing
/// stable to hold on to.
///
/// A fade-and-rise is quieter and quicker: the new screen fades in while
/// lifting a little, and the old one stays put underneath it. It reads as
/// "a new page" rather than "the page is being replaced by a photograph of
/// a page".
///
/// The duration is [ElaraMotion.slow] — 280 ms, the longest in the app, and
/// only for a change of place.
///
/// **Reduced motion.** The transition is not animation-free: it *is* the
/// animation. So when the platform has asked for animations to be removed,
/// the route is pushed with no transition at all — the new screen is simply
/// there. That is checked here, at push time, rather than assumed, because
/// the setting can be changed while the app is running.
Route<T> elaraRoute<T>(
  BuildContext context,
  Widget page, {
  String? name,
}) {
  // The setting is read from the context the route is pushed from, so it
  // reflects the platform's setting as it is right now.
  if (ElaraMotion.reduceMotion(context)) {
    return PageRouteBuilder<T>(
      settings: RouteSettings(name: name),
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      pageBuilder: (context, animation, secondaryAnimation) => page,
    );
  }

  return PageRouteBuilder<T>(
    settings: RouteSettings(name: name),
    transitionDuration: ElaraMotion.slow,
    reverseTransitionDuration: ElaraMotion.medium,
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder:
        (context, animation, secondaryAnimation, child) {
      // A curve that starts fast and settles, for the way in; and one that
      // accelerates out, for the way back. "It arrived" and "it is leaving"
      // are different movements and should not use the same curve.
      final curved = CurvedAnimation(
        parent: animation,
        curve: ElaraMotion.curve,
        reverseCurve: ElaraMotion.exitCurve,
      );

      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          // A small rise: 4% of the screen's height. Enough to read as
          // "coming forward", not enough to be a slide.
          position: Tween<Offset>(
            begin: const Offset(0, 0.04),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}
