import 'dart:convert';

import 'package:suretakip/core/sync/models/sync_enums.dart';

/// Bir outbox kaydının sunucuya gönderilmesinin sonucu. `create_customer`
/// RPC'sinin döndürdüğü `result`/`error_code` sözleşmesinden türetilir.
final class SyncPushResult {
  const SyncPushResult({
    required this.type,
    this.errorCode,
    this.serverVersion,
    this.createdAtServer,
    this.updatedAtServer,
  });

  final SyncResultType type;
  final String? errorCode;
  final int? serverVersion;
  final DateTime? createdAtServer;
  final DateTime? updatedAtServer;

  bool get isSuccess =>
      type == SyncResultType.applied || type == SyncResultType.alreadyProcessed;
}

/// Sunucu RPC'lerinin ortak `result`/`error_code` zarfını [SyncPushResult]'a
/// çevirir (Bölüm 7.3.3). create_customer, sync_start_session ve
/// sync_session_event aynı sözleşmeyi paylaşır.
SyncPushResult parseSyncResult(Object? response) {
  final map = response is String
      ? jsonDecode(response) as Map<String, Object?>
      : (response as Map).cast<String, Object?>();

  switch (map['result'] as String?) {
    case 'applied':
      return SyncPushResult(
        type: SyncResultType.applied,
        serverVersion: _asInt(map['server_version']),
        createdAtServer: _asDate(map['created_at_server']),
        updatedAtServer: _asDate(map['updated_at_server']),
      );
    case 'already_processed':
      return SyncPushResult(
        type: SyncResultType.alreadyProcessed,
        serverVersion: _asInt(map['server_version']),
        createdAtServer: _asDate(map['created_at_server']),
        updatedAtServer: _asDate(map['updated_at_server']),
      );
    case 'auth_required':
      return const SyncPushResult(type: SyncResultType.authRequired);
    case 'conflict':
      return SyncPushResult(
        type: SyncResultType.conflict,
        errorCode: map['error_code'] as String?,
      );
    case 'rejected':
    default:
      return SyncPushResult(
        type: SyncResultType.rejected,
        errorCode: map['error_code'] as String? ?? 'UNKNOWN_RESULT',
      );
  }
}

int? _asInt(Object? value) => value is int
    ? value
    : (value is num ? value.toInt() : int.tryParse('$value'));

DateTime? _asDate(Object? value) =>
    value is String ? DateTime.tryParse(value)?.toUtc() : null;
