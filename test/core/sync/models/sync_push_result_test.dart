import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:suretakip/core/sync/models/sync_enums.dart';
import 'package:suretakip/core/sync/models/sync_push_result.dart';

void main() {
  group('SyncPushResult.isSuccess', () {
    test('applied ve alreadyProcessed başarı sayılır', () {
      const applied = SyncPushResult(type: SyncResultType.applied);
      const alreadyProcessed = SyncPushResult(
        type: SyncResultType.alreadyProcessed,
      );

      expect(applied.isSuccess, isTrue);
      expect(alreadyProcessed.isSuccess, isTrue);
    });

    test('authRequired, conflict ve rejected başarı sayılmaz', () {
      const authRequired = SyncPushResult(type: SyncResultType.authRequired);
      const conflict = SyncPushResult(type: SyncResultType.conflict);
      const rejected = SyncPushResult(type: SyncResultType.rejected);

      expect(authRequired.isSuccess, isFalse);
      expect(conflict.isSuccess, isFalse);
      expect(rejected.isSuccess, isFalse);
    });
  });

  group('parseSyncResult', () {
    test('applied zarfını tüm alanlarıyla ayrıştırır', () {
      final result = parseSyncResult({
        'result': 'applied',
        'server_version': 3,
        'created_at_server': '2026-01-01T00:00:00Z',
        'updated_at_server': '2026-01-02T00:00:00Z',
      });

      expect(result.type, SyncResultType.applied);
      expect(result.serverVersion, 3);
      expect(result.createdAtServer, DateTime.utc(2026));
      expect(result.updatedAtServer, DateTime.utc(2026, 1, 2));
      expect(result.isSuccess, isTrue);
    });

    test('already_processed zarfını ayrıştırır', () {
      final result = parseSyncResult({
        'result': 'already_processed',
        'server_version': 5,
      });

      expect(result.type, SyncResultType.alreadyProcessed);
      expect(result.serverVersion, 5);
      expect(result.isSuccess, isTrue);
    });

    test('auth_required zarfını ayrıştırır', () {
      final result = parseSyncResult({'result': 'auth_required'});

      expect(result.type, SyncResultType.authRequired);
      expect(result.errorCode, isNull);
      expect(result.isSuccess, isFalse);
    });

    test('conflict zarfı error_code taşır', () {
      final result = parseSyncResult({
        'result': 'conflict',
        'error_code': 'STALE_VERSION',
      });

      expect(result.type, SyncResultType.conflict);
      expect(result.errorCode, 'STALE_VERSION');
    });

    test('rejected zarfı error_code taşır', () {
      final result = parseSyncResult({
        'result': 'rejected',
        'error_code': 'FORBIDDEN',
      });

      expect(result.type, SyncResultType.rejected);
      expect(result.errorCode, 'FORBIDDEN');
    });

    test('rejected zarfında error_code eksikse UNKNOWN_RESULT kullanılır', () {
      final result = parseSyncResult({'result': 'rejected'});

      expect(result.type, SyncResultType.rejected);
      expect(result.errorCode, 'UNKNOWN_RESULT');
    });

    test('bilinmeyen result değeri rejected/UNKNOWN_RESULT olarak ele alınır', () {
      final result = parseSyncResult({'result': 'future_contract'});

      expect(result.type, SyncResultType.rejected);
      expect(result.errorCode, 'UNKNOWN_RESULT');
    });

    test('String gövde jsonDecode edilerek ayrıştırılır', () {
      final body = jsonEncode({'result': 'applied', 'server_version': 7});

      final result = parseSyncResult(body);

      expect(result.type, SyncResultType.applied);
      expect(result.serverVersion, 7);
    });

    test('created_at_server geçersizse null döner', () {
      final result = parseSyncResult({
        'result': 'applied',
        'created_at_server': 'not-a-date',
      });

      expect(result.createdAtServer, isNull);
    });
  });
}
