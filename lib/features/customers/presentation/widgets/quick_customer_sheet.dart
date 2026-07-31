import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:suretakip/app/providers/app_providers.dart';
import 'package:suretakip/core/constants/app_constants.dart';
import 'package:suretakip/core/utils/form_validators.dart';
import 'package:suretakip/features/customers/domain/entities/customer.dart';
import 'package:suretakip/features/customers/domain/entities/customer_input.dart';
import 'package:suretakip/features/customers/presentation/controllers/customers_controllers.dart';
import 'package:suretakip/features/customers/presentation/utils/customer_presentation_utils.dart';

/// Akışı bölmeden müşteri oluşturmak için kullanılan alt panel.
///
/// Tam müşteri formu kayıttan sonra detay sayfasına yönlendirdiği için işlem
/// başlatma akışında kullanılamaz. Bu panel yalnızca zorunlu alanları sorar ve
/// oluşturulan [Customer] ile kapanır; çağıran taraf onu doğrudan seçebilir.
Future<Customer?> showQuickCustomerSheet(BuildContext context) =>
    showModalBottomSheet<Customer>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const QuickCustomerSheet(),
    );

class QuickCustomerSheet extends ConsumerStatefulWidget {
  const QuickCustomerSheet({super.key});

  @override
  ConsumerState<QuickCustomerSheet> createState() => _QuickCustomerSheetState();
}

class _QuickCustomerSheetState extends ConsumerState<QuickCustomerSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  String? _nullable(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final businessId = ref.read(activeBusinessScopeProvider).businessId;
    if (businessId == null) {
      _showMessage('Aktif işletme bulunamadı. Lütfen tekrar deneyin.');
      return;
    }
    final created = await ref
        .read(customerFormControllerProvider.notifier)
        .create(
          CustomerInput(
            businessId: businessId,
            name: _nameController.text.trim(),
            phone: _nullable(_phoneController.text),
          ),
        );
    if (!mounted || created == null) return;
    Navigator.of(context).pop(created);
  }

  void _showMessage(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) {
    final submitState = ref.watch(customerFormControllerProvider);
    ref.listen(customerFormControllerProvider, (_, next) {
      if (!next.hasError) return;
      _showMessage(
        customerErrorMessage(
          next.error,
          'Müşteri kaydedilemedi. Lütfen tekrar deneyin.',
        ),
      );
    });

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Yeni Müşteri',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              autofocus: true,
              textInputAction: TextInputAction.next,
              maxLength: AppConstants.maximumNameLength,
              decoration: const InputDecoration(
                labelText: 'Ad soyad',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
              validator: (value) =>
                  FormValidators.requiredName(value, 'Müşteri adı'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Telefon (isteğe bağlı)',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
              onFieldSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: submitState.isLoading ? null : _submit,
              icon: submitState.isLoading
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_rounded),
              label: const Text('Kaydet ve Seç'),
            ),
          ],
        ),
      ),
    );
  }
}
