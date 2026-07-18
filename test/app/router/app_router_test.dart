import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suretakip/app/providers/app_providers.dart';
import 'package:suretakip/app/router/app_router.dart';
import 'package:suretakip/features/auth/domain/entities/auth_session_state.dart';

void main() {
  testWidgets('oturum açıkken reset password route erişilebilir kalır', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        authSessionStateProvider.overrideWith(
          (ref) => Stream.value(const AuthSessionState(userId: 'user-1')),
        ),
        userBusinessesProvider.overrideWith((ref) async => const []),
      ],
    );
    final router = container.read(appRouterProvider);
    addTearDown(() {
      router.dispose();
      container.dispose();
    });

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    router.go('/reset-password');
    await tester.pumpAndSettle();

    expect(find.text('Yeni şifrenizi belirleyin'), findsOneWidget);
  });

  testWidgets('password recovery olayı reset ekranına yönlendirir', (
    tester,
  ) async {
    final authStates = StreamController<AuthSessionState>();
    final container = ProviderContainer(
      overrides: [
        authSessionStateProvider.overrideWith((ref) => authStates.stream),
        userBusinessesProvider.overrideWith((ref) async => const []),
      ],
    );
    final router = container.read(appRouterProvider);
    addTearDown(() async {
      router.dispose();
      container.dispose();
      await authStates.close();
    });

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    authStates.add(const AuthSessionState(userId: 'user-1'));
    await tester.pumpAndSettle();

    authStates.add(
      const AuthSessionState(userId: 'user-1', isPasswordRecovery: true),
    );
    await tester.pumpAndSettle();

    expect(find.text('Yeni şifrenizi belirleyin'), findsOneWidget);
  });
}
