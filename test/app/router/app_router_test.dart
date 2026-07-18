import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suretakip/app/providers/app_providers.dart';
import 'package:suretakip/app/router/app_router.dart';
import 'package:suretakip/app/router/app_routes.dart';
import 'package:suretakip/core/domain/domain_enums.dart';
import 'package:suretakip/features/auth/domain/entities/auth_session_state.dart';
import 'package:suretakip/features/businesses/domain/entities/business.dart';
import 'package:suretakip/features/businesses/domain/entities/business_capabilities.dart';

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

  testWidgets('owner katalog oluşturma route’una erişir', (tester) async {
    await _pumpCatalogRoute(
      tester,
      role: MemberRole.owner,
      location: AppRoutes.serviceCreate,
    );

    expect(find.text('Yeni Hizmet'), findsOneWidget);
    expect(find.text('Yetkiniz yok'), findsNothing);
  });

  testWidgets('admin katalog oluşturma route’una erişir', (tester) async {
    await _pumpCatalogRoute(
      tester,
      role: MemberRole.admin,
      location: AppRoutes.productCreate,
    );

    expect(find.text('Yeni Ürün'), findsOneWidget);
    expect(find.text('Yetkiniz yok'), findsNothing);
  });

  testWidgets('staff katalog yazma deep-linkinde izin ekranını görür', (
    tester,
  ) async {
    await _pumpCatalogRoute(
      tester,
      role: MemberRole.staff,
      location: AppRoutes.serviceCreate,
    );

    expect(find.text('Yetkiniz yok'), findsOneWidget);
    expect(
      find.text('Bu işlem için işletme yöneticisi yetkisi gerekiyor.'),
      findsOneWidget,
    );
  });
}

Future<void> _pumpCatalogRoute(
  WidgetTester tester, {
  required MemberRole role,
  required String location,
}) async {
  final container = ProviderContainer(
    overrides: [
      authSessionStateProvider.overrideWith(
        (ref) => Stream.value(const AuthSessionState(userId: 'user-1')),
      ),
      currentUserProvider.overrideWithValue(null),
      userBusinessesProvider.overrideWith((ref) async => [_business()]),
      businessCapabilitiesProvider.overrideWithValue(
        AsyncData(BusinessCapabilities.forRole(role)),
      ),
    ],
  );
  await container.read(authSessionStateProvider.future);
  await container.read(userBusinessesProvider.future);
  final router = container.read(appRouterProvider)..go(location);
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
