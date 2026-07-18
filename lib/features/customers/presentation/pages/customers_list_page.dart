import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:suretakip/app/router/app_routes.dart';
import 'package:suretakip/core/presentation/widgets/app_error_state.dart';
import 'package:suretakip/features/customers/domain/entities/customer.dart';
import 'package:suretakip/features/customers/presentation/controllers/customers_controllers.dart';
import 'package:suretakip/features/customers/presentation/utils/customer_presentation_utils.dart';
import 'package:suretakip/features/customers/presentation/widgets/customer_status_chip.dart';

class CustomersListPage extends ConsumerStatefulWidget {
  const CustomersListPage({super.key});

  @override
  ConsumerState<CustomersListPage> createState() => _CustomersListPageState();
}

class _CustomersListPageState extends ConsumerState<CustomersListPage> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final listState = ref.watch(customersListControllerProvider);
    final formState = ref.watch(customerFormControllerProvider);
    ref.listen(customerFormControllerProvider, (_, next) {
      if (!next.hasError) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            customerErrorMessage(
              next.error,
              'Müşteri durumu değiştirilemedi. Lütfen tekrar deneyin.',
            ),
          ),
        ),
      );
    });
    return Scaffold(
      appBar: AppBar(title: const Text('Müşteriler')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.pushNamed(AppRouteNames.customerCreate),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Yeni Müşteri'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () =>
              ref.read(customersListControllerProvider.notifier).refresh(),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                  child: TextField(
                    controller: _searchController,
                    onChanged: ref
                        .read(customersListControllerProvider.notifier)
                        .setQuery,
                    decoration: const InputDecoration(
                      hintText: 'Müşteri adı, telefon veya e-posta ara',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
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
                      fallbackMessage: customerErrorMessage(
                        error,
                        'Müşteriler yüklenemedi. Lütfen tekrar deneyin.',
                      ),
                      onRetry: () => ref
                          .read(customersListControllerProvider.notifier)
                          .refresh(),
                      padding: const EdgeInsets.all(32),
                      iconSize: 52,
                    ),
                  ),
                ],
                data: (state) {
                  if (state.visibleCustomers.isEmpty) {
                    return const [
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _MessageState(
                          message:
                              'Eşleşen müşteri bulunamadı. Aramayı değiştirin veya Yeni Müşteri düğmesiyle kayıt ekleyin.',
                        ),
                      ),
                    ];
                  }
                  return [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 104),
                      sliver: SliverList.separated(
                        itemCount: state.visibleCustomers.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final customer = state.visibleCustomers[index];
                          return _CustomerCard(
                            customer: customer,
                            isUpdating: formState.isLoading,
                            onTap: () => context.pushNamed(
                              AppRouteNames.customerDetail,
                              pathParameters: {'customerId': customer.id},
                            ),
                            onStatusChanged: (isActive) => ref
                                .read(customerFormControllerProvider.notifier)
                                .setActive(customer.id, isActive: isActive),
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

class _CustomerCard extends StatelessWidget {
  const _CustomerCard({
    required this.customer,
    required this.isUpdating,
    required this.onTap,
    required this.onStatusChanged,
  });

  final Customer customer;
  final bool isUpdating;
  final VoidCallback onTap;
  final ValueChanged<bool> onStatusChanged;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: customer.isActive ? 1 : 0.68,
    child: Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    child: Text(customer.name.characters.first.toUpperCase()),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          customer.name,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        if (customer.phone != null) Text(customer.phone!),
                        if (customer.email != null) Text(customer.email!),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  CustomerStatusChip(isActive: customer.isActive),
                  // MergeSemantics şart: onsuz Switch'in kendi düğümü adsız kalır.
                  MergeSemantics(
                    child: Semantics(
                      label: '${customer.name} aktif durumu',
                      toggled: customer.isActive,
                      child: Switch.adaptive(
                        value: customer.isActive,
                        onChanged: isUpdating ? null : onStatusChanged,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _MessageState extends StatelessWidget {
  const _MessageState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.people_outline_rounded, size: 52),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}
