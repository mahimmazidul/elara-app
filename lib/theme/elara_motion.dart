import 'package:material_ui/material_ui.dart';

/// How long Elara's animations run, and whether they run at all.
///
/// The app is a quiet one: it shows a cycle's state, a few suggestions and
/// some health information. Nothing here needs to attract attention with
/// movement, so the motion is deliberately small and purposeful — it exists to
/// show where something came from or where it went, not to decorate.
///
/// Two rules govern every duration in this file:
///
///  * **Nothing is longer than a third of a second.** A slow transition on a
///    screen the user opens dozens of times a day becomes a chore. The
///    longest here is 280 ms, and that is for a sheet, which is a change of
///    place.
///  * **Nothing moves that does not have to.** A colour change is a colour
///    change; it does not need to slide.
///
/// The reduced-motion question is answered by the platform, not by the app's
/// own opinion. Android's "Remove animations" setting in Accessibility is
/// reported by the engine as [MediaQueryData.disableAnimations], and Flutter
/// also stops its own implicit animations when it is set. An app that keeps
/// animating anyway is overriding a setting the user made because motion makes
/// them ill, so [reduceMotion] shortens every duration to zero rather than
/// merely making them shorter.
class ElaraMotion {
  const ElaraMotion._();

  /// A colour or opacity change: the accent moving from one phase to the next.
  static const Duration fast = Duration(milliseconds: 120);

  /// A size or position change inside a screen: a chip expanding, a row
  /// appearing.
  static const Duration medium = Duration(milliseconds: 200);

  /// A change of place: a sheet rising, a route being pushed.
  static const Duration slow = Duration(milliseconds: 280);

  /// How long a press highlight takes to fade back out.
  static const Duration press = Duration(milliseconds: 90);

  /// Whether the platform has asked for animations to be removed.
  ///
  /// [MediaQueryData.disableAnimations] is set by Android's "Remove
  /// animations" accessibility setting and by Flutter's own
  /// `AccessibilityFeatures.disableAnimations`. Either is enough.
  static bool reduceMotion(BuildContext context) {
    final data = MediaQuery.maybeOf(context);
    if (data == null) return false;
    return data.disableAnimations ||
        data.accessibleNavigation;
  }

  /// [duration], or zero when the platform has asked for animations to be
  /// removed.
  ///
  /// This is the only way durations should be read in the app. A widget that
  /// builds its own `Tween` with a literal duration will keep animating when
  /// the user has asked it not to, which is exactly the case the platform
  /// setting exists to cover.
  static Duration duration(BuildContext context, Duration duration) {
    if (reduceMotion(context)) return Duration.zero;
    return duration;
  }

  /// The curve used for motion in this app.
  ///
  /// `easeOutCubic` starts fast and settles, which reads as "it arrived".
  /// `easeOutCubic` is also what Flutter's own [Material] motion uses for
  /// most of its transitions, so the app's motion does not feel like a
  /// different app from the platform's.
  static const Curve curve = Curves.easeOutCubic;

  /// The curve used when something leaves the screen.
  ///
  /// Accelerating out reads as "it is going away", where decelerating in
  /// reads as "it has arrived".
  static const Curve exitCurve = Curves.easeInCubic;
}
