import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:suretakip/app/router/app_routes.dart';
import 'package:suretakip/core/presentation/widgets/app_error_state.dart';
import 'package:suretakip/features/services/domain/entities/service.dart';
import 'package:suretakip/features/services/presentation/controllers/services_controllers.dart';
import 'package:suretakip/features/services/presentation/utils/service_presentation_utils.dart';
import 'package:suretakip/features/services/presentation/widgets/service_status_chip.dart';

class ServiceDetailPage extends ConsumerWidget {
  const ServiceDetailPage({required this.serviceId, super.key});

  final String serviceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(serviceDetailProvider(serviceId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hizmet Detayı'),
        actions: [
          TextButton.icon(
            onPressed: detail.hasValue
                ? () => context.pushNamed(
                    AppRouteNames.serviceEdit,
                    pathParameters: {'serviceId': serviceId},
                  )
                : null,
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Düzenle'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: detail.when(
          loading: () =>
              const Center(child: CircularProgressIndicator.adaptive()),
          error: (error, _) => AppErrorState(
            error: error,
            fallbackMessage: serviceErrorMessage(
              error,
              'Hizmet detayı yüklenemedi. Lütfen tekrar deneyin.',
            ),
            onRetry: () => ref.invalidate(serviceDetailProvider(serviceId)),
          ),
          data: (service) => _DetailContent(service: service),
        ),
      ),
    );
  }
}

class _DetailContent extends ConsumerWidget {
  const _DetailContent({required this.service});

  final Service service;

  Future<void> _toggle(BuildContext context, WidgetRef ref) async {
    final willActivate = !service.isActive;
    final ok = await ref
        .read(serviceFormControllerProvider.notifier)
        .setActive(service.id, isActive: willActivate);
    if (!context.mounted || !ok) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          willActivate
              ? 'Hizmet yeniden aktifleştirildi.'
              : 'Hizmet pasife alındı.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final submitState = ref.watch(serviceFormControllerProvider);
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
                  child: ServiceStatusChip(isActive: service.isActive),
                ),
                const SizedBox(height: 16),
                Text(
                  service.name,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  formatMoneyPerMinute(
                    service.pricePerMinuteMinor,
                    service.currencyCode,
                  ),
                  textAlign: TextAlign.end,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Theme.of(context).colorScheme.secondary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Divider(height: 36),
                _DetailRow(
                  icon: Icons.timer_outlined,
                  label: 'Minimum ücretlendirme',
                  value: '${service.minimumChargeMinutes} dakika',
                ),
                const SizedBox(height: 16),
                _DetailRow(
                  icon: Icons.arrow_upward_rounded,
                  label: 'Yuvarlama aralığı',
                  value: '${service.roundingIntervalMinutes} dakika',
                ),
                const SizedBox(height: 16),
                _DetailRow(
                  icon: Icons.currency_exchange_rounded,
                  label: 'Para birimi',
                  value: service.currencyCode,
                ),
                const SizedBox(height: 16),
                _DetailRow(
                  icon: Icons.update_rounded,
                  label: 'Son güncelleme',
                  value: DateFormat(
                    'dd.MM.yyyy HH:mm',
                  ).format(service.updatedAt.toLocal()),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  service.isActive
                      ? 'Hizmeti pasife al'
                      : 'Hizmeti aktifleştir',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  service.isActive
                      ? 'Pasif hizmet yeni işlemlerde seçilemez; kayıt kalıcı olarak silinmez.'
                      : 'Hizmeti yeniden yeni işlemlerde kullanılabilir yapar.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: submitState.isLoading
                      ? null
                      : () => _toggle(context, ref),
                  icon: submitState.isLoading
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator.adaptive(
                            strokeWidth: 2,
                          ),
                        )
                      : Icon(
                          service.isActive
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                  label: Text(service.isActive ? 'Pasife Al' : 'Aktifleştir'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

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
      Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
    ],
  );
}
