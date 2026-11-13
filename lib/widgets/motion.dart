import 'package:material_ui/material_ui.dart';

import '../theme/elara_motion.dart';

/// A value that changes over time, with the change made visible.
///
/// Flutter's [AnimatedContainer], [AnimatedOpacity] and friends all animate
/// unconditionally: they keep running when the platform has asked for
/// animations to be removed. On Android that setting is off by default, so
/// it is rarely wrong — but it is exactly the switch a person turns on because
/// motion makes them ill, and an app that ignores it is choosing their
/// discomfort over their setting.
///
/// This widget is the app's answer. It animates a colour towards a new value
/// over [ElaraMotion.fast], and does not animate at all when
/// [MediaQueryData.disableAnimations] is set — it jumps straight to the new
/// colour instead.
///
/// What it is for: the phase colour. When a new cycle start is logged, the
/// accent moves from one phase to another across the whole app at once. A
/// snap makes that feel like a reload; a short cross-fade makes it feel like
/// the same screen showing a new state.
class ElaraAnimatedColor extends StatelessWidget {
  const ElaraAnimatedColor({
    super.key,
    required this.color,
    required this.child,
    this.borderRadius,
    this.duration,
    this.curve,
  });

  /// The colour to move towards.
  final Color color;

  /// The subtree drawn on [color].
  final Widget child;

  /// The corner radius of the painted fill, in logical pixels.
  ///
  /// This exists because the fill is painted by *this* widget, not by the
  /// child: a plain `ColoredBox` or `AnimatedContainer(color:)` paints the full
  /// rectangle, so a child that declared a rounded shape was drawn on top of a
  /// square in the same colour and the shape was invisible. On the Today screen
  /// that turned the phase circle into a 150x150 square, and the phase chip's
  /// corners square with it — both shipped that way, and both are visible in
  /// the screenshots in docs/.
  final double? borderRadius;

  /// How long the change takes. Defaults to [ElaraMotion.fast].
  final Duration? duration;

  /// The curve. Defaults to [ElaraMotion.curve].
  final Curve? curve;

  @override
  Widget build(BuildContext context) {
    final resolved = duration ?? ElaraMotion.fast;
    final decoration = BoxDecoration(
      color: color,
      borderRadius: borderRadius == null
          ? null
          : BorderRadius.circular(borderRadius!),
    );
    if (ElaraMotion.reduceMotion(context)) {
      // Not a shorter animation - no animation. The colour is simply the new
      // one from the first frame.
      return DecoratedBox(decoration: decoration, child: child);
    }
    return AnimatedContainer(
      duration: resolved,
      curve: curve ?? ElaraMotion.curve,
      decoration: decoration,
      child: child,
    );
  }
}

/// Content that fades in once, when it first appears.
///
/// This is the app's only entrance animation, and it is deliberately a fade
/// rather than a slide: the content is *there*, and fading it in says "this
/// is ready" without saying "look over here". A slide would pull the eye to
/// the top of the screen every time a tab is opened.
///
/// It is also the easiest place to get reduced motion wrong. A fade is motion,
/// and an app that fades content in while the user has asked for animations
/// to be removed has ignored the setting. When the platform asks for reduced
/// motion the content is present from the first frame, with no fade and no
/// flash.
class ElaraFadeIn extends StatefulWidget {
  const ElaraFadeIn({
    super.key,
    required this.child,
    this.duration,
    this.delay = Duration.zero,
  });

  /// The content to reveal.
  final Widget child;

  /// How long the fade takes. Defaults to [ElaraMotion.medium].
  final Duration? duration;

  /// How long to wait before the fade starts.
  ///
  /// A short stagger is useful when several sections arrive together and
  /// would otherwise all flash at once. It is capped by the reduced-motion
  /// rule: with animations off, the content is simply there.
  final Duration delay;

  @override
  State<ElaraFadeIn> createState() => _ElaraFadeInState();
}

class _ElaraFadeInState extends State<ElaraFadeIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration ?? ElaraMotion.medium,
  );

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The platform's animation setting is read here rather than in
    // `initState`: an inherited widget cannot be depended on before
    // `initState` has finished, and reading it there throws.
    if (_started) return;
    _started = true;

    if (ElaraMotion.reduceMotion(context)) return;
    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future<void>.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (ElaraMotion.reduceMotion(context)) {
      return widget.child;
    }
    return FadeTransition(opacity: _controller, child: widget.child);
  }
}

