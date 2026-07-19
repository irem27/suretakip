import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:suretakip/core/presentation/widgets/app_back_button.dart';
import 'package:suretakip/core/presentation/widgets/app_error_state.dart';
import 'package:go_router/go_router.dart';
import 'package:suretakip/app/providers/app_providers.dart';
import 'package:suretakip/app/router/app_routes.dart';
import 'package:suretakip/core/constants/app_constants.dart';
import 'package:suretakip/core/utils/form_validators.dart';
import 'package:suretakip/core/value_objects/money.dart';
import 'package:suretakip/features/services/domain/entities/service.dart';
import 'package:suretakip/features/services/domain/entities/service_input.dart';
import 'package:suretakip/features/services/presentation/controllers/services_controllers.dart';
import 'package:suretakip/features/services/presentation/utils/service_presentation_utils.dart';

class ServiceFormPage extends ConsumerWidget {
  const ServiceFormPage({this.serviceId, super.key});

  final String? serviceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = serviceId;
    if (id == null) return const _ServiceForm();

    return ref
        .watch(serviceDetailProvider(id))
        .when(
          loading: () => Scaffold(
            appBar: AppBar(
              leading: const AppBackButton(
                fallbackRouteName: AppRouteNames.services,
              ),
              title: const Text('Hizmeti Düzenle'),
            ),
            body: const Center(child: CircularProgressIndicator.adaptive()),
          ),
          error: (error, _) => Scaffold(
            appBar: AppBar(
              leading: const AppBackButton(
                fallbackRouteName: AppRouteNames.services,
              ),
              title: const Text('Hizmeti Düzenle'),
            ),
            body: _FormLoadError(error: error, serviceId: id),
          ),
          data: (service) => _ServiceForm(service: service),
        );
  }
}

class _ServiceForm extends ConsumerStatefulWidget {
  const _ServiceForm({this.service});

  final Service? service;

  @override
  ConsumerState<_ServiceForm> createState() => _ServiceFormState();
}

