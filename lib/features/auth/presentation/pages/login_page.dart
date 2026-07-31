import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:suretakip/app/router/app_routes.dart';
import 'package:suretakip/core/errors/domain_exception.dart';
import 'package:suretakip/core/utils/form_validators.dart';
import 'package:suretakip/features/auth/presentation/controllers/auth_controllers.dart';
import 'package:suretakip/features/auth/presentation/widgets/auth_card_scaffold.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final success = await ref
        .read(loginControllerProvider.notifier)
        .signIn(
          email: _emailController.text,
          password: _passwordController.text,
        );
    if (!mounted || !success) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Giriş başarılı.')));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(loginControllerProvider);
    ref.listen(loginControllerProvider, (_, next) {
      if (!next.hasError) return;
      final error = next.error;
      final message = error is DomainException
          ? error.message
          : 'Giriş yapılamadı. Lütfen tekrar deneyin.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    });

    return AuthCardScaffold(
      title: 'Tekrar hoş geldiniz',
      subtitle: 'İşletmenizi yönetmek için giriş yapın.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(
                labelText: 'E-posta',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              validator: FormValidators.email,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              obscureText: true,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              onFieldSubmitted: (_) => _submit(),
              decoration: const InputDecoration(
                labelText: 'Şifre',
                prefixIcon: Icon(Icons.lock_outline),
              ),
              validator: (value) =>
                  (value ?? '').isEmpty ? 'Şifre zorunlu.' : null,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: state.isLoading
                    ? null
                    : () => context.push(AppRoutes.forgotPassword),
                child: const Text('Şifremi unuttum'),
              ),
            ),
            FilledButton(
              onPressed: state.isLoading ? null : _submit,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: state.isLoading
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator.adaptive(
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Giriş Yap'),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: state.isLoading
                  ? null
                  : () => context.push(AppRoutes.register),
              child: const Text('Hesabınız yok mu? Kayıt olun'),
            ),
          ],
        ),
      ),
    );
  }
}
