import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';

typedef SyncPushTrigger = Future<void> Function();

/// Uygulama yaşam döngüsü ve bağlantı sinyallerini SyncEngine push denemesine
/// çevirir. Connectivity yalnız tetikleyicidir; erişilebilirlik ve auth kararı
/// SyncEngine içindeki gerçek sunucu çağrılarıyla verilir.
final class SyncTriggerService with WidgetsBindingObserver {
  SyncTriggerService({
    required Stream<List<ConnectivityResult>> connectivityChanges,
    required SyncPushTrigger push,
  }) : _connectivityChanges = connectivityChanges,
       _push = push;

  final Stream<List<ConnectivityResult>> _connectivityChanges;
  final SyncPushTrigger _push;

  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool? _hadConnectivity;

  void start() {
    if (_subscription != null) return;
    WidgetsBinding.instance.addObserver(this);
    _subscription = _connectivityChanges.listen(_onConnectivityChanged);
    _triggerPush();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _triggerPush();
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    final hasConnectivity = results.any(
      (result) => result != ConnectivityResult.none,
    );
    if (hasConnectivity && _hadConnectivity == false) _triggerPush();
    _hadConnectivity = hasConnectivity;
  }

  void _triggerPush() {
    unawaited(_push().catchError(_ignorePushError));
  }

  Future<void> dispose() async {
    WidgetsBinding.instance.removeObserver(this);
    final subscription = _subscription;
    _subscription = null;
    await subscription?.cancel();
  }

  static Future<void> _ignorePushError(Object _, StackTrace _) async {}
}
