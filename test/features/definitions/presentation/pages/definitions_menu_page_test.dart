import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:suretakip/app/router/app_routes.dart';
import 'package:suretakip/features/definitions/presentation/pages/definitions_menu_page.dart';

void main() {
  testWidgets('tanım kartları açıklamalarıyla birlikte görünür', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.text('Tanımlar'), findsOneWidget);
    expect(
      find.text(
        'İşletmenizde kullandığınız hizmet, ürün ve müşteri kayıtlarını yönetin.',
      ),
      findsOneWidget,
    );
    expect(
      find.text('Hizmet türlerini ve dakika fiyatlarını belirleyin.'),
      findsOneWidget,
    );
    expect(
      find.text('Satış ürünlerini, fiyatlarını ve stoklarını yönetin.'),
      findsOneWidget,
    );
    expect(
      find.text('Müşteri iletişim bilgilerini ve durumlarını yönetin.'),
      findsOneWidget,
    );
    expect(
      tester.getSize(find.widgetWithText(InkWell, 'Hizmetler')).height,
      greaterThanOrEqualTo(48),
    );
  });

  for (final routeCase in const [
    (label: 'Hizmetler', target: 'Hizmetler hedefi'),
    (label: 'Ürünler', target: 'Ürünler hedefi'),
    (label: 'Müşteriler', target: 'Müşteriler hedefi'),
  ]) {
    testWidgets('${routeCase.label} kartı doğru ekrana gider', (tester) async {
      await _pump(tester);

      await tester.tap(find.text(routeCase.label));
      await tester.pumpAndSettle();

      expect(find.text(routeCase.target), findsOneWidget);
    });
  }
}

Future<void> _pump(WidgetTester tester) async {
  final router = GoRouter(
    initialLocation: AppRoutes.definitions,
    routes: [
      GoRoute(
        path: AppRoutes.definitions,
        builder: (_, _) => const DefinitionsMenuPage(),
      ),
      GoRoute(
        name: AppRouteNames.services,
        path: AppRoutes.services,
        builder: (_, _) => const Scaffold(body: Text('Hizmetler hedefi')),
      ),
      GoRoute(
        name: AppRouteNames.products,
        path: AppRoutes.products,
        builder: (_, _) => const Scaffold(body: Text('Ürünler hedefi')),
      ),
      GoRoute(
        name: AppRouteNames.customers,
        path: AppRoutes.customers,
        builder: (_, _) => const Scaffold(body: Text('Müşteriler hedefi')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pumpAndSettle();
}
