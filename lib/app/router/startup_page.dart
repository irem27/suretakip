import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:suretakip/app/providers/app_providers.dart';
import 'package:suretakip/core/presentation/widgets/app_error_state.dart';

class StartupPage extends ConsumerWidget {
  const StartupPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authenticatedUserIdProvider);
    final businesses = ref.watch(userBusinessesProvider);
    final error = auth.error ?? businesses.error;
    return Scaffold(
      body: Center(
        child: error == null
            ? const CircularProgressIndicator.adaptive()
            : AppErrorState(
                error: error,
                fallbackMessage: 'Hesap bilgileri yüklenemedi.',
                onRetry: () {
                  ref.invalidate(authenticatedUserIdProvider);
                  ref.invalidate(userBusinessesProvider);
                },
              ),
      ),
    );
  }
}