/// A number that counts up to its new value instead of jumping.
///
/// Elara shows numbers that matter: days until the next period, the average
/// cycle length, a heat index. When one of them changes because the user
/// logged something, a count-up says "this just became 20" in a way that a
/// jump does not - and it is the one motion in the app that carries
/// information rather than decoration.
///
/// It is skipped entirely when the platform asks for reduced motion, and
/// when the value has not changed, so it never runs on every rebuild.
class ElaraCountUp extends StatefulWidget {
  const ElaraCountUp({
    super.key,
    required this.value,
    required this.builder,
    this.duration,
    this.decimals = 0,
  });

  /// The number to show.
  final double value;

  /// Builds the text for the current, animating value.
  final Widget Function(BuildContext context, double value) builder;

  /// How long the count takes. Defaults to [ElaraMotion.slow].
  final Duration? duration;

  /// How many decimal places to print.
  final int decimals;

  @override
  State<ElaraCountUp> createState() => _ElaraCountUpState();
}

class _ElaraCountUpState extends State<ElaraCountUp>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _from = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration ?? ElaraMotion.slow,
    );
    _animation = AlwaysStoppedAnimation<double>(widget.value);
  }

  @override
  void didUpdateWidget(ElaraCountUp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value == widget.value) return;

    if (ElaraMotion.reduceMotion(context)) {
      _controller.stop();
      _from = widget.value;
      _animation = AlwaysStoppedAnimation<double>(widget.value);
      return;
    }

    _from = _animation.value;
    _controller
      ..reset()
      ..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        // Before the count starts, the value shown is the value itself: a
        // count-up that begins at zero would show a wrong number for the first
        // frame, which on a screen that states a date is a lie for as long as
        // it lasts.
        if (_controller.isDismissed) {
          return widget.builder(context, widget.value);
        }
        final t = ElaraMotion.curve.transform(_controller.value);
        final current = _from + (widget.value - _from) * t;
        return widget.builder(context, current);
      },
    );
  }
}

/// A tappable surface that gives a small, deliberate press feedback.
///
/// Elara had no press feedback at all: a row looked exactly the same before
/// and after a finger landed on it, and the app only acknowledged the tap
/// afterwards, by changing screen. A row that responds *while* the finger is
/// down feels like a physical object rather than a picture of one.
///
/// The response is a scale-down to [scale] and back. It is deliberately
/// small — a tenth of a percent is enough to read as "pressed" — because the
/// app is used in quiet moments and a large movement is startling rather
/// than reassuring. Nothing is shadowed and nothing is blurred: a shadow that
/// animates costs a real frame on a mid-range phone, and the scale alone is
/// enough to say it.
///
/// **Reduced motion.** The scale is not an animation of a visual property;
/// it is the whole feedback. So when the platform has asked for animations
/// to be removed, the row does not animate — but it still *darkens* on
/// press, because a change of colour is not motion and the person who
/// turned the setting off was not asking for the interface to stop
/// responding to their finger.
class ElaraPressable extends StatefulWidget {
  const ElaraPressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = 0.97,
    this.behaviour = HitTestBehavior.opaque,
    this.pressedColour,
  });

  /// The surface that is pressed.
  final Widget child;

  /// Called on a short tap.
  final VoidCallback? onTap;

  /// Called on a long press.
  final VoidCallback? onLongPress;

  /// How far the surface shrinks while it is held.
  final double scale;

  /// How the surface is hit-tested.
  final HitTestBehavior behaviour;

  /// The tint laid over the surface while it is held.
  ///
  /// `null` means no tint, which is the right choice for a row that already
  /// has a ripple of its own.
  final Color? pressedColour;

  @override
  State<ElaraPressable> createState() => _ElaraPressableState();
}

class _ElaraPressableState extends State<ElaraPressable> {
  bool _down = false;

  void _set(bool value) {
    if (_down == value) return;
    setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    final bool interactive = widget.onTap != null || widget.onLongPress != null;

    Widget surface = widget.child;

    // The tint is not motion, so it is applied even when animations are
    // removed.
    if (widget.pressedColour != null) {
      surface = ColoredBox(
        color: _down ? widget.pressedColour! : const Color(0x00000000),
        child: surface,
      );
    }

    if (ElaraMotion.reduceMotion(context)) {
      return GestureDetector(
        behavior: widget.behaviour,
        onTapDown: interactive ? (_) => _set(true) : null,
        onTapCancel: interactive ? () => _set(false) : null,
        onTapUp: interactive ? (_) => _set(false) : null,
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: surface,
      );
    }

    return GestureDetector(
      behavior: widget.behaviour,
      onTapDown: interactive ? (_) => _set(true) : null,
      onTapCancel: interactive ? () => _set(false) : null,
      onTapUp: interactive ? (_) => _set(false) : null,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: ElaraMotion.press,
        curve: ElaraMotion.curve,
        child: surface,
      ),
    );
  }
}
