import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suretakip/core/sync/sync_trigger_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('startup foreground ve bağlantı dönüşü push tetikler', () async {
    final connectivity = StreamController<List<ConnectivityResult>>();
    addTearDown(connectivity.close);
    var pushCount = 0;
    final service = SyncTriggerService(
      connectivityChanges: connectivity.stream,
      push: () async => pushCount++,
    );
    addTearDown(service.dispose);

    service.start();
    await _flushEvents();
    expect(pushCount, 1, reason: 'uygulama açılışı');

    service.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await _flushEvents();
    expect(pushCount, 2, reason: 'foreground dönüşü');

    connectivity.add(const [ConnectivityResult.none]);
    await _flushEvents();
    connectivity.add(const [ConnectivityResult.wifi]);
    await _flushEvents();
    expect(pushCount, 3, reason: 'bağlantı geri geldi');

    connectivity.add(const [ConnectivityResult.wifi]);
    await _flushEvents();
    expect(pushCount, 3, reason: 'aynı bağlantı sinyali tekrarlandı');
  });
}

Future<void> _flushEvents() => Future<void>.delayed(Duration.zero);
