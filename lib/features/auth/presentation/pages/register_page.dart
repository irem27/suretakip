import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:suretakip/app/providers/app_providers.dart';
import 'package:suretakip/app/router/app_routes.dart';
import 'package:suretakip/core/errors/domain_exception.dart';
import 'package:suretakip/core/utils/form_validators.dart';
import 'package:suretakip/features/auth/presentation/controllers/auth_controllers.dart';
import 'package:suretakip/features/auth/presentation/widgets/auth_card_scaffold.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmationController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final success = await ref
        .read(registerControllerProvider.notifier)
        .signUp(
          email: _emailController.text,
          password: _passwordController.text,
        );
    if (!mounted || !success) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Hesabınız oluşturuldu. Gerekirse e-postanızı doğrulayın.',
        ),
      ),
    );
    // E-posta doğrulaması kapalıysa signUp anında oturum kurar; bu durumda
    // router'ın redirect mantığı kullanıcıyı zaten doğru sayfaya taşır.
    // Oturum kurulmadıysa (doğrulama bekleniyorsa) login'e yönlendiririz.
    final userId = await ref
        .read(authRepositoryProvider)
        .getAuthenticatedUserId();
    if (!mounted || userId != null) return;
    context.go(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(registerControllerProvider);
    ref.listen(registerControllerProvider, (_, next) {
      if (!next.hasError) return;
      final error = next.error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is DomainException
                ? error.message
                : 'Kayıt oluşturulamadı. Lütfen tekrar deneyin.',
          ),
        ),
      );
    });
    return AuthCardScaffold(
      title: 'İşletmenizi kurmaya başlayın',
      subtitle: 'SüreTakip hesabınızı birkaç saniyede oluşturun.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
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
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Şifre',
                prefixIcon: Icon(Icons.lock_outline),
              ),
              validator: FormValidators.password,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _confirmationController,
              obscureText: true,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              decoration: const InputDecoration(
                labelText: 'Şifre tekrarı',
                prefixIcon: Icon(Icons.lock_reset_rounded),
              ),
              validator: (value) => value == _passwordController.text
                  ? null
                  : 'Şifreler eşleşmiyor.',
            ),
            const SizedBox(height: 24),
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
                    : const Text('Kayıt Ol'),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: state.isLoading
                  ? null
                  : () => context.go(AppRoutes.login),
              child: const Text('Giriş ekranına dön'),
            ),
          ],
        ),
      ),
    );
  }
}
