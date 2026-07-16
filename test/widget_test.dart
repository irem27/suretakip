import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:menusayac/app/app.dart';
import 'package:menusayac/features/auth/presentation/pages/login_page.dart';

void main() {
  testWidgets('renders login screen', (WidgetTester tester) async {
    final testRouter = GoRouter(
      initialLocation: '/login',
      routes: [
        GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      ],
    );

    await tester.pumpWidget(App(routerOverride: testRouter));
    await tester.pumpAndSettle();

    expect(find.text('Menü Sayaç'), findsWidgets);
    expect(find.text('Giriş Yap'), findsOneWidget);
  });
}
