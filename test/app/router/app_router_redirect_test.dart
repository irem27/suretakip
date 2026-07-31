import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suretakip/app/providers/app_providers.dart';
import 'package:suretakip/app/router/app_router.dart';
import 'package:suretakip/app/router/app_routes.dart';
import 'package:suretakip/features/auth/domain/entities/auth_session_state.dart';
import 'package:suretakip/features/businesses/domain/entities/business.dart';

void main() {
  testWidgets('auth yüklenirken korumalı sayfa startup’a yönlendirilir', (
    tester,
  ) async {
    final authStates = StreamController<AuthSessionState>();
    final location = await _pumpAndGo(
      tester,
      overrides: [
        authSessionStateProvider.overrideWith((ref) => authStates.stream),
        userBusinessesProvider.overrideWith((ref) async => const []),
      ],
      go: AppRoutes.dashboard,
      awaitAuth: false,
      awaitBusinesses: false,
    );
    addTearDown(authStates.close);

    expect(location, AppRoutes.startup);
  });

  testWidgets('auth yüklenirken startup sayfası kendisinde kalır', (
    tester,
  ) async {
    final authStates = StreamController<AuthSessionState>();
    final location = await _pumpAndGo(
      tester,
      overrides: [
        authSessionStateProvider.overrideWith((ref) => authStates.stream),
        userBusinessesProvider.overrideWith((ref) async => const []),
      ],
      go: AppRoutes.startup,
      awaitAuth: false,
      awaitBusinesses: false,
    );
    addTearDown(authStates.close);

    expect(location, AppRoutes.startup);
  });

  testWidgets('auth hata verirse korumalı sayfa startup’a yönlendirilir', (
    tester,
  ) async {
    final location = await _pumpAndGo(
      tester,
      overrides: [
        authSessionStateProvider.overrideWith(
          (ref) => Stream<AuthSessionState>.error(Exception('auth-error')),
        ),
        userBusinessesProvider.overrideWith((ref) async => const []),
      ],
      go: AppRoutes.dashboard,
      awaitAuth: false,
      awaitBusinesses: false,
    );

    expect(location, AppRoutes.startup);
  });

  testWidgets('oturum yoksa korumalı sayfa login’e yönlendirilir', (
    tester,
  ) async {
    final location = await _pumpAndGo(
      tester,
      overrides: [
        authSessionStateProvider.overrideWith(
          (ref) => Stream.value(const AuthSessionState(userId: null)),
        ),
        userBusinessesProvider.overrideWith((ref) async => const []),
      ],
      go: AppRoutes.dashboard,
    );

    expect(location, AppRoutes.login);
  });

  testWidgets('oturum yoksa login sayfasında kalınır', (tester) async {
    final location = await _pumpAndGo(
      tester,
      overrides: [
        authSessionStateProvider.overrideWith(
          (ref) => Stream.value(const AuthSessionState(userId: null)),
        ),
        userBusinessesProvider.overrideWith((ref) async => const []),
      ],
      go: AppRoutes.login,
    );

    expect(location, AppRoutes.login);
  });

  testWidgets('işletmeler yüklenirken startup’a yönlendirilir', (tester) async {
    final businessesController = Completer<List<Business>>();
    final location = await _pumpAndGo(
      tester,
      overrides: [
        authSessionStateProvider.overrideWith(
          (ref) => Stream.value(const AuthSessionState(userId: 'user-1')),
        ),
        userBusinessesProvider.overrideWith(
          (ref) => businessesController.future,
        ),
      ],
      go: AppRoutes.dashboard,
      awaitBusinesses: false,
    );
    addTearDown(() => businessesController.complete(const []));

    expect(location, AppRoutes.startup);
  });

  testWidgets('işletmeler hata verirse startup’a yönlendirilir', (
    tester,
  ) async {
    final location = await _pumpAndGo(
      tester,
      overrides: [
        authSessionStateProvider.overrideWith(
          (ref) => Stream.value(const AuthSessionState(userId: 'user-1')),
        ),
        userBusinessesProvider.overrideWith(
          (ref) async => throw Exception('business-error'),
        ),
      ],
      go: AppRoutes.dashboard,
      awaitBusinesses: false,
    );

    expect(location, AppRoutes.startup);
  });

  testWidgets('işletme yoksa onboarding’e yönlendirilir', (tester) async {
    final location = await _pumpAndGo(
      tester,
      overrides: [
        authSessionStateProvider.overrideWith(
          (ref) => Stream.value(const AuthSessionState(userId: 'user-1')),
        ),
        userBusinessesProvider.overrideWith((ref) async => const []),
      ],
      go: AppRoutes.dashboard,
    );

    expect(location, AppRoutes.onboarding);
  });

  testWidgets('işletme yoksa onboarding sayfasında kalınır', (tester) async {
    final location = await _pumpAndGo(
      tester,
      overrides: [
        authSessionStateProvider.overrideWith(
          (ref) => Stream.value(const AuthSessionState(userId: 'user-1')),
        ),
        userBusinessesProvider.overrideWith((ref) async => const []),
      ],
      go: AppRoutes.onboarding,
    );

    expect(location, AppRoutes.onboarding);
  });

  testWidgets('işletme varken iş dışı bir sayfa dashboard’a yönlendirilir', (
    tester,
  ) async {
    final location = await _pumpAndGo(
      tester,
      overrides: [
        authSessionStateProvider.overrideWith(
          (ref) => Stream.value(const AuthSessionState(userId: 'user-1')),
        ),
        userBusinessesProvider.overrideWith((ref) async => [_business()]),
      ],
      go: AppRoutes.onboarding,
    );

    expect(location, AppRoutes.dashboard);
  });

  testWidgets('işletme varken seans sayfası korumasız erişilebilir kalır', (
    tester,
  ) async {
    final location = await _pumpAndGo(
      tester,
      overrides: [
        authSessionStateProvider.overrideWith(
          (ref) => Stream.value(const AuthSessionState(userId: 'user-1')),
        ),
        userBusinessesProvider.overrideWith((ref) async => [_business()]),
      ],
      go: AppRoutes.sessionStart,
    );

    expect(location, AppRoutes.sessionStart);
  });
}

Future<String> _pumpAndGo(
  WidgetTester tester, {
  required List<Override> overrides,
  required String go,
  bool awaitAuth = true,
  bool awaitBusinesses = true,
}) async {
  final container = ProviderContainer(overrides: overrides);
  addTearDown(container.dispose);

  if (awaitAuth) {
    await container.read(authSessionStateProvider.future);
  }
  if (awaitBusinesses) {
    await container.read(userBusinessesProvider.future);
  }

  final router = container.read(appRouterProvider)..go(go);
  addTearDown(router.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  // Yönlendirme birden fazla mikro görevde çözülebilir (auth/işletme
  // stream'leri); sayfa içeriğinin ağ bağımlı yüklenmesini beklemeden
  // (ör. dashboard) sonlanmayan animasyonlarla `pumpAndSettle` kilitlenmesin
  // diye sınırlı sayıda `pump` yeterlidir.
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }

  return router.routerDelegate.currentConfiguration.uri.toString();
}

Business _business() => Business(
  id: 'business-1',
  name: 'Test İşletmesi',
  currencyCode: 'TRY',
  timezone: 'Europe/Istanbul',
  isActive: true,
  archivedAt: null,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);
