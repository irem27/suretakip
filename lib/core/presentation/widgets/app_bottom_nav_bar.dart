import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:suretakip/app/router/app_routes.dart';

/// Alt navigasyondaki ana bölümler. Sıra ekrandaki sıradır.
enum AppSection {
  dashboard(
    label: 'Ana Sayfa',
    icon: Icons.home_outlined,
    selectedIcon: Icons.home_rounded,
    routeName: AppRouteNames.dashboard,
  ),
  sessions(
    label: 'İşlemler',
    icon: Icons.receipt_long_outlined,
    selectedIcon: Icons.receipt_long_rounded,
    routeName: AppRouteNames.sessions,
  ),
  customers(
    label: 'Müşteriler',
    icon: Icons.people_outline_rounded,
    selectedIcon: Icons.people_rounded,
    routeName: AppRouteNames.customers,
  ),
  definitions(
    label: 'Tanımlar',
    icon: Icons.settings_outlined,
    selectedIcon: Icons.settings_rounded,
    routeName: AppRouteNames.definitions,
  ),
  reports(
    label: 'Raporlar',
    icon: Icons.bar_chart_outlined,
    selectedIcon: Icons.bar_chart_rounded,
    routeName: AppRouteNames.reports,
  );

  const AppSection({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.routeName,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String routeName;
}

/// Ana bölümler arasında geçiş yapan alt navigasyon çubuğu.
///
/// Geçişler `goNamed` ile yapılır: sekmeler arasında gidip gelirken yığın
/// büyümez, dolayısıyla geri tuşu beklenmedik şekilde derinleşmez.
class AppBottomNavBar extends StatelessWidget {
  const AppBottomNavBar({required this.current, super.key});

  final AppSection current;

  @override
  Widget build(BuildContext context) => NavigationBar(
    selectedIndex: current.index,
    onDestinationSelected: (index) {
      final target = AppSection.values[index];
      if (target == current) return;
      context.goNamed(target.routeName);
    },
    destinations: [
      for (final section in AppSection.values)
        NavigationDestination(
          icon: Icon(section.icon),
          selectedIcon: Icon(section.selectedIcon),
          label: section.label,
          tooltip: section.label,
        ),
    ],
  );
}
