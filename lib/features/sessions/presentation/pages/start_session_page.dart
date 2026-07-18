import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:suretakip/app/providers/app_providers.dart';
import 'package:suretakip/app/router/app_routes.dart';
import 'package:suretakip/core/errors/domain_exception.dart';
import 'package:suretakip/core/presentation/widgets/app_error_state.dart';
import 'package:suretakip/features/customers/domain/entities/customer.dart';
import 'package:suretakip/features/customers/presentation/controllers/customers_controllers.dart';
import 'package:suretakip/features/services/domain/entities/service.dart';
import 'package:suretakip/features/services/presentation/controllers/services_controllers.dart';
import 'package:suretakip/features/sessions/presentation/controllers/sessions_controllers.dart';
import 'package:suretakip/features/sessions/presentation/utils/session_presentation_utils.dart';

class StartSessionPage extends ConsumerStatefulWidget {
  const StartSessionPage({super.key});

  @override
  ConsumerState<StartSessionPage> createState() => _StartSessionPageState();
}

class _StartSessionPageState extends ConsumerState<StartSessionPage> {
  final _notesController = TextEditingController();
  String? _customerId;
  String? _serviceId;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scope = ref.watch(activeBusinessScopeProvider);
    final customersProvider = customersListControllerProvider(scope);
    final servicesProvider = servicesListControllerProvider(scope);
    final customers = ref.watch(customersProvider);
    final services = ref.watch(servicesProvider);
    final submit = ref.watch(startSessionControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Yeni İşlem')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const _StepTitle(number: 1, title: 'Müşteri seç'),
            const SizedBox(height: 12),
            customers.when(
              loading: () =>
                  const _SelectorLoading(label: 'Müşteriler yükleniyor'),
              error: (error, _) => AppErrorState(
                error: error,
                fallbackMessage: 'Müşteriler yüklenemedi.',
                onRetry: () => ref.read(customersProvider.notifier).refresh(),
                padding: const EdgeInsets.all(16),
                iconSize: 40,
              ),
              data: (state) => _CustomerSelector(
                customers: state.customers
                    .where((customer) => customer.isActive)
                    .toList(growable: false),
                selectedId: _customerId,
                onSelected: (id) => setState(() => _customerId = id),
              ),
            ),
            const SizedBox(height: 24),
            const _StepTitle(number: 2, title: 'Hizmet seç'),
            const SizedBox(height: 12),
            services.when(
              loading: () =>
                  const _SelectorLoading(label: 'Hizmetler yükleniyor'),
              error: (error, _) => AppErrorState(
                error: error,
                fallbackMessage: 'Hizmetler yüklenemedi.',
                onRetry: () => ref.read(servicesProvider.notifier).refresh(),
                padding: const EdgeInsets.all(16),
                iconSize: 40,
              ),
              data: (state) => _ServiceSelector(
                services: state.services
                    .where((service) => service.isActive)
                    .toList(growable: false),
                selectedId: _serviceId,
                onSelected: (id) => setState(() => _serviceId = id),
              ),
            ),
            const SizedBox(height: 24),
            const _StepTitle(number: 3, title: 'Not ve onay'),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              minLines: 3,
              maxLines: 5,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: 'Not (isteğe bağlı)',
                hintText: 'İşlem hakkında kısa bir not ekleyin',
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: submit.isLoading || _serviceId == null
                  ? null
                  : _startSession,
              icon: submit.isLoading
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                    )
                  : const Icon(Icons.play_arrow_rounded),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('Süreyi Başlat'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startSession() async {
    final sessionId = await ref
        .read(startSessionControllerProvider.notifier)
        .start(
          serviceId: _serviceId!,
          customerId: _customerId,
          notes: _notesController.text,
        );
    if (!mounted) return;
    if (sessionId != null) {
      context.goNamed(
        AppRouteNames.sessionDetail,
        pathParameters: {'sessionId': sessionId},
      );
      return;
    }
    final error = ref.read(startSessionControllerProvider).error;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error is DomainException
              ? error.message
              : 'İşlem başlatılamadı. Lütfen tekrar deneyin.',
        ),
      ),
    );
  }
}

class _StepTitle extends StatelessWidget {
  const _StepTitle({required this.number, required this.title});

  final int number;
  final String title;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Row(
      children: [
        ExcludeSemantics(
          child: CircleAvatar(radius: 18, child: Text('$number')),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
      ],
    ),
  );
}

class _CustomerSelector extends StatelessWidget {
  const _CustomerSelector({
    required this.customers,
    required this.selectedId,
    required this.onSelected,
  });

  final List<Customer> customers;
  final String? selectedId;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Semantics(
        button: true,
        selected: selectedId == null,
        label: 'Misafir müşteri. Müşteri kaydı olmadan devam et.',
        excludeSemantics: true,
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            selected: selectedId == null,
            onTap: () => onSelected(null),
            title: const Text('Misafir müşteri'),
            subtitle: const Text('Müşteri kaydı olmadan devam et'),
            leading: const Icon(Icons.person_outline_rounded),
            trailing: selectedId == null
                ? const Icon(Icons.check_circle_rounded)
                : null,
          ),
        ),
      ),
      for (final customer in customers)
        Semantics(
          button: true,
          selected: selectedId == customer.id,
          label: 'Müşteri: ${customer.name}',
          excludeSemantics: true,
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              selected: selectedId == customer.id,
              onTap: () => onSelected(customer.id),
              title: Text(customer.name),
              subtitle: customer.phone == null ? null : Text(customer.phone!),
              leading: const Icon(Icons.person_rounded),
              trailing: selectedId == customer.id
                  ? const Icon(Icons.check_circle_rounded)
                  : null,
            ),
          ),
        ),
    ],
  );
}

class _ServiceSelector extends StatelessWidget {
  const _ServiceSelector({
    required this.services,
    required this.selectedId,
    required this.onSelected,
  });

  final List<Service> services;
  final String? selectedId;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    if (services.isEmpty) {
      return _ActionMessage(
        message:
            'Aktif hizmet bulunamadı. İşlem başlatmak için önce bir hizmet ekleyin.',
        actionLabel: 'Hizmet Ekle',
        onAction: () => context.pushNamed(AppRouteNames.serviceCreate),
      );
    }
    return Column(
      children: [
        for (final service in services)
          Semantics(
            button: true,
            selected: selectedId == service.id,
            label: 'Hizmet: ${service.name}',
            excludeSemantics: true,
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                selected: selectedId == service.id,
                onTap: () => onSelected(service.id),
                title: Text(service.name),
                subtitle: Text(
                  '${formatSessionMoney(service.pricePerMinuteMinor, service.currencyCode)}/dk · '
                  '${service.roundingIntervalMinutes} dk yuvarlama',
                ),
                trailing: selectedId == service.id
                    ? const Icon(Icons.check_circle_rounded)
                    : null,
              ),
            ),
          ),
      ],
    );
  }
}

class _SelectorLoading extends StatelessWidget {
  const _SelectorLoading({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 96,
    child: Center(
      child: CircularProgressIndicator.adaptive(semanticsLabel: label),
    ),
  );
}

class _ActionMessage extends StatelessWidget {
  const _ActionMessage({
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    ),
  );
}
