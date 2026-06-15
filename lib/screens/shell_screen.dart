import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'dashboard_screen.dart';
import 'plans_screen.dart';
import 'subscribers_screen.dart';
import 'settings_screen.dart';

class ShellScreen extends StatefulWidget {
  final ApiService apiService;
  final String useCase;
  final VoidCallback onLogout;

  const ShellScreen({
    super.key,
    required this.apiService,
    required this.useCase,
    required this.onLogout,
  });

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final isSales = widget.useCase == 'sales';
    final tabs = isSales
        ? const [
            _TabItem('Dashboard', Icons.dashboard),
            _TabItem('Products', Icons.inventory),
            _TabItem('Sales', Icons.receipt_long),
            _TabItem('Settings', Icons.settings),
          ]
        : const [
            _TabItem('Dashboard', Icons.dashboard),
            _TabItem('Plans', Icons.subscriptions),
            _TabItem('Subscribers', Icons.people),
            _TabItem('Settings', Icons.settings),
          ];

    final pages = <Widget>[
      DashboardScreen(
        apiService: widget.apiService,
        useCase: widget.useCase,
      ),
      PlansScreen(apiService: widget.apiService, isSales: isSales),
      SubscribersScreen(apiService: widget.apiService, isSales: isSales),
      SettingsScreen(
        apiService: widget.apiService,
        useCase: widget.useCase,
        onLogout: widget.onLogout,
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: tabs
            .map((t) => NavigationDestination(icon: Icon(t.icon), label: t.label))
            .toList(),
      ),
    );
  }
}

class _TabItem {
  final String label;
  final IconData icon;
  const _TabItem(this.label, this.icon);
}