class _ServiceFormState extends ConsumerState<_ServiceForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _priceController;
  late int _roundingIntervalMinutes;
  late int _minimumChargeMinutes;

  bool get _isEditing => widget.service != null;

  @override
  void initState() {
    super.initState();
    final service = widget.service;
    _nameController = TextEditingController(text: service?.name);
    _priceController = TextEditingController(
      text: service == null
          ? ''
          : minorUnitsToInput(service.pricePerMinuteMinor),
    );
    _roundingIntervalMinutes =
        service?.roundingIntervalMinutes ??
        AppConstants.defaultRoundingIntervalMinutes;
    _minimumChargeMinutes =
        service?.minimumChargeMinutes ??
        AppConstants.defaultMinimumChargeMinutes;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final priceMinor = FormValidators.moneyToMinor(_priceController.text);
    final controller = ref.read(serviceFormControllerProvider.notifier);
    final current = widget.service;
    Service? result;
    if (current == null) {
      final business = ref.read(activeBusinessProvider);
      if (business == null) {
        _showMessage('Aktif işletme bulunamadı. Lütfen tekrar giriş yapın.');
        return;
      }
      result = await controller.create(
        ServiceInput(
          businessId: business.id,
          name: _nameController.text.trim(),
          pricePerMinute: Money(
            minorUnits: priceMinor,
            currencyCode: business.currencyCode,
          ),
          roundingIntervalMinutes: _roundingIntervalMinutes,
          minimumChargeMinutes: _minimumChargeMinutes,
        ),
      );
    } else {
      result = await controller.updateService(
        current.copyWith(
          name: _nameController.text.trim(),
          pricePerMinuteMinor: priceMinor,
          roundingIntervalMinutes: _roundingIntervalMinutes,
          minimumChargeMinutes: _minimumChargeMinutes,
        ),
      );
    }
    if (!mounted || result == null) return;
    if (_isEditing) {
      context.pop();
      return;
    }
    context.pushReplacementNamed(
      AppRouteNames.serviceDetail,
      pathParameters: {'serviceId': result.id},
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final submitState = ref.watch(serviceFormControllerProvider);
    final business = ref.watch(activeBusinessProvider);
    final currencyCode = widget.service?.currencyCode ?? business?.currencyCode;
    ref.listen(serviceFormControllerProvider, (_, next) {
      if (!next.hasError) return;
      _showMessage(
        serviceErrorMessage(
          next.error,
          'Hizmet kaydedilemedi. Lütfen tekrar deneyin.',
        ),
      );
    });

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallbackRouteName: AppRouteNames.services),
        title: Text(_isEditing ? 'Hizmeti Düzenle' : 'Yeni Hizmet'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 112),
            children: [
              _FormSection(
                icon: Icons.info_outline_rounded,
                title: 'Temel Bilgiler',
                child: TextFormField(
                  controller: _nameController,
                  textInputAction: TextInputAction.next,
                  maxLength: AppConstants.maximumNameLength,
                  decoration: const InputDecoration(
                    labelText: 'Hizmet adı',
                    hintText: 'Örn: Saatlik teknik servis',
                    prefixIcon: Icon(Icons.design_services_outlined),
                  ),
                  validator: (value) =>
                      FormValidators.requiredName(value, 'Hizmet adı'),
                ),
              ),
              const SizedBox(height: 16),
              _FormSection(
                icon: Icons.payments_outlined,
                title: 'Fiyatlandırma',
                child: Column(
                  children: [
                    TextFormField(
                      controller: _priceController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        labelText: 'Dakika ücreti',
                        helperText: currencyCode == null
                            ? null
                            : 'İşletme para birimi: $currencyCode',
                        prefixIcon: const Icon(Icons.sell_outlined),
                      ),
                      validator: (value) =>
                          FormValidators.positiveMoney(value, 'Dakika ücreti'),
                    ),
                    const SizedBox(height: 16),
                    _MinuteDropdown(
                      label: 'Minimum ücretlendirilecek süre',
                      value: _minimumChargeMinutes,
                      values: _withCurrent(
                        AppConstants.serviceMinimumChargeOptions,
                        _minimumChargeMinutes,
                      ),
                      onChanged: (value) =>
                          setState(() => _minimumChargeMinutes = value),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _FormSection(
                icon: Icons.calculate_outlined,
                title: 'Ücretlendirme Yöntemi',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Süre, seçilen dakika aralığına yukarı yuvarlanır.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _MinuteDropdown(
                      label: 'Yuvarlama aralığı',
                      value: _roundingIntervalMinutes,
                      values: _withCurrent(
                        AppConstants.serviceRoundingIntervalOptions,
                        _roundingIntervalMinutes,
                      ),
                      onChanged: (value) =>
                          setState(() => _roundingIntervalMinutes = value),
                    ),
                  ],
                ),
              ),
              if (_isEditing) ...[
                const SizedBox(height: 16),
                Card(
                  child: SwitchListTile.adaptive(
                    value: widget.service!.isActive,
                    onChanged: null,
                    secondary: const Icon(Icons.visibility_outlined),
                    title: Text(
                      widget.service!.isActive
                          ? 'Hizmet aktif'
                          : 'Hizmet pasif',
                    ),
                    subtitle: const Text(
                      'Durumu detay veya liste ekranından değiştirebilirsiniz.',
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              top: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: submitState.isLoading ? null : context.pop,
                  child: const Text('İptal'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: submitState.isLoading ? null : _submit,
                  icon: submitState.isLoading
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator.adaptive(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(
                    _isEditing ? 'Değişiklikleri Kaydet' : 'Hizmeti Kaydet',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

List<int> _withCurrent(List<int> values, int current) {
  final result = {...values, current}.toList()..sort();
  return result;
}

class _FormSection extends StatelessWidget {
  const _FormSection({
    required this.icon,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 10),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const Divider(height: 28),
          child,
        ],
      ),
    ),
  );
}

class _MinuteDropdown extends StatelessWidget {
  const _MinuteDropdown({
    required this.label,
    required this.value,
    required this.values,
    required this.onChanged,
  });

  final String label;
  final int value;
  final List<int> values;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<int>(
    isExpanded: true,
    initialValue: value,
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: const Icon(Icons.timer_outlined),
    ),
    items: values
        .map(
          (minutes) =>
              DropdownMenuItem(value: minutes, child: Text('$minutes dakika')),
        )
        .toList(growable: false),
    onChanged: (selected) {
      if (selected != null) onChanged(selected);
    },
  );
}

class _FormLoadError extends ConsumerWidget {
  const _FormLoadError({required this.error, required this.serviceId});

  final Object error;
  final String serviceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) => AppErrorState(
    error: error,
    fallbackMessage: serviceErrorMessage(
      error,
      'Hizmet bilgileri yüklenemedi. Lütfen tekrar deneyin.',
    ),
    onRetry: () => ref.invalidate(serviceDetailProvider(serviceId)),
    padding: const EdgeInsets.all(32),
  );
}
