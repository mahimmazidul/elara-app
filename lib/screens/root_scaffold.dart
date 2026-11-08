import 'package:flutter/material.dart';

import '../theme/elara_theme.dart';
import 'calendar/calendar_screen.dart';
import 'insights/insights_screen.dart';
import 'settings/settings_screen.dart';
import 'today/today_screen.dart';

/// The app shell: four tabs over an [IndexedStack].
///
/// IndexedStack rather than swapping children, so each tab keeps its scroll
/// position and the calendar keeps its visible month when the user moves away.
class RootScaffold extends StatefulWidget {
  const RootScaffold({super.key});

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

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;

    return Scaffold(
      backgroundColor: tokens.bgPrimary,
      body: SafeArea(
        bottom: false,
        child: IndexedStack(index: _index, children: _tabs),
      ),
      bottomNavigationBar: DecoratedBox(
        // A hairline instead of elevation, to stay within the one-shadow rule.
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: tokens.divider)),
        ),
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (value) => setState(() => _index = value),
          backgroundColor: tokens.bgCard,
          surfaceTintColor: tokens.transparent,
          elevation: 0,
          indicatorColor: tokens.moonGlow,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.today_outlined),
              selectedIcon: Icon(Icons.today),
              label: 'Today',
            ),
            NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined),
              selectedIcon: Icon(Icons.calendar_month),
              label: 'Calendar',
            ),
            NavigationDestination(
              icon: Icon(Icons.insights_outlined),
              selectedIcon: Icon(Icons.insights),
              label: 'Insights',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}
