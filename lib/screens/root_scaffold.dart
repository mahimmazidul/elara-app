import 'package:flutter/material.dart';

import '../theme/elara_theme.dart';
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
class RootScaffold extends StatefulWidget {
  const RootScaffold({super.key});

  /// Above this width the rail replaces the bottom bar.
  static const double railBreakpoint = 720;

  @override
  State<RootScaffold> createState() => _RootScaffoldState();
}

class _RootScaffoldState extends State<RootScaffold> {
  int _index = 0;

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
      child: IndexedStack(index: _index, children: _tabs),
    );

    return Scaffold(
      backgroundColor: tokens.bgPrimary,
      body: SafeArea(
        bottom: !isWide,
        child: isWide
            ? Row(
                children: [
                  _Rail(
                    index: _index,
                    onSelected: (value) => setState(() => _index = value),
                  ),
                  Expanded(child: content),
                ],
              )
            : content,
      ),
      bottomNavigationBar: isWide ? null : _Bar(
        index: _index,
        onSelected: (value) => setState(() => _index = value),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.index, required this.onSelected});

  final int index;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    return DecoratedBox(
      // A hairline instead of elevation, to stay within the one-shadow rule.
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: tokens.divider)),
      ),
      child: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: onSelected,
        backgroundColor: tokens.bgCard,
        surfaceTintColor: tokens.transparent,
        elevation: 0,
        indicatorColor: tokens.moonGlow,
        destinations: [
          for (final destination in _RootScaffoldState._destinations)
            NavigationDestination(
              icon: Icon(destination.icon),
              selectedIcon: Icon(destination.selected),
              label: destination.label,
            ),
        ],
      ),
    );
  }
}

class _Rail extends StatelessWidget {
  const _Rail({required this.index, required this.onSelected});

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
        indicatorColor: tokens.moonGlow,
        labelType: NavigationRailLabelType.all,
        destinations: [
          for (final destination in _RootScaffoldState._destinations)
            NavigationRailDestination(
              icon: Icon(destination.icon),
              selectedIcon: Icon(destination.selected),
              label: Text(destination.label),
            ),
        ],
      ),
    );
  }
}
