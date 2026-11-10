import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../providers/update_provider.dart';
import '../theme/elara_theme.dart';
import '../theme/elara_motion.dart';
import '../widgets/primitives.dart';
import 'calendar/calendar_screen.dart';
import 'insights/insights_screen.dart';
import 'settings/settings_screen.dart';
import 'today/today_screen.dart';

/// The app shell.
///
/// Phones get four tabs over an [IndexedStack]; anything wider than
/// [railBreakpoint] gets a [NavigationRail] beside the content, which is the
/// Material pattern for that size and stops a tablet from showing a phone
/// layout stretched across 900 logical pixels.
///
/// IndexedStack in both cases rather than swapping children, so each tab keeps
/// its scroll position and the calendar keeps its visible month when the user
/// moves away.
///
/// Motion language (all skipped under reduced motion):
///   * Traveling bottom-nav indicator that glides between tabs.
///   * Directional fill animation: the fill stretches toward the direction of
///     travel so the movement reads as a glide, not a teleport.
///   * Screen-slide transition synced with tab movement: switching tabs slides
///     the new screen in from the direction of travel.
///   * Animated active/inactive icons: active icons use the phase colour, and
///     a tap gives immediate scale-down feedback.
class RootScaffold extends StatefulWidget {
  const RootScaffold({super.key});

  /// Above this width the rail replaces the bottom bar.
  static const double railBreakpoint = 720;

  @override
  State<RootScaffold> createState() => _RootScaffoldState();
}

class _RootScaffoldState extends State<RootScaffold>
    with TickerProviderStateMixin {
  int _index = 0;
  int _previousIndex = 0;

  /// Direction of the last tab change: +1 for right, -1 for left, 0 on first
  /// paint. Drives both the indicator fill stretch and the screen-slide
  /// direction.
  int _direction = 0;

  /// Animates the traveling nav indicator's position and fill stretch.
  late final AnimationController _navController;

  /// Animates the screen slide between tabs.
  late final AnimationController _slideController;

  /// How far the content is currently dragged, in logical pixels.
  ///
  /// Driven by a horizontal drag anywhere on the content and read by a
  /// [ValueListenableBuilder] rather than [setState], so following a finger does
  /// not rebuild the whole shell sixty times a second — only the transform.
  final ValueNotifier<double> _drag = ValueNotifier<double>(0);

  /// The raw distance of the current gesture, before the edge resistance is
  /// applied. The decision to change tab is made from this, not from [_drag],
  /// or a swipe at the first tab would need a much longer gesture than one in
  /// the middle.
  double _dragRaw = 0;

  /// How far a gesture has to travel before it counts as a tab change. Low
  /// enough to work with a thumb on a 320dp phone, high enough that a diagonal
  /// scroll does not change tabs by accident.
  static const double _swipeFraction = 0.16;

  /// Where the content stops following the finger, as a fraction of the width.
  static const double _dragLimitFraction = 0.34;

  /// The start-up update check runs once per launch at most, and only when the
  /// user has switched it on. It is a single public request to GitHub that
  /// carries nothing about this phone.
  bool _startupCheckAttempted = false;

  @override
  void initState() {
    super.initState();
    _navController = AnimationController(
      vsync: this,
      duration: ElaraMotion.medium,
    );
    _slideController = AnimationController(
      vsync: this,
      duration: ElaraMotion.slow,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_startupCheckAttempted) return;
    _startupCheckAttempted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final settings = context.read<SettingsProvider?>();
      if (settings?.updatesAutoCheck != true) return;
      context.read<UpdateProvider?>()?.check();
    });
  }

  /// Resistance is what tells the finger there is nothing to the left of the
  /// first tab. Without it the content slides freely into empty space and the
  /// app feels broken at both ends.
  double _resist(double raw, double width) {
    final atStart = _index == 0 && raw > 0;
    final atEnd = _index == _tabCount - 1 && raw < 0;
    final scaled = (atStart || atEnd) ? raw * 0.22 : raw;
    final limit = width * _dragLimitFraction;
    return scaled.clamp(-limit, limit);
  }

  static int get _tabCount => _destinations.length;

  void _onDragStart(DragStartDetails details) {
    _dragRaw = 0;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    _dragRaw += details.delta.dx;
    // A reduced-motion user gets the same navigation, without the content
    // sliding under their finger while they do it.
    if (ElaraMotion.reduceMotion(context)) return;
    _drag.value = _resist(_dragRaw, MediaQuery.sizeOf(context).width);
  }

  void _onDragEnd(DragEndDetails details) {
    final width = MediaQuery.sizeOf(context).width;
    final distance = _dragRaw;
    final velocity = details.velocity.pixelsPerSecond.dx;
    _dragRaw = 0;
    // Spring back first, so the content is never left offset when the gesture
    // is a miss.
    _drag.value = 0;

    final travelled = distance.abs() > width * _swipeFraction;
    // A quick flick counts even when it is short: that is how it feels natural
    // to move between tabs one-handed.
    final flicked = velocity.abs() > 320 && distance.abs() > 24;
    if (!travelled && !flicked) return;

    final forwards = distance < 0;
    final target = _index + (forwards ? 1 : -1);
    if (target < 0 || target >= _tabCount) return;
    _selectTab(target);
  }

  @override
  void dispose() {
    _drag.dispose();
    _navController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  void _selectTab(int value) {
    if (value == _index) return;

    setState(() {
      _previousIndex = _index;
      _direction = value > _index ? 1 : -1;
      _index = value;
    });

    if (ElaraMotion.reduceMotion(context)) {
      _navController.value = 1.0;
      _slideController.value = 1.0;
    } else {
      _navController
        ..reset()
        ..forward();
      _slideController
        ..reset()
        ..forward();
    }
  }

  static const List<Widget> _tabs = [
    TodayScreen(),
    CalendarScreen(),
    InsightsScreen(),
    SettingsScreen(),
  ];

  static const List<({IconData icon, IconData selected, String label})>
      _destinations = [
    (icon: Icons.today_outlined, selected: Icons.today, label: 'Today'),
    (
      icon: Icons.calendar_month_outlined,
      selected: Icons.calendar_month,
      label: 'Calendar'
    ),
    (
      icon: Icons.insights_outlined,
      selected: Icons.insights,
      label: 'Insights'
    ),
    (icon: Icons.settings_outlined, selected: Icons.settings, label: 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    final isWide =
        MediaQuery.sizeOf(context).width >= RootScaffold.railBreakpoint;

    final content = ElaraContentWidth(
      maxWidth: isWide ? 720 : double.infinity,
      child: _SwipeTabs(
        drag: _drag,
        onStart: _onDragStart,
        onUpdate: _onDragUpdate,
        onEnd: _onDragEnd,
        child: _ScreenSlide(
          controller: _slideController,
          direction: _direction,
          child: IndexedStack(index: _index, children: _tabs),
        ),
      ),
    );

    return Scaffold(
      backgroundColor: tokens.bgPrimary,
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: isWide
            ? Row(
                children: [
                  _Rail(index: _index, onSelected: _selectTab),
                  Expanded(child: content),
                ],
              )
            : content,
      ),
      bottomNavigationBar: isWide ? null : _Bar(
        index: _index,
        previousIndex: _previousIndex,
        controller: _navController,
        direction: _direction,
        onSelected: _selectTab,
      ),
    );
  }
}

