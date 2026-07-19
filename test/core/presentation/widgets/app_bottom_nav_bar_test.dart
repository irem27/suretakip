import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:suretakip/app/router/app_routes.dart';
import 'package:suretakip/app/theme/app_theme.dart';
import 'package:suretakip/core/presentation/widgets/app_bottom_nav_bar.dart';

void main() {
  const expectedLabels = [
    'Ana Sayfa',
    'İşlemler',
    'Müşteriler',
    'Tanımlar',
    'Raporlar',
  ];

  testWidgets('tam olarak beş hedefi doğru Türkçe sırayla gösterir', (
    tester,
  ) async {
    await _pumpBar(tester);

    final destinations = tester.widgetList<NavigationDestination>(
      find.byType(NavigationDestination),
    );

    expect(destinations, hasLength(5));
    expect(
      destinations.map((destination) => destination.label),
      orderedEquals(expectedLabels),
    );
    expect(
      AppSection.values.map((section) => section.label),
      orderedEquals(expectedLabels),
    );
  });

  for (final themeCase in [
    (name: 'açık', theme: AppTheme.light()),
    (name: 'koyu', theme: AppTheme.dark()),
  ]) {
    testWidgets(
      '${themeCase.name} temada seçili gösterge secondary renk jetonunu kullanır',
      (tester) async {
        await _pumpBar(tester, theme: themeCase.theme);

        final colorScheme = themeCase.theme.colorScheme;
        final navigationTheme = themeCase.theme.navigationBarTheme;
        const selected = {WidgetState.selected};
        const unselected = <WidgetState>{};

        expect(navigationTheme.indicatorColor, colorScheme.secondary);
        expect(navigationTheme.indicatorShape, const StadiumBorder());
        expect(
          navigationTheme.iconTheme?.resolve(selected)?.color,
          colorScheme.onSecondary,
        );
        expect(
          navigationTheme.iconTheme?.resolve(unselected)?.color,
          colorScheme.onSurfaceVariant,
        );
        expect(
          navigationTheme.labelTextStyle?.resolve(selected)?.color,
          colorScheme.onSurface,
        );
        expect(
          tester
              .widgetList<NavigationIndicator>(find.byType(NavigationIndicator))
              .map((indicator) => indicator.color),
          everyElement(colorScheme.secondary),
        );
      },
    );
  }

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

      await tester.tap(find.text(section.label));
      await tester.pumpAndSettle();

      expect(router.routeInformationProvider.value.uri.path, _pathFor(section));
      expect(find.byKey(ValueKey(section.routeName)), findsOneWidget);
      expect(router.canPop(), isFalse);
    });
  }

  testWidgets('320 piksel genişlikte etiketler taşmadan görünür', (
    tester,
  ) async {
    await _setCompactSurface(tester);
    await _pumpBar(tester);

    _expectNoLayoutOverflow(tester, expectedLabels);
  });

  testWidgets('2.0 metin ölçeğinde etiketler taşmadan görünür', (tester) async {
    await _setCompactSurface(tester);
    await _pumpBar(tester, textScaler: const TextScaler.linear(2));

    _expectNoLayoutOverflow(tester, expectedLabels);
  });

  testWidgets('her hedef etiketi ve seçili durumunu semantik olarak sunar', (
    tester,
  ) async {
    await _pumpBar(tester);

    for (final section in AppSection.values) {
      final data = tester
          .getSemantics(find.text(section.label))
          .getSemanticsData();

      expect(data.label, startsWith(section.label));
      expect(
        data.flagsCollection.isSelected,
        section == AppSection.definitions ? Tristate.isTrue : Tristate.isFalse,
      );
      expect(data.rect.height, greaterThanOrEqualTo(48));
    }
  });

  for (final deepRoute in [
    (path: '/customers/customer-42', section: AppSection.customers),
    (path: '/sessions/session-42', section: AppSection.sessions),
  ]) {
    testWidgets(
      '${deepRoute.path} deep linki doğru üst hedefi seçer ve kök yığını büyütmez',
      (tester) async {
        final router = _navigationRouter(initialLocation: deepRoute.path);
        addTearDown(router.dispose);
        await tester.pumpWidget(
          MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
        );
        await tester.pumpAndSettle();

        final navigationBar = tester.widget<NavigationBar>(
          find.byType(NavigationBar),
        );
        expect(navigationBar.selectedIndex, deepRoute.section.index);

        await tester.tap(find.text(AppSection.dashboard.label));
        await tester.pumpAndSettle();

        expect(
          router.routeInformationProvider.value.uri.path,
          AppRoutes.dashboard,
        );
        expect(router.canPop(), isFalse);
      },
    );
  }
}

Future<void> _pumpBar(
  WidgetTester tester, {
  ThemeData? theme,
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme ?? AppTheme.light(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: child!,
      ),
      home: const Scaffold(
        bottomNavigationBar: AppBottomNavBar(current: AppSection.definitions),
      ),
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

void _expectNoLayoutOverflow(WidgetTester tester, List<String> expectedLabels) {
  expect(tester.takeException(), isNull);
  expect(
    tester.getSize(find.byType(NavigationBar)).height,
    greaterThanOrEqualTo(48),
  );

  for (final label in expectedLabels) {
    final rect = tester.getRect(find.text(label));
    expect(rect.left, greaterThanOrEqualTo(0));
    expect(rect.right, lessThanOrEqualTo(320));
    expect(rect.width, lessThanOrEqualTo(320 / expectedLabels.length));
  }
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
    GoRoute(
      path: '/customers/:customerId',
      builder: (_, _) => const _NavigationScaffold(
        section: AppSection.customers,
        marker: 'customer-detail',
      ),
    ),
    GoRoute(
      path: '/sessions/:sessionId',
      builder: (_, _) => const _NavigationScaffold(
        section: AppSection.sessions,
        marker: 'session-detail',
      ),
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
