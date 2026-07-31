import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:suretakip/app/router/app_routes.dart';
import 'package:suretakip/core/errors/domain_exception.dart';
import 'package:suretakip/core/utils/form_validators.dart';
import 'package:suretakip/features/auth/presentation/controllers/auth_controllers.dart';
import 'package:suretakip/features/auth/presentation/widgets/auth_card_scaffold.dart';

class ResetPasswordPage extends ConsumerStatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  ConsumerState<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends ConsumerState<ResetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmationController = TextEditingController();

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final success = await ref
        .read(updatePasswordControllerProvider.notifier)
        .changePassword(_passwordController.text);
    if (!mounted || !success) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Şifreniz başarıyla güncellendi.')),
    );
    context.go(AppRoutes.dashboard);
  }

  String? _validateConfirmation(String? value) {
    final passwordError = FormValidators.password(value);
    if (passwordError != null) return passwordError;
    return value == _passwordController.text ? null : 'Şifreler eşleşmiyor.';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(updatePasswordControllerProvider);
    ref.listen(updatePasswordControllerProvider, (_, next) {
      if (!next.hasError) return;
      final error = next.error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is DomainException
                ? error.message
                : 'Şifre güncellenemedi. Lütfen tekrar deneyin.',
          ),
        ),
      );
    });
    return AuthCardScaffold(
      title: 'Yeni şifrenizi belirleyin',
      subtitle: 'Hesabınız için güvenli bir şifre oluşturun.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PasswordField(controller: _passwordController),
            const SizedBox(height: 16),
            _ConfirmationField(
              controller: _confirmationController,
              validator: _validateConfirmation,
              onSubmitted: _submit,
            ),
            const SizedBox(height: 24),
            _SubmitButton(isLoading: state.isLoading, onPressed: _submit),
          ],
        ),
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: true,
      textInputAction: TextInputAction.next,
      autofillHints: const [AutofillHints.newPassword],
      decoration: const InputDecoration(
        labelText: 'Yeni şifre',
        prefixIcon: Icon(Icons.lock_outline),
      ),
      validator: FormValidators.password,
    );
  }
}

class _ConfirmationField extends StatelessWidget {
  const _ConfirmationField({
    required this.controller,
    required this.validator,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final FormFieldValidator<String> validator;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: true,
      textInputAction: TextInputAction.done,
      autofillHints: const [AutofillHints.newPassword],
      onFieldSubmitted: (_) => onSubmitted(),
      decoration: const InputDecoration(
        labelText: 'Yeni şifre tekrarı',
        prefixIcon: Icon(Icons.lock_reset_rounded),
      ),
      validator: validator,
    );
  }
}

class _SubmitButton extends StatelessWidget {
  const _SubmitButton({required this.isLoading, required this.onPressed});

  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: isLoading ? null : onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: isLoading
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator.adaptive(strokeWidth: 2),
              )
            : const Text('Şifreyi Güncelle'),
      ),
    );
  }
}
