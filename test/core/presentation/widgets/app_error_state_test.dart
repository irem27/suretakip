import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suretakip/core/errors/domain_exception.dart';
import 'package:suretakip/core/presentation/widgets/app_error_state.dart';

void main() {
  testWidgets('ağ hatası dar ekranda büyük metinle taşmadan gösterilir', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(240, 320);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: AppErrorState(
              error: NetworkException(
                'İnternet bağlantısı yok gibi görünüyor. '
                'Bağlantınızı kontrol edip tekrar deneyin.',
              ),
              fallbackMessage: 'Yüklenemedi.',
              onRetry: _noop,
            ),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);
    expect(find.text('Çevrimdışı moddasınız.'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Yenile'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

void _noop() {}