/// Makes the content follow a horizontal drag, so the tabs can be swiped as
/// well as tapped.
///
/// It sits *outside* the tab content and uses a plain horizontal drag
/// recogniser, which is what makes it safe: a vertical scroll in any tab's list
/// claims the gesture first (different axis, no contest), and any horizontal
/// scroller inside a tab — a chart that pans, a row that scrolls — wins the
/// arena over this one because the deepest recogniser takes the prize. So a
/// swipe only changes tab when nothing else wanted the gesture, which is exactly
/// when the reader meant the tab.
///
/// The content moves with the finger and springs back on a miss. Following the
/// finger is the whole difference between "swipe navigation" and "a tab change
/// that happens to be triggered by a swipe": one feels like a surface being
/// pushed, the other like a button being pressed out of sight.
class _SwipeTabs extends StatelessWidget {
  const _SwipeTabs({
    required this.drag,
    required this.onStart,
    required this.onUpdate,
    required this.onEnd,
    required this.child,
  });

  final ValueListenable<double> drag;
  final GestureDragStartCallback onStart;
  final GestureDragUpdateCallback onUpdate;
  final GestureDragEndCallback onEnd;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Translucent, so the areas of a tab that are not painted (the gaps
      // between rows) still start a swipe.
      behavior: HitTestBehavior.translucent,
      onHorizontalDragStart: onStart,
      onHorizontalDragUpdate: onUpdate,
      onHorizontalDragEnd: onEnd,
      child: ValueListenableBuilder<double>(
        valueListenable: drag,
        builder: (context, dx, inner) => Transform.translate(
          offset: Offset(dx, 0),
          child: inner,
        ),
        child: child,
      ),
    );
  }
}

