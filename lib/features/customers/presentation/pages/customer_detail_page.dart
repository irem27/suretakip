import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:suretakip/app/router/app_routes.dart';
import 'package:suretakip/core/presentation/widgets/app_back_button.dart';
import 'package:suretakip/core/presentation/widgets/app_error_state.dart';
import 'package:suretakip/features/customers/domain/entities/customer.dart';
import 'package:suretakip/features/customers/presentation/controllers/customers_controllers.dart';
import 'package:suretakip/features/customers/presentation/utils/customer_presentation_utils.dart';
import 'package:suretakip/features/customers/presentation/widgets/customer_status_chip.dart';

class CustomerDetailPage extends ConsumerWidget {
  const CustomerDetailPage({required this.customerId, super.key});

  final String customerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(customerDetailProvider(customerId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Müşteri Detayı'),
        leading: const AppBackButton(
          fallbackRouteName: AppRouteNames.customers,
        ),
        actions: [
          TextButton.icon(
            onPressed: detail.hasValue
                ? () => context.pushNamed(
                    AppRouteNames.customerEdit,
                    pathParameters: {'customerId': customerId},
                  )
                : null,
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Düzenle'),
          ),
        ],
      ),
      body: SafeArea(
        child: detail.when(
          loading: () =>
              const Center(child: CircularProgressIndicator.adaptive()),
          error: (error, _) => AppErrorState(
            error: error,
            fallbackMessage: customerErrorMessage(
              error,
              'Müşteri detayı yüklenemedi. Lütfen tekrar deneyin.',
            ),
            onRetry: () => ref.invalidate(customerDetailProvider(customerId)),
          ),
          data: (customer) => _Content(customer: customer),
        ),
      ),
    );
  }
}

class _Content extends ConsumerWidget {
  const _Content({required this.customer});

  final Customer customer;

  Future<void> _toggle(BuildContext context, WidgetRef ref) async {
    final willActivate = !customer.isActive;
    final ok = await ref
        .read(customerFormControllerProvider.notifier)
        .setActive(customer.id, isActive: willActivate);
    if (!context.mounted || !ok) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          willActivate
              ? 'Müşteri yeniden aktifleştirildi.'
              : 'Müşteri pasife alındı.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final submitState = ref.watch(customerFormControllerProvider);
    ref.listen(customerFormControllerProvider, (_, next) {
      if (!next.hasError) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            customerErrorMessage(next.error, 'Müşteri durumu değiştirilemedi.'),
          ),
        ),
      );
    });
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: CustomerStatusChip(isActive: customer.isActive),
                ),
                const SizedBox(height: 16),
                Text(
                  customer.name,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Divider(height: 36),
                _Row(
                  icon: Icons.phone_outlined,
                  label: 'Telefon',
                  value: customer.phone ?? '—',
                ),
                const SizedBox(height: 16),
                _Row(
                  icon: Icons.email_outlined,
                  label: 'E-posta',
                  value: customer.email ?? '—',
                ),
                const SizedBox(height: 16),
                _Row(
                  icon: Icons.update_rounded,
                  label: 'Son güncelleme',
                  value: DateFormat(
                    'dd.MM.yyyy HH:mm',
                  ).format(customer.updatedAt.toLocal()),
                ),
                if (customer.notes != null) ...[
                  const Divider(height: 36),
                  Text(
                    'Notlar',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(customer.notes!),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: submitState.isLoading ? null : () => _toggle(context, ref),
          icon: Icon(
            customer.isActive
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
          ),
          label: Text(customer.isActive ? 'Pasife Al' : 'Aktifleştir'),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: Theme.of(context).colorScheme.primary),
      const SizedBox(width: 12),
      Expanded(
        child: Text(
          label,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
      Flexible(child: Text(value, textAlign: TextAlign.end)),
    ],
  );
}
