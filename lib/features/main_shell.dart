import 'package:flutter/material.dart';

import 'planning/planning_screens.dart';
import 'profile/profile_screen.dart';
import 'workout/workout_screens.dart';

class MainShell extends StatefulWidget {
  const MainShell({
    required this.themeMode,
    required this.onThemeChanged,
    super.key,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeChanged;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      const DayScreen(),
      const WeekScreen(),
      const CalendarScreen(),
      const WorkoutsListScreen(),
      ProfileScreen(
        themeMode: widget.themeMode,
        onThemeChanged: widget.onThemeChanged,
      ),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('LifePlanner')),
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.today), label: 'Giorno'),
          NavigationDestination(
            icon: Icon(Icons.view_week),
            label: 'Settimana',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month),
            label: 'Mese',
          ),
          NavigationDestination(
            icon: Icon(Icons.fitness_center),
            label: 'Workout',
          ),
          NavigationDestination(icon: Icon(Icons.person), label: 'Profilo'),
        ],
      ),
    );
  }
}
