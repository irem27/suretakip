import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:suretakip/app/router/app_routes.dart';
import 'package:suretakip/core/presentation/widgets/app_error_state.dart';
import 'package:suretakip/features/services/domain/entities/service.dart';
import 'package:suretakip/features/services/presentation/controllers/services_controllers.dart';
import 'package:suretakip/features/services/presentation/utils/service_presentation_utils.dart';
import 'package:suretakip/features/services/presentation/widgets/service_card.dart';

class ServicesListPage extends ConsumerStatefulWidget {
  const ServicesListPage({super.key});

  @override
  ConsumerState<ServicesListPage> createState() => _ServicesListPageState();
}

class _ServicesListPageState extends ConsumerState<ServicesListPage> {
  final _searchController = TextEditingController();
  var _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _toggle(Service service, bool isActive) async {
    await ref
        .read(serviceFormControllerProvider.notifier)
        .setActive(service.id, isActive: isActive);
  }

  @override
  Widget build(BuildContext context) {
    final listState = ref.watch(servicesListControllerProvider);
    final formState = ref.watch(serviceFormControllerProvider);
    ref.listen(serviceFormControllerProvider, (_, next) {
      if (!next.hasError) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            serviceErrorMessage(
              next.error,
              'Hizmet durumu değiştirilemedi. Lütfen tekrar deneyin.',
            ),
          ),
        ),
      );
    });

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.go(AppRoutes.dashboard),
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Ana sayfaya dön',
        ),
        title: const Text('Hizmetler'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.pushNamed(AppRouteNames.serviceCreate),
        backgroundColor: Theme.of(context).colorScheme.secondary,
        foregroundColor: Theme.of(context).colorScheme.onSecondary,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Yeni Hizmet'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () =>
              ref.read(servicesListControllerProvider.notifier).refresh(),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: _ListHeader(
                  searchController: _searchController,
                  queryChanged: (value) => setState(() => _query = value),
                  state: listState.valueOrNull,
                  onFilterChanged: (filter) => ref
                      .read(servicesListControllerProvider.notifier)
                      .setFilter(filter),
                ),
              ),
              ...listState.when(
                loading: () => const [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: CircularProgressIndicator.adaptive()),
                  ),
                ],
                error: (error, _) => [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: AppErrorState(
                      error: error,
                      fallbackMessage: serviceErrorMessage(
                        error,
                        'Hizmetler yüklenemedi. Lütfen tekrar deneyin.',
                      ),
                      onRetry: () => ref
                          .read(servicesListControllerProvider.notifier)
                          .refresh(),
                      padding: const EdgeInsets.all(32),
                      iconSize: 52,
                    ),
                  ),
                ],
                data: (state) {
                  final normalized = _query.trim().toLowerCase();
                  final services = state.visibleServices
                      .where(
                        (service) =>
                            service.name.toLowerCase().contains(normalized),
                      )
                      .toList(growable: false);
                  if (services.isEmpty) {
                    return const [
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _EmptyState(),
                      ),
                    ];
                  }
                  return [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 104),
                      sliver: SliverList.separated(
                        itemCount: services.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final service = services[index];
                          return ServiceCard(
                            service: service,
                            isUpdating: formState.isLoading,
                            onTap: () => context.pushNamed(
                              AppRouteNames.serviceDetail,
                              pathParameters: {'serviceId': service.id},
                            ),
                            onStatusChanged: (value) => _toggle(service, value),
                          );
                        },
                      ),
                    ),
                  ];
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ListHeader extends StatelessWidget {
  const _ListHeader({
    required this.searchController,
    required this.queryChanged,
    required this.state,
    required this.onFilterChanged,
  });

  final TextEditingController searchController;
  final ValueChanged<String> queryChanged;
  final ServicesListState? state;
  final ValueChanged<ServiceStatusFilter> onFilterChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Dakika bazında ücretlendirdiğiniz hizmetleri yönetin.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: searchController,
          onChanged: queryChanged,
          decoration: const InputDecoration(
            hintText: 'Hizmet ara',
            prefixIcon: Icon(Icons.search_rounded),
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          children: ServiceStatusFilter.values
              .map(
                (filter) => ChoiceChip(
                  label: Text(_filterLabel(filter)),
                  selected:
                      (state?.filter ?? ServiceStatusFilter.all) == filter,
                  onSelected: (_) => onFilterChanged(filter),
                ),
              )
              .toList(growable: false),
        ),
      ],
    ),
  );

  String _filterLabel(ServiceStatusFilter filter) => switch (filter) {
    ServiceStatusFilter.all => 'Tümü',
    ServiceStatusFilter.active => 'Aktif',
    ServiceStatusFilter.inactive => 'Pasif',
  };
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.design_services_outlined,
            size: 56,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'Eşleşen hizmet bulunamadı. Aramayı değiştirin veya Yeni Hizmet düğmesiyle kayıt ekleyin.',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'Filtreyi değiştirin veya yeni bir hizmet ekleyin.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}
