import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:suretakip/core/sync/models/delta_models.dart';
import 'package:suretakip/features/customers/data/local/customers_local_data_source.dart';

/// Delta pull ve bootstrap RPC sözleşmesi (Bölüm 7.3.4). Test için fake edilir.
abstract interface class SyncPullApi {
  Future<ChangesPage> getChanges({
    required String businessId,
    required int cursor,
    int limit,
  });

  Future<CustomerSnapshotPage> getCustomersSnapshot({
    required String businessId,
    String? afterId,
    int limit,
  });
}

/// `get_changes` ve `get_customers_snapshot` Supabase RPC'lerini çağırır.
class SyncPullRpc implements SyncPullApi {
  const SyncPullRpc(this._client);

  final SupabaseClient _client;

  @override
  Future<ChangesPage> getChanges({
    required String businessId,
    required int cursor,
    int limit = 500,
  }) async {
    final response = await _client.rpc<Object?>(
      'get_changes',
      params: {
        'p_business_id': businessId,
        'p_cursor': cursor,
        'p_limit': limit,
      },
    );
    final map = _asMap(response);
    switch (map['result'] as String?) {
      case 'auth_required':
        return const ChangesPage.authRequired();
      case 'rejected':
        if (map['error_code'] == 'CURSOR_TOO_OLD') {
          return const ChangesPage.cursorTooOld();
        }
        throw StateError('get_changes reddedildi: ${map['error_code']}');
      case 'ok':
      default:
        final rawChanges = (map['changes'] as List? ?? const [])
            .cast<Map<String, dynamic>>();
        return ChangesPage(
          changes: rawChanges.map(_change).toList(growable: false),
          nextCursor: _asInt(map['next_cursor']) ?? cursor,
          hasMore: map['has_more'] as bool? ?? false,
        );
    }
  }

  @override
  Future<CustomerSnapshotPage> getCustomersSnapshot({
    required String businessId,
    String? afterId,
    int limit = 500,
  }) async {
    final response = await _client.rpc<Object?>(
      'get_customers_snapshot',
      params: {
        'p_business_id': businessId,
        'p_after_id': afterId,
        'p_limit': limit,
      },
    );
    final map = _asMap(response);
    switch (map['result'] as String?) {
      case 'auth_required':
        return const CustomerSnapshotPage.authRequired();
      case 'rejected':
        // FORBIDDEN dahil her ret: merge/tombstone YAPMA (veri kaybını önler).
        return const CustomerSnapshotPage.rejected();
      case 'ok':
      default:
        final rawCustomers = (map['customers'] as List? ?? const [])
            .cast<Map<String, dynamic>>();
        return CustomerSnapshotPage(
          customers: rawCustomers
              .map(_snapshotCustomer)
              .toList(growable: false),
          nextAfterId: map['next_after_id'] as String?,
          hasMore: map['has_more'] as bool? ?? false,
          serverCursor: _asInt(map['server_cursor']) ?? 0,
        );
    }
  }

  SyncChange _change(Map<String, dynamic> json) => SyncChange(
    changeSeq: _asInt(json['change_seq']) ?? 0,
    entityType: json['entity_type'] as String,
    entityId: json['entity_id'] as String,
    operation: json['operation'] as String,
    serverVersion: _asInt(json['server_version']) ?? 0,
    payload: json['payload'] == null
        ? null
        : (json['payload'] as Map).cast<String, dynamic>(),
  );

  ServerCustomerSnapshot _snapshotCustomer(Map<String, dynamic> json) =>
      ServerCustomerSnapshot(
        id: json['id'] as String,
        businessId: json['business_id'] as String,
        name: json['name'] as String,
        phone: json['phone'] as String?,
        email: json['email'] as String?,
        notes: json['notes'] as String?,
        isActive: json['is_active'] as bool,
        serverVersion: _asInt(json['server_version']) ?? 1,
        createdAt: _date(json['created_at']),
        updatedAt: _date(json['updated_at']),
      );

  Map<String, dynamic> _asMap(Object? response) => response is String
      ? jsonDecode(response) as Map<String, dynamic>
      : (response as Map).cast<String, dynamic>();

  int? _asInt(Object? value) => value is int
      ? value
      : (value is num ? value.toInt() : int.tryParse('$value'));

  DateTime _date(Object? value) {
    if (value is DateTime) return value;
    if (value is String) return DateTime.parse(value);
    throw const FormatException('Geçersiz zaman damgası.');
  }
}