/// Slides content horizontally when the tab changes, synced with tab movement.
///
/// The new screen enters from the direction of travel: right for a forward
/// tap, left for a backward tap. Skipped under reduced motion.
class _ScreenSlide extends StatelessWidget {
  const _ScreenSlide({
    required this.controller,
    required this.direction,
    required this.child,
  });

  final AnimationController controller;
  final int direction;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (ElaraMotion.reduceMotion(context)) return child;

    final offset = CurvedAnimation(
      parent: controller,
      curve: ElaraMotion.curve,
    );

    return SlideTransition(
      position: Tween<Offset>(
        begin: Offset(direction * 0.3, 0),
        end: Offset.zero,
      ).animate(offset),
      child: child,
    );
  }
}

/// Bottom navigation bar with a traveling indicator and directional fill.
///
/// Selected tab icon/label: phase colour. Unselected: secondary ink.
/// A rounded-rect fill glides beneath the selected tab, stretching toward the
/// direction of travel so the movement reads as a glide. Each icon scales
/// briefly on press (tactile feedback, skipped under reduced motion).
class _Bar extends StatelessWidget {
  const _Bar({
    required this.index,
    required this.previousIndex,
    required this.controller,
    required this.direction,
    required this.onSelected,
  });

  final int index;
  final int previousIndex;
  final AnimationController controller;
  final int direction;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final width = MediaQuery.sizeOf(context).width;
    final tabCount = _RootScaffoldState._destinations.length;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: tokens.divider)),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            NavigationBar(
              selectedIndex: index,
              onDestinationSelected: onSelected,
              backgroundColor: tokens.bgCard,
              surfaceTintColor: tokens.transparent,
              elevation: 0,
              indicatorColor: tokens.transparent,
              height: ElaraSpacing.navigationBarHeight,
              labelTextStyle: WidgetStateProperty.resolveWith(
                (states) => _labelStyle(tokens, states),
              ),
              destinations: [
                for (var i = 0; i < tabCount; i++)
                NavigationDestination(
                  icon: _NavIcon(
                    i: i,
                    isSelected: i == index,
                    tokens: tokens,
                  ),
                  label: _RootScaffoldState._destinations[i].label,
                ),
              ],
            ),

            // Traveling fill beneath the NavigationBar: glides from the
            // previous tab's position to the new one, stretching toward the
            // direction of travel.
            _TravelingFill(
              index: index,
              previousIndex: previousIndex,
              controller: controller,
              width: width,
              tabCount: tabCount,
              direction: direction,
              tokens: tokens,
            ),
          ],
        ),
      ),
    );
  }

  static TextStyle? _labelStyle(ElaraTokens tokens,
      Set<WidgetState> states) {
    final selected = states.contains(WidgetState.selected);
    return TextStyle(
      fontFamily: 'Hind Siliguri',
      fontWeight: FontWeight.w400,
      fontSize: 12,
      height: 1.3,
      color: selected ? tokens.accentText : tokens.textSecondaryStrong,
    );
  }

}

/// One tap target in the traveling bar: icon with phase colour and press
/// feedback.
class _NavIcon extends StatefulWidget {
  const _NavIcon({
    required this.i,
    required this.isSelected,
    required this.tokens,
  });

  final int i;
  final bool isSelected;
  final ElaraTokens tokens;

  @override
  State<_NavIcon> createState() => _NavIconState();
}

class _NavIconState extends State<_NavIcon> {
  bool _down = false;

  void _set(bool value) {
    if (_down == value) return;
    setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    final reduced = ElaraMotion.reduceMotion(context);
    final colour = widget.isSelected ? widget.tokens.accentText : widget.tokens.textSecondaryStrong;
    final iconData = widget.isSelected
        ? _RootScaffoldState._destinations[widget.i].selected
        : _RootScaffoldState._destinations[widget.i].icon;

    return GestureDetector(
      onTapDown: reduced ? null : (_) => _set(true),
      onTapUp: reduced ? null : (_) => _set(false),
      onTapCancel: reduced ? null : () => _set(false),
      child: AnimatedScale(
        scale: reduced
            ? 1.0
            : (_down || widget.isSelected ? 0.94 : 1.0),
        duration: ElaraMotion.press,
        curve: ElaraMotion.curve,
        child: Icon(iconData, size: 22, color: colour),
      ),
    );
  }
}

