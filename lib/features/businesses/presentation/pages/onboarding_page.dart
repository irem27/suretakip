import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:suretakip/core/constants/app_constants.dart';
import 'package:suretakip/core/errors/domain_exception.dart';
import 'package:suretakip/core/utils/form_validators.dart';
import 'package:suretakip/features/businesses/presentation/controllers/onboarding_controller.dart';

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final _businessName = TextEditingController();
  final _serviceName = TextEditingController();
  final _servicePrice = TextEditingController();
  final _productName = TextEditingController();
  final _productPrice = TextEditingController();
  var _step = 0;
  var _currency = AppConstants.defaultCurrencyCode;
  var _timezone = AppConstants.defaultTimezone;
  var _includeProduct = false;
  var _showErrors = false;

  @override
  void dispose() {
    _businessName.dispose();
    _serviceName.dispose();
    _servicePrice.dispose();
    _productName.dispose();
    _productPrice.dispose();
    super.dispose();
  }

  void _continue() {
    setState(() => _showErrors = true);
    final error = _stepError();
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    if (_step < 4) {
      setState(() {
        _step += 1;
        _showErrors = false;
      });
      return;
    }
    _complete();
  }

  void _clearErrors(String _) {
    if (_showErrors) setState(() => _showErrors = false);
  }

  String? _stepError() => switch (_step) {
    0 => FormValidators.requiredName(_businessName.text, 'İşletme adı'),
    3 =>
      FormValidators.requiredName(_serviceName.text, 'Hizmet adı') ??
          FormValidators.nonNegativeMoney(_servicePrice.text, 'dakika ücreti'),
    4 when _includeProduct =>
      FormValidators.requiredName(_productName.text, 'Ürün adı') ??
          FormValidators.nonNegativeMoney(_productPrice.text, 'ürün fiyatı'),
    _ => null,
  };

  Future<void> _complete() async {
    await ref
        .read(onboardingControllerProvider.notifier)
        .complete(
          OnboardingRequest(
            businessName: _businessName.text,
            currencyCode: _currency,
            timezone: _timezone,
            serviceName: _serviceName.text,
            servicePricePerMinuteMinor: FormValidators.moneyToMinor(
              _servicePrice.text,
            ),
            includeProduct: _includeProduct,
            productName: _productName.text,
            productPriceMinor: _includeProduct
                ? FormValidators.moneyToMinor(_productPrice.text)
                : 0,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(onboardingControllerProvider);
    ref.listen(onboardingControllerProvider, (_, next) {
      if (!next.hasError) return;
      final error = next.error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is DomainException
                ? error.message
                : 'Kurulum tamamlanamadı. Lütfen tekrar deneyin.',
          ),
        ),
      );
    });
    return Scaffold(
      appBar: AppBar(title: const Text('İşletme Kurulumu')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Stepper(
              currentStep: _step,
              onStepContinue: asyncState.isLoading ? null : _continue,
              onStepCancel: _step == 0 || asyncState.isLoading
                  ? null
                  : () => setState(() => _step -= 1),
              controlsBuilder: (context, details) => Padding(
                padding: const EdgeInsets.only(top: 24),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton(
                      onPressed: details.onStepContinue,
                      child: asyncState.isLoading
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator.adaptive(
                                strokeWidth: 2,
                              ),
                            )
                          : Text(_step == 4 ? 'Kurulumu Tamamla' : 'Devam Et'),
                    ),
                    if (_step > 0) ...[
                      TextButton(
                        onPressed: details.onStepCancel,
                        child: const Text('Geri'),
                      ),
                    ],
                  ],
                ),
              ),
              steps: [
                Step(
                  title: const Text('İşletme adı'),
                  subtitle: const Text('Müşterilerinizin göreceği adı girin.'),
                  isActive: _step >= 0,
                  content: TextField(
                    controller: _businessName,
                    textInputAction: TextInputAction.done,
                    onChanged: _clearErrors,
                    decoration: InputDecoration(
                      labelText: 'İşletme adı',
                      prefixIcon: const Icon(Icons.storefront_outlined),
                      errorText: _showErrors && _step == 0
                          ? FormValidators.requiredName(
                              _businessName.text,
                              'İşletme adı',
                            )
                          : null,
                    ),
                  ),
                ),
                Step(
                  title: const Text('Para birimi'),
                  subtitle: const Text('Fiyat ve raporlarda kullanılacak.'),
                  isActive: _step >= 1,
                  content: DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: _currency,
                    decoration: const InputDecoration(labelText: 'Para birimi'),
                    items: AppConstants.supportedCurrencyCodes
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) {
                      if (value != null) setState(() => _currency = value);
                    },
                  ),
                ),
                Step(
                  title: const Text('Saat dilimi'),
                  subtitle: const Text(
                    'İşlem süreleri bu bölgeye göre tutulur.',
                  ),
                  isActive: _step >= 2,
                  content: DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: _timezone,
                    decoration: const InputDecoration(labelText: 'Saat dilimi'),
                    items: AppConstants.supportedTimezones
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) {
                      if (value != null) setState(() => _timezone = value);
                    },
                  ),
                ),
                Step(
                  title: const Text('İlk hizmet'),
                  subtitle: const Text('Zorunlu · Dakika bazlı fiyat girin.'),
                  isActive: _step >= 3,
                  content: Column(
                    children: [
                      TextField(
                        controller: _serviceName,
                        textInputAction: TextInputAction.next,
                        onChanged: _clearErrors,
                        decoration: InputDecoration(
                          labelText: 'Hizmet adı',
                          prefixIcon: const Icon(
                            Icons.design_services_outlined,
                          ),
                          errorText: _showErrors && _step == 3
                              ? FormValidators.requiredName(
                                  _serviceName.text,
                                  'Hizmet adı',
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _servicePrice,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        onChanged: _clearErrors,
                        decoration: InputDecoration(
                          labelText: 'Dakika ücreti ($_currency)',
                          prefixIcon: const Icon(Icons.payments_outlined),
                          errorText: _showErrors && _step == 3
                              ? FormValidators.nonNegativeMoney(
                                  _servicePrice.text,
                                  'dakika ücreti',
                                )
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
                Step(
                  title: const Text('İlk ürün'),
                  subtitle: const Text(
                    'Opsiyonel · Daha sonra da ekleyebilirsiniz.',
                  ),
                  isActive: _step >= 4,
                  content: Column(
                    children: [
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Şimdi bir ürün ekle'),
                        value: _includeProduct,
                        onChanged: (value) =>
                            setState(() => _includeProduct = value),
                      ),
                      if (_includeProduct) ...[
                        const SizedBox(height: 8),
                        TextField(
                          controller: _productName,
                          textInputAction: TextInputAction.next,
                          onChanged: _clearErrors,
                          decoration: InputDecoration(
                            labelText: 'Ürün adı',
                            prefixIcon: const Icon(Icons.inventory_2_outlined),
                            errorText: _showErrors && _step == 4
                                ? FormValidators.requiredName(
                                    _productName.text,
                                    'Ürün adı',
                                  )
                                : null,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _productPrice,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          onChanged: _clearErrors,
                          decoration: InputDecoration(
                            labelText: 'Satış fiyatı ($_currency)',
                            prefixIcon: const Icon(Icons.sell_outlined),
                            errorText: _showErrors && _step == 4
                                ? FormValidators.nonNegativeMoney(
                                    _productPrice.text,
                                    'ürün fiyatı',
                                  )
                                : null,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
