import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suretakip/core/logging/app_logger.dart';
import 'package:suretakip/core/sync/sync_trigger_service.dart';

final class _RecordingLogger implements AppLogger {
  final warnings = <Object>[];

  @override
  void error(Object error, {StackTrace? stackTrace, String? context}) {}

  @override
  void info(Object message, {String? context}) {}

  @override
  void warn(Object warning, {StackTrace? stackTrace, String? context}) {
    warnings.add(warning);
  }
}

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

  test('ilk bağlantı kontrolü çevrimiçiyse senkronizasyonu tetikler', () async {
    final connectivity = StreamController<List<ConnectivityResult>>();
    addTearDown(connectivity.close);
    var pushCount = 0;
    final service = SyncTriggerService(
      connectivityChanges: connectivity.stream,
      initialConnectivity: () async => const [ConnectivityResult.mobile],
      push: () async => pushCount++,
    );
    addTearDown(service.dispose);

    service.start();
    await _flushEvents();
    await _flushEvents();

    expect(pushCount, 1);
  });

  test(
    'ilk bağlantı kontrolü hata verirse yine senkronizasyonu dener ve loglar',
    () async {
      final connectivity = StreamController<List<ConnectivityResult>>();
      addTearDown(connectivity.close);
      final logger = _RecordingLogger();
      var pushCount = 0;
      final service = SyncTriggerService(
        connectivityChanges: connectivity.stream,
        initialConnectivity: () async => throw StateError('check failed'),
        push: () async => pushCount++,
        logger: logger,
      );
      addTearDown(service.dispose);

      service.start();
      await _flushEvents();
      await _flushEvents();

      expect(pushCount, 1);
      expect(logger.warnings, hasLength(1));
    },
  );

  test('işletme hazır olduğunda açık tetik yeniden çalıştırılabilir', () async {
    final connectivity = StreamController<List<ConnectivityResult>>();
    addTearDown(connectivity.close);
    var pushCount = 0;
    final service = SyncTriggerService(
      connectivityChanges: connectivity.stream,
      initialConnectivity: () async => const [ConnectivityResult.none],
      push: () async => pushCount++,
    );
    addTearDown(service.dispose);

    service.start();
    await _flushEvents();
    await service.trigger();

    expect(pushCount, 1);
  });

  test('arka plan senkronizasyon hatasını logger ile görünür kılar', () async {
    final connectivity = StreamController<List<ConnectivityResult>>();
    addTearDown(connectivity.close);
    final logger = _RecordingLogger();
    final service = SyncTriggerService(
      connectivityChanges: connectivity.stream,
      initialConnectivity: () async => const [ConnectivityResult.wifi],
      push: () async => throw StateError('sync failed'),
      logger: logger,
    );
    addTearDown(service.dispose);

    service.start();
    await _flushEvents();
    await _flushEvents();

    expect(logger.warnings, hasLength(1));
  });

  test(
    'eşzamanlı tetikler üst üste binmez, bir takip turunda birleşir',
    () async {
      final connectivity = StreamController<List<ConnectivityResult>>();
      addTearDown(connectivity.close);
      final firstRun = Completer<void>();
      var pushCount = 0;
      var activePushes = 0;
      var maxActivePushes = 0;
      final service = SyncTriggerService(
        connectivityChanges: connectivity.stream,
        initialConnectivity: () async => const [ConnectivityResult.none],
        push: () async {
          pushCount++;
          activePushes++;
          if (activePushes > maxActivePushes) maxActivePushes = activePushes;
          if (pushCount == 1) await firstRun.future;
          activePushes--;
        },
      );
      addTearDown(service.dispose);

      service.start();
      final first = service.trigger();
      final second = service.trigger();
      await _flushEvents();
      expect(pushCount, 1);

      firstRun.complete();
      await Future.wait([first, second]);

      expect(pushCount, 2);
      expect(maxActivePushes, 1);
    },
  );
}

Future<void> _flushEvents() => Future<void>.delayed(Duration.zero);