/// The traveling fill: a rounded rect beneath the selected tab.
///
/// Its left edge glides from the previous tab's position to the current one.
/// While animating, it stretches toward the direction of travel so the fill
/// reads as gliding forward or back rather than teleporting.
///
/// Rebuilds on every tick of [controller] so the position and width animate
/// smoothly rather than snapping between frames.
class _TravelingFill extends StatelessWidget {
  const _TravelingFill({
    required this.index,
    required this.previousIndex,
    required this.controller,
    required this.width,
    required this.tabCount,
    required this.direction,
    required this.tokens,
  });

  final int index;
  final int previousIndex;
  final AnimationController controller;
  final double width;
  final int tabCount;
  final int direction;
  final ElaraTokens tokens;

  @override
  Widget build(BuildContext context) {
    final phaseKey = _phaseKeyForTab(index);
    final fill = tokens.phaseFill(phaseKey);

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final t = CurvedAnimation(
          parent: controller,
          curve: ElaraMotion.curve,
        ).value;

        final geometry = NavFillGeometry.resolve(
          index: index,
          previousIndex: previousIndex,
          tabCount: tabCount,
          pageWidth: width,
          t: t,
        );

        return Positioned(
          left: geometry.left,
          bottom: 4,
          child: AnimatedContainer(
            duration: ElaraMotion.medium,
            curve: ElaraMotion.curve,
            width: geometry.width,
            height: 6,
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        );
      },
    );
  }

  String _phaseKeyForTab(int i) {
    const keys = ['ovulatory', 'follicular', 'luteal', 'menstrual'];
    return keys[i % keys.length];
  }
}

/// Where the traveling fill is at a point in the animation.
///
/// This was three tweens inside the widget, and it was wrong in a way that only
/// showed up when the reader moved *left*: the width was computed as
/// `to - from`, which is negative when the destination tab sits left of the
/// current one, so the bar asked for a negative width and Flutter threw
/// "BoxConstraints has a negative minimum width" while the tab change was in
/// flight. Moving right worked, which is why it survived — the first four tabs
/// are reached left-to-right.
///
/// It also rested 12% wider than its tab, because the stretch tween ended at
/// the stretched value. The stretch now follows a bell: zero at both ends, one
/// in the middle, so the bar is exactly one tab wide when it is standing still
/// and swells only while it travels, in either direction.
class NavFillGeometry {
  const NavFillGeometry({required this.left, required this.width});

  final double left;
  final double width;

  /// How far the bar swells at mid-flight, as a fraction of a tab.
  static const double stretchFraction = 0.12;

  static NavFillGeometry resolve({
    required int index,
    required int previousIndex,
    required int tabCount,
    required double pageWidth,
    required double t,
  }) {
    final tabWidth = pageWidth / tabCount;
    final from = previousIndex * tabWidth;
    final to = index * tabWidth;

    // Sine of pi * t: 0 at rest, 1 at the midpoint, 0 at the end.
    final bell = math.sin(math.pi * t.clamp(0.0, 1.0));
    final stretch = tabWidth * stretchFraction * bell;

    final left = from + (to - from) * t;
    return NavFillGeometry(
      left: left - stretch / 2,
      width: tabWidth + stretch,
    );
  }
}

/// The rail for wide windows: same destinations, vertical layout.
///
/// The rail's selected indicator uses the phase colour.
class _Rail extends StatelessWidget {
  const _Rail({
    required this.index,
    required this.onSelected,
  });

  final int index;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: tokens.divider)),
      ),
      child: NavigationRail(
        selectedIndex: index,
        onDestinationSelected: onSelected,
        backgroundColor: tokens.bgCard,
        indicatorColor: tokens.transparent,
        labelType: NavigationRailLabelType.all,
        destinations: [
          for (var i = 0;
              i < _RootScaffoldState._destinations.length;
              i++)
          NavigationRailDestination(
            icon: Icon(
              _RootScaffoldState._destinations[i].icon,
              color: i == index ? tokens.accentText : tokens.textSecondaryStrong,
            ),
            selectedIcon: Icon(
              _RootScaffoldState._destinations[i].selected,
              color: tokens.accentText,
            ),
            label: Text(
              _RootScaffoldState._destinations[i].label,
              style: TextStyle(
                fontFamily: 'Hind Siliguri',
                fontWeight: FontWeight.w500,
                fontSize: 13,
                color: i == index ? tokens.textPrimary : tokens.textSecondaryStrong,
              ),
            ),
          ),
        ],
      ),
    );
  }
}