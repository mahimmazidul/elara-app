import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../providers/update_provider.dart';
import '../theme/elara_theme.dart';
import '../theme/elara_motion.dart';
import '../widgets/icons.dart';
import '../widgets/primitives.dart';
import '../widgets/status_bar_scrim.dart';
import 'calendar/calendar_screen.dart';
import 'insights/insights_screen.dart';
import 'settings/settings_screen.dart';
import 'today/log_sheet.dart';
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
/// Phones get the floating bottom bar in [ElaraNavBar]: four tabs and a raised
/// centre action that opens the log sheet, so recording something is one tap
/// from anywhere. Wide windows keep the rail, which carries the same action as
/// its leading item.
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
      label: 'Calendar',
    ),
    (
      icon: Icons.insights_outlined,
      selected: Icons.insights,
      label: 'Insights',
    ),
    (
      icon: Icons.settings_outlined,
      selected: Icons.settings,
      label: 'Settings',
    ),
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
      // No SafeArea: the pages carry the status-bar inset themselves, so their
      // lists run to the top edge of the display and scroll up under the clock
      // the way a mail list does. The scrim keeps the icons legible without
      // putting content back in a box.
      body: Stack(
        // Explicitly expand: a Stack that holds only positioned children takes
        // the smallest size its constraints allow, and a zero-height body
        // renders nothing at all — which the widget tests caught immediately.
        fit: StackFit.expand,
        children: [
          isWide
              ? Row(
                  children: [
                    _Rail(
                      index: _index,
                      onSelected: _selectTab,
                      onLog: () => showLogSheet(context),
                    ),
                    Expanded(child: content),
                  ],
                )
              : content,
          const ElaraStatusBarScrim(),
        ],
      ),
      bottomNavigationBar: isWide
          ? null
          : ElaraNavBar(
              selectedIndex: _index,
              onSelected: _selectTab,
              onLog: () => showLogSheet(context),
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
        builder: (context, dx, inner) =>
            Transform.translate(offset: Offset(dx, 0), child: inner),
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

/// The bottom bar: a floating card, four tabs, and a raised centre action.
///
/// It used to be a full-width [NavigationBar] welded to the bottom edge with a
/// hairline across the top. Two things were wrong with that. It read as the
/// floor the app was standing on rather than as a control surface, so Today -
/// the screen the app is actually about - looked like it was inside a frame. And
/// it could not record anything: the one thing this app exists for was two taps
/// away, behind a button in the calendar header, on a tab you had to know to
/// visit.
///
/// The reference was taka's home screen, where the bar floats clear of the bottom
/// edge as a rounded card with the primary action raised at its centre. The idea
/// worth taking is the separation, not the colour: the card is the page's own
/// white, the action is ink rather than a fifth hue, and the phase colour stays
/// where it means something - the hero panel and the selected tab's wash.
class ElaraNavBar extends StatelessWidget {
  const ElaraNavBar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    required this.onLog,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  /// Opens the log sheet: the centre action, offered from every tab.
  final VoidCallback onLog;

  /// Minimum height of the card.
  ///
  /// A minimum rather than a height: at 2.0x text the label under each icon is
  /// taller than at 1.0x, and a fixed height clipped it in the text-scale sweep.
  static const double barHeight = 64;

  /// The raised action's diameter, and how far it rises above the card.
  static const double addButtonSize = 56;
  static const double addButtonRise = 20;

  /// The floating card itself, for tests and for anything that needs to measure
  /// what the reader sees. [ElaraNavBar] spans the width of the screen; the card
  /// inside it is the object that floats.
  static const Key cardKey = Key('elara-nav-card');

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Padding(
      // Clear of the bottom edge, and inset at the sides, so the page shows all
      // the way round the card. That is the whole difference between a bar that
      // floats and a bar that sits.
      // sm, not md, at the sides: at 320dp the four labels and the action have
      // 304 pixels between them, and "Calendar" needs every one it can get.
      padding: EdgeInsets.fromLTRB(
        ElaraSpacing.sm,
        addButtonRise,
        ElaraSpacing.sm,
        bottomInset + ElaraSpacing.sm,
      ),
      child: Stack(
        // The action deliberately paints above the card's top edge.
        clipBehavior: Clip.none,
        children: [
          Container(
            key: cardKey,
            constraints: const BoxConstraints(minHeight: barHeight),
            decoration: BoxDecoration(
              color: tokens.bgCard,
              borderRadius: BorderRadius.circular(ElaraRadii.card + 10),
              border: Border.all(color: tokens.divider),
              boxShadow: Theme.of(context).brightness == Brightness.dark
                  ? ElaraShadows.glassDark
                  : ElaraShadows.glass,
            ),
            child: Row(
              children: [
                _slot(0),
                _slot(1),
                // The action's own column. A gap in the row rather than an
                // overlay, so the two labels either side stay evenly spaced and
                // no tab is half-covered by the button.
                const SizedBox(width: addButtonSize),
                _slot(2),
                _slot(3),
              ],
            ),
          ),
          Positioned(
            top: -addButtonRise,
            left: 0,
            right: 0,
            child: Center(child: _CentreAction(tokens: tokens, onTap: onLog)),
          ),
        ],
      ),
    );
  }

  Widget _slot(int i) => Expanded(
    child: _NavSlot(
      i: i,
      isSelected: i == selectedIndex,
      onTap: () => onSelected(i),
    ),
  );
}

