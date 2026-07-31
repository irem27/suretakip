import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:suretakip/core/logging/app_logger.dart';
import 'package:suretakip/core/logging/noop_app_logger.dart';

typedef SyncPushTrigger = Future<void> Function();
typedef InitialConnectivityCheck = Future<List<ConnectivityResult>> Function();

/// Uygulama yaşam döngüsü ve bağlantı sinyallerini SyncEngine push denemesine
/// çevirir. Connectivity yalnız tetikleyicidir; erişilebilirlik ve auth kararı
/// SyncEngine içindeki gerçek sunucu çağrılarıyla verilir.
final class SyncTriggerService with WidgetsBindingObserver {
  SyncTriggerService({
    required Stream<List<ConnectivityResult>> connectivityChanges,
    required SyncPushTrigger push,
    InitialConnectivityCheck? initialConnectivity,
    AppLogger logger = const NoopAppLogger(),
  }) : _connectivityChanges = connectivityChanges,
       _push = push,
       _initialConnectivity = initialConnectivity,
       _logger = logger;

  final Stream<List<ConnectivityResult>> _connectivityChanges;
  final SyncPushTrigger _push;
  final InitialConnectivityCheck? _initialConnectivity;
  final AppLogger _logger;

  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool? _hadConnectivity;
  Future<void>? _inFlight;
  bool _rerunRequested = false;

  void start() {
    if (_subscription != null) return;
    WidgetsBinding.instance.addObserver(this);
    _subscription = _connectivityChanges.listen(_onConnectivityChanged);
    final initialConnectivity = _initialConnectivity;
    if (initialConnectivity == null) {
      unawaited(trigger());
    } else {
      unawaited(_checkInitialConnectivity(initialConnectivity));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(trigger());
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    final hasConnectivity = results.any(
      (result) => result != ConnectivityResult.none,
    );
    if (hasConnectivity && _hadConnectivity == false) unawaited(trigger());
    _hadConnectivity = hasConnectivity;
  }

  Future<void> _checkInitialConnectivity(
    InitialConnectivityCheck initialConnectivity,
  ) async {
    try {
      final results = await initialConnectivity();
      final hasConnectivity = results.any(
        (result) => result != ConnectivityResult.none,
      );
      _hadConnectivity = hasConnectivity;
      if (hasConnectivity) await trigger();
    } catch (error, stack) {
      _logger.warn(
        error,
        stackTrace: stack,
        context: 'SyncInitialConnectivity',
      );
      // Connectivity yalnızca bir ipucudur. Kontrol mekanizmasının kendi
      // hatası, gerçek sunucu çağrısının denenmesini engellememeli.
      await trigger();
    }
  }

  /// Aktif işletme gibi bir senkronizasyon önkoşulu sonradan hazır olduğunda
  /// koordinatör tarafından açıkça çağrılabilir.
  Future<void> trigger() {
    _rerunRequested = true;
    return _inFlight ??= _drainTriggers();
  }

  Future<void> _drainTriggers() async {
    try {
      while (_rerunRequested) {
        _rerunRequested = false;
        try {
          await _push();
        } catch (error, stack) {
          _logger.warn(error, stackTrace: stack, context: 'SyncTrigger');
        }
      }
    } finally {
      _inFlight = null;
    }
  }

  Future<void> dispose() async {
    WidgetsBinding.instance.removeObserver(this);
    final subscription = _subscription;
    _subscription = null;
    await subscription?.cancel();
  }
}
