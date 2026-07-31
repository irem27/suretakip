import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:suretakip/app/router/app_routes.dart';
import 'package:suretakip/app/theme/app_theme.dart';
import 'package:suretakip/core/presentation/widgets/app_bottom_nav_bar.dart';

void main() {
  // Ana Sayfa ortadaki dairesel butondur; yan bölümler etiketli öğelerdir.
  const sideLabels = ['İşlemler', 'Müşteriler', 'Tanımlar', 'Raporlar'];

  testWidgets('dört yan bölüm etiketli, Ana Sayfa dairesel buton olarak durur', (
    tester,
  ) async {
    await _pumpBar(tester);

    for (final label in sideLabels) {
      expect(find.text(label), findsOneWidget);
    }
    // Ortadaki Ana Sayfa butonu ikon + semantik ile sunulur, metin etiketi yok.
    expect(find.text('Ana Sayfa'), findsNothing);
    expect(find.byIcon(Icons.home_rounded), findsOneWidget);
    expect(find.bySemanticsLabel('Ana Sayfa'), findsOneWidget);
  });

  for (final section in AppSection.values) {
    testWidgets('${section.label} hedefi doğru named route’a gider', (
      tester,
    ) async {
      final router = _navigationRouter(
        hostSection: section == AppSection.dashboard
            ? AppSection.sessions
            : AppSection.dashboard,
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
      );
      await tester.pumpAndSettle();

      // Ana Sayfa ikonla, diğerleri etiketle tıklanır.
      final finder = section == AppSection.dashboard
          ? find.byIcon(Icons.home_rounded)
          : find.text(section.label);
      await tester.tap(finder);
      await tester.pumpAndSettle();

      expect(router.routeInformationProvider.value.uri.path, _pathFor(section));
      expect(find.byKey(ValueKey(section.routeName)), findsOneWidget);
      expect(router.canPop(), isFalse);
    });
  }

  testWidgets('320 piksel genişlikte taşma olmadan yerleşir', (tester) async {
    await _setCompactSurface(tester);
    await _pumpBar(tester);

    expect(tester.takeException(), isNull);
    for (final label in sideLabels) {
      final rect = tester.getRect(find.text(label));
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(320));
    }
  });

  testWidgets('2.0 metin ölçeğinde taşma olmadan yerleşir', (tester) async {
    await _setCompactSurface(tester);
    await _pumpBar(tester, textScaler: const TextScaler.linear(2));

    expect(tester.takeException(), isNull);
  });

  testWidgets('Ana Sayfa butonu seçili durumu semantik olarak sunar', (
    tester,
  ) async {
    await _pumpBar(tester, current: AppSection.dashboard);

    final data = tester
        .getSemantics(find.bySemanticsLabel('Ana Sayfa'))
        .getSemanticsData();
    expect(data.label, 'Ana Sayfa');
  });
}

Future<void> _pumpBar(
  WidgetTester tester, {
  ThemeData? theme,
  TextScaler textScaler = TextScaler.noScaling,
  AppSection current = AppSection.definitions,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme ?? AppTheme.light(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: child!,
      ),
      home: Scaffold(bottomNavigationBar: AppBottomNavBar(current: current)),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _setCompactSurface(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(320, 640);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

GoRouter _navigationRouter({
  String initialLocation = '/host',
  AppSection hostSection = AppSection.definitions,
}) => GoRouter(
  initialLocation: initialLocation,
  routes: [
    GoRoute(
      path: '/host',
      builder: (_, _) =>
          _NavigationScaffold(section: hostSection, marker: 'host'),
    ),
    for (final section in AppSection.values)
      GoRoute(
        name: section.routeName,
        path: _pathFor(section),
        builder: (_, _) =>
            _NavigationScaffold(section: section, marker: section.routeName),
      ),
  ],
);

String _pathFor(AppSection section) => switch (section) {
  AppSection.dashboard => AppRoutes.dashboard,
  AppSection.sessions => AppRoutes.sessions,
  AppSection.customers => AppRoutes.customers,
  AppSection.definitions => AppRoutes.definitions,
  AppSection.reports => AppRoutes.reports,
};

class _NavigationScaffold extends StatelessWidget {
  const _NavigationScaffold({required this.section, required this.marker});

  final AppSection section;
  final String marker;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SizedBox(key: ValueKey(marker)),
    bottomNavigationBar: AppBottomNavBar(current: section),
  );
}