/// The raised action at the centre of the bar.
///
/// Ink on the card's own white, rather than the day's phase colour: the bar
/// already carries the phase in its selected tab, and a second loud hue two
/// centimetres lower would compete with the hero panel for the eye. An ink disc
/// also cannot fall out of contrast as the phase changes.
class _CentreAction extends StatelessWidget {
  const _CentreAction({
    required this.tokens,
    required this.onTap,
    this.size = ElaraNavBar.addButtonSize,
  });

  final ElaraTokens tokens;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Log',
      child: Tooltip(
        message: 'Log',
        child: Material(
          color: tokens.textPrimary,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: size,
              height: size,
              child: Icon(
                ElaraIcons.plus,
                size: size * 0.46,
                color: tokens.bgCard,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One label-plus-icon in the bar.
class _NavSlot extends StatelessWidget {
  const _NavSlot({
    required this.i,
    required this.isSelected,
    required this.onTap,
  });

  final int i;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    final type = context.type;
    final label = _RootScaffoldState._destinations[i].label;

    // One node per tab, named by the tab: button, name, selected state. The
    // label is set here and the subtree excluded, so a screen reader says
    // "Calendar, selected, button" once instead of reading the icon and the
    // label as two separate things. It is also what the device capture asserts
    // on, since the "Tab 2 of 4" descriptor a NavigationBar used to add is gone.
    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _NavIcon(i: i, isSelected: isSelected, tokens: tokens),
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 0, 2, 6),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: type.caption(
                  isSelected ? tokens.textPrimary : tokens.textSecondaryStrong,
                ),
              ),
            ),
          ],
        ),
      ),
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
    final selected = widget.isSelected;
    // The selected destination wears a filled tile behind its icon, the way a
    // system mail app does, because a tinted glyph alone is easy to miss on a
    // page that is nearly the same colour as the bar. The fill is a wash of the
    // theme accent, which is the day's phase, so the bar and the panel agree.
    final colour = selected
        ? widget.tokens.textPrimary
        : widget.tokens.textSecondaryStrong;
    final iconData = selected
        ? _RootScaffoldState._destinations[widget.i].selected
        : _RootScaffoldState._destinations[widget.i].icon;

    return GestureDetector(
      onTapDown: reduced ? null : (_) => _set(true),
      onTapUp: reduced ? null : (_) => _set(false),
      onTapCancel: reduced ? null : () => _set(false),
      child: AnimatedScale(
        scale: reduced ? 1.0 : (_down || selected ? 0.94 : 1.0),
        duration: ElaraMotion.press,
        curve: ElaraMotion.curve,
        child: AnimatedContainer(
          duration: ElaraMotion.medium,
          curve: ElaraMotion.curve,
          width: 52,
          height: 30,
          decoration: BoxDecoration(
            color: selected
                ? widget.tokens.accent.withValues(alpha: 0.22)
                : widget.tokens.transparent,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(iconData, size: 22, color: colour),
        ),
      ),
    );
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
    return NavFillGeometry(left: left - stretch / 2, width: tabWidth + stretch);
  }
}

/// The rail for wide windows: same destinations, vertical layout.
///
/// The rail's selected indicator uses the phase colour.
class _Rail extends StatelessWidget {
  const _Rail({
    required this.index,
    required this.onSelected,
    required this.onLog,
  });

  final int index;
  final ValueChanged<int> onSelected;
  final VoidCallback onLog;

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
        // The same action the phone bar carries at its centre. Without it the
        // one thing the app exists for would disappear on a tablet, which is
        // where a long history is easiest to read and therefore most likely to be
        // corrected.
        leading: Padding(
          padding: const EdgeInsets.only(
            top: ElaraSpacing.md,
            bottom: ElaraSpacing.lg,
          ),
          child: _CentreAction(tokens: tokens, onTap: onLog, size: 48),
        ),
        destinations: [
          for (var i = 0; i < _RootScaffoldState._destinations.length; i++)
            NavigationRailDestination(
              icon: Icon(
                _RootScaffoldState._destinations[i].icon,
                color: i == index
                    ? tokens.accentText
                    : tokens.textSecondaryStrong,
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
                  color: i == index
                      ? tokens.textPrimary
                      : tokens.textSecondaryStrong,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
