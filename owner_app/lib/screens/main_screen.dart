// lib/screens/main_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/owner_providers.dart';
import '../utils/app_theme.dart';
import 'dashboard/dashboard_screen.dart';
import 'networks/networks_screen.dart';
import 'inventory/inventory_screen.dart';
import 'sales/sales_screen.dart';

class MainScreen extends ConsumerWidget {
  const MainScreen({super.key});

  final List<Widget> _screens = const [
    DashboardScreen(),
    NetworksScreen(),
    InventoryScreen(),
    SalesScreen(),
  ];

  final List<BottomNavigationBarItem> _navItems = const [
    BottomNavigationBarItem(
      icon: Icon(Icons.dashboard_outlined),
      label: 'الرئيسية',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.wifi_rounded),
      label: 'شبكاتي',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.inventory_2_outlined),
      label: 'المخزون',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.point_of_sale_outlined),
      label: 'المبيعات',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedTab = ref.watch(selectedTabProvider);

    return Scaffold(
      body: IndexedStack(
        index: selectedTab,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectedTab,
        onTap: (index) => ref.read(selectedTabProvider.notifier).state = index,
        items: _navItems,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppTheme.primary,
        unselectedItemColor: AppTheme.textMuted,
        backgroundColor: AppTheme.surface,
        elevation: 8,
      ),
    );
  }
}
