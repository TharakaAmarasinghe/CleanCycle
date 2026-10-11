import 'package:flutter/material.dart';

import '../centers/recycling_centres_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../profile/profile_screen.dart';
import '../report/my_reports_screen.dart';

/// The household's top-level navigation. IndexedStack keeps each tab
/// alive, so switching tabs doesn't reload it or lose scroll position.
class HouseholdShell extends StatefulWidget {
  const HouseholdShell({super.key});

  @override
  State<HouseholdShell> createState() => _HouseholdShellState();
}

class _HouseholdShellState extends State<HouseholdShell> {
  int _index = 0;
  final Set<int> _visited = {0};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          const DashboardScreen(),
          const MyReportsScreen(),
          // Built on first visit only: this tab asks for location, and a
          // permission should be requested where it is needed, not at launch.
          _visited.contains(2) ? const RecyclingCentresScreen() : const SizedBox.shrink(),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() {
          _index = i;
          _visited.add(i);
        }),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment),
            label: 'Reports',
          ),
          NavigationDestination(
            icon: Icon(Icons.recycling_outlined),
            selectedIcon: Icon(Icons.recycling),
            label: 'Centres',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}