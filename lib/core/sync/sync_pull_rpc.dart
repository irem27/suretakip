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
    return parseChangesPage(response, cursor: cursor);
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
    return parseCustomerSnapshotPage(response);
  }
}

/// RPC sözleşmesinin yalnız açıkça tanımlanmış sonuçlarını kabul eder.
///
/// Eksik/bilinmeyen `result` değerleri başarı sayılmaz. Böylece yeni veya
/// bozuk bir sunucu cevabı boş snapshot gibi yorumlanıp yerel veriyi
/// tombstone edemez.
ChangesPage parseChangesPage(Object? response, {required int cursor}) {
  final map = _asResponseMap(response);
  switch (map['result']) {
    case 'auth_required':
      return const ChangesPage.authRequired();
    case 'rejected':
      if (map['error_code'] == 'CURSOR_TOO_OLD') {
        return const ChangesPage.cursorTooOld();
      }
      throw StateError('get_changes reddedildi: ${map['error_code']}');
    case 'ok':
      final rawChanges = _mapList(map['changes'], field: 'changes');
      return ChangesPage(
        changes: rawChanges.map(_change).toList(growable: false),
        nextCursor: _requiredInt(map['next_cursor'], field: 'next_cursor'),
        hasMore: _requiredBool(map['has_more'], field: 'has_more'),
      );
    default:
      throw const FormatException('Bilinmeyen get_changes sonucu.');
  }
}

CustomerSnapshotPage parseCustomerSnapshotPage(Object? response) {
  final map = _asResponseMap(response);
  switch (map['result']) {
    case 'auth_required':
      return const CustomerSnapshotPage.authRequired();
    case 'rejected':
      // FORBIDDEN dahil her ret: merge/tombstone YAPMA (veri kaybını önler).
      return const CustomerSnapshotPage.rejected();
    case 'ok':
      final rawCustomers = _mapList(map['customers'], field: 'customers');
      return CustomerSnapshotPage(
        customers: rawCustomers.map(_snapshotCustomer).toList(growable: false),
        nextAfterId: map['next_after_id'] as String?,
        hasMore: _requiredBool(map['has_more'], field: 'has_more'),
        serverCursor: _requiredInt(
          map['server_cursor'],
          field: 'server_cursor',
        ),
      );
    default:
      throw const FormatException('Bilinmeyen müşteri snapshot sonucu.');
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

Map<String, dynamic> _asResponseMap(Object? response) {
  final decoded = response is String ? jsonDecode(response) : response;
  if (decoded is! Map) {
    throw const FormatException('RPC cevabı nesne olmalıdır.');
  }
  return decoded.cast<String, dynamic>();
}

List<Map<String, dynamic>> _mapList(Object? value, {required String field}) {
  if (value is! List) throw FormatException('$field liste olmalıdır.');
  return value
      .map((item) {
        if (item is! Map) {
          throw FormatException('$field öğesi nesne olmalıdır.');
        }
        return item.cast<String, dynamic>();
      })
      .toList(growable: false);
}

int _requiredInt(Object? value, {required String field}) {
  final parsed = _asInt(value);
  if (parsed == null) throw FormatException('$field tam sayı olmalıdır.');
  return parsed;
}

bool _requiredBool(Object? value, {required String field}) {
  if (value is! bool) throw FormatException('$field boolean olmalıdır.');
  return value;
}

int? _asInt(Object? value) => value is int
    ? value
    : (value is num ? value.toInt() : int.tryParse('$value'));

DateTime _date(Object? value) {
  if (value is DateTime) return value;
  if (value is String) return DateTime.parse(value);
  throw const FormatException('Geçersiz zaman damgası.');
}
