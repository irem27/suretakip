import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:suretakip/core/presentation/widgets/app_error_state.dart';
import 'package:go_router/go_router.dart';
import 'package:suretakip/app/providers/app_providers.dart';
import 'package:suretakip/app/router/app_routes.dart';
import 'package:suretakip/core/constants/app_constants.dart';
import 'package:suretakip/core/utils/form_validators.dart';
import 'package:suretakip/features/customers/domain/entities/customer.dart';
import 'package:suretakip/features/customers/domain/entities/customer_input.dart';
import 'package:suretakip/features/customers/presentation/controllers/customers_controllers.dart';
import 'package:suretakip/features/customers/presentation/utils/customer_presentation_utils.dart';

class CustomerFormPage extends ConsumerWidget {
  const CustomerFormPage({this.customerId, super.key});

  final String? customerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = customerId;
    if (id == null) return const _CustomerForm();
    return ref
        .watch(customerDetailProvider(id))
        .when(
          loading: () => Scaffold(
            appBar: AppBar(title: const Text('Müşteriyi Düzenle')),
            body: const Center(child: CircularProgressIndicator.adaptive()),
          ),
          error: (error, _) => Scaffold(
            appBar: AppBar(title: const Text('Müşteriyi Düzenle')),
            body: _LoadError(error: error, customerId: id),
          ),
          data: (customer) => _CustomerForm(customer: customer),
        );
  }
}

class _CustomerForm extends ConsumerStatefulWidget {
  const _CustomerForm({this.customer});

  final Customer? customer;

  @override
  ConsumerState<_CustomerForm> createState() => _CustomerFormState();
}

class _CustomerFormState extends ConsumerState<_CustomerForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _notesController;

  bool get _isEditing => widget.customer != null;

  @override
  void initState() {
    super.initState();
    final customer = widget.customer;
    _nameController = TextEditingController(text: customer?.name);
    _phoneController = TextEditingController(text: customer?.phone);
    _emailController = TextEditingController(text: customer?.email);
    _notesController = TextEditingController(text: customer?.notes);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String? _optionalEmail(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return FormValidators.email(value);
  }

  String? _nullable(String value) {
    final normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final controller = ref.read(customerFormControllerProvider.notifier);
    final current = widget.customer;
    Customer? result;
    if (current == null) {
      final business = ref.read(activeBusinessProvider);
      if (business == null) {
        _showMessage('Aktif işletme bulunamadı. Lütfen tekrar giriş yapın.');
        return;
      }
      result = await controller.create(
        CustomerInput(
          businessId: business.id,
          name: _nameController.text.trim(),
          phone: _nullable(_phoneController.text),
          email: _nullable(_emailController.text),
          notes: _nullable(_notesController.text),
        ),
      );
    } else {
      result = await controller.updateCustomer(
        current.copyWith(
          name: _nameController.text.trim(),
          phone: _nullable(_phoneController.text),
          email: _nullable(_emailController.text),
          notes: _nullable(_notesController.text),
        ),
      );
    }
    if (!mounted || result == null) return;
    if (_isEditing) {
      context.pop();
      return;
    }
    context.goNamed(
      AppRouteNames.customerDetail,
      pathParameters: {'customerId': result.id},
    );
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
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Müşteriyi Düzenle' : 'Yeni Müşteri'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 112),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _nameController,
                        maxLength: AppConstants.maximumNameLength,
                        textInputAction: TextInputAction.next,
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
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Telefon (isteğe bağlı)',
                          prefixIcon: Icon(Icons.phone_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'E-posta (isteğe bağlı)',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        validator: _optionalEmail,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _notesController,
                        minLines: 3,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          labelText: 'Notlar (isteğe bağlı)',
                          alignLabelWithHint: true,
                          prefixIcon: Icon(Icons.notes_rounded),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: submitState.isLoading ? null : _submit,
            icon: submitState.isLoading
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(
              _isEditing ? 'Değişiklikleri Kaydet' : 'Müşteriyi Kaydet',
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadError extends ConsumerWidget {
  const _LoadError({required this.error, required this.customerId});

  final Object error;
  final String customerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) => AppErrorState(
    error: error,
    fallbackMessage: customerErrorMessage(
      error,
      'Müşteri bilgileri yüklenemedi.',
    ),
    onRetry: () => ref.invalidate(customerDetailProvider(customerId)),
    padding: const EdgeInsets.all(32),
  );
}
