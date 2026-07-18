import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:suretakip/app/router/app_routes.dart';

class DefinitionsMenuPage extends StatelessWidget {
  const DefinitionsMenuPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Tanımlar')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'İşletmenizde kullandığınız hizmet, ürün ve müşteri kayıtlarını yönetin.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          _DefinitionCard(
            icon: Icons.design_services_outlined,
            title: 'Hizmetler',
            description: 'Hizmet türlerini ve dakika fiyatlarını belirleyin.',
            onTap: () => context.pushNamed(AppRouteNames.services),
          ),
          const SizedBox(height: 12),
          _DefinitionCard(
            icon: Icons.inventory_2_outlined,
            title: 'Ürünler',
            description: 'Satış ürünlerini, fiyatlarını ve stoklarını yönetin.',
            onTap: () => context.pushNamed(AppRouteNames.products),
          ),
          const SizedBox(height: 12),
          _DefinitionCard(
            icon: Icons.people_outline_rounded,
            title: 'Müşteriler',
            description: 'Müşteri iletişim bilgilerini ve durumlarını yönetin.',
            onTap: () => context.pushNamed(AppRouteNames.customers),
          ),
        ],
      ),
    ),
  );
}

class _DefinitionCard extends StatelessWidget {
  const _DefinitionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                color: Theme.of(context).colorScheme.primary,
                size: 30,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(description),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    ),
  );
}
