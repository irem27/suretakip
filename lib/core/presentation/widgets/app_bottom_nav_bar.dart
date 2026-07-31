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
/// Ana Sayfa ortada dairesel/yükseltilmiş bir buton olarak durur; diğer dört
/// bölüm ikişerli olarak iki yana yerleşir. Geçişler `goNamed` ile yapılır:
/// sekmeler arasında gidip gelirken yığın büyümez.
class AppBottomNavBar extends StatelessWidget {
  const AppBottomNavBar({required this.current, super.key});

  final AppSection current;

  // Görsel düzen: sol iki bölüm, ortada Ana Sayfa, sağ iki bölüm.
  static const _left = [AppSection.sessions, AppSection.customers];
  static const _right = [AppSection.definitions, AppSection.reports];

  void _go(BuildContext context, AppSection target) {
    if (target == current) return;
    context.goNamed(target.routeName);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: SizedBox(
        height: 76,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            for (final section in _left)
              Expanded(
                child: _NavItem(section: section, current: current, onTap: _go),
              ),
            _HomeButton(
              isCurrent: current == AppSection.dashboard,
              colors: colors,
              onTap: () => _go(context, AppSection.dashboard),
            ),
            for (final section in _right)
              Expanded(
                child: _NavItem(section: section, current: current, onTap: _go),
              ),
          ],
        ),
      ),
    );
  }
}

/// Yan bölümler için ikon + etiketli standart öğe.
class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.section,
    required this.current,
    required this.onTap,
  });

  final AppSection section;
  final AppSection current;
  final void Function(BuildContext, AppSection) onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final selected = section == current;
    final color = selected ? colors.primary : colors.onSurfaceVariant;
    return InkResponse(
      onTap: () => onTap(context, section),
      radius: 36,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        // Büyük metin ölçeğinde (ör. 2.0x) sabit yükseklikte taşmayı önler.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selected ? section.selectedIcon : section.icon,
                color: color,
              ),
              const SizedBox(height: 4),
              Text(
                section.label,
                maxLines: 1,
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ortadaki dairesel, yükseltilmiş Ana Sayfa butonu.
class _HomeButton extends StatelessWidget {
  const _HomeButton({
    required this.isCurrent,
    required this.colors,
    required this.onTap,
  });

  final bool isCurrent;
  final ColorScheme colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Semantics(
        button: true,
        label: 'Ana Sayfa',
        selected: isCurrent,
        child: Material(
          color: colors.primary,
          shape: const CircleBorder(),
          elevation: isCurrent ? 6 : 3,
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: 60,
              height: 60,
              child: Icon(
                Icons.home_rounded,
                color: colors.onPrimary,
                size: 30,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
