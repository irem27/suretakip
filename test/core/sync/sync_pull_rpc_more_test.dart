import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:suretakip/core/sync/sync_pull_rpc.dart';

void main() {
  group('parseChangesPage', () {
    test('auth_required zarfını yansıtır', () {
      final page = parseChangesPage({'result': 'auth_required'}, cursor: 4);

      expect(page.authRequired, isTrue);
      expect(page.cursorTooOld, isFalse);
      expect(page.changes, isEmpty);
    });

    test('CURSOR_TOO_OLD reddi cursorTooOld olarak ele alınır', () {
      final page = parseChangesPage({
        'result': 'rejected',
        'error_code': 'CURSOR_TOO_OLD',
      }, cursor: 4);

      expect(page.cursorTooOld, isTrue);
      expect(page.authRequired, isFalse);
    });

    test('CURSOR_TOO_OLD dışındaki ret StateError fırlatır', () {
      expect(
        () => parseChangesPage({
          'result': 'rejected',
          'error_code': 'FORBIDDEN',
        }, cursor: 4),
        throwsStateError,
      );
    });

    test('ok zarfı değişiklikleri ve sayfalama alanlarını ayrıştırır', () {
      final page = parseChangesPage({
        'result': 'ok',
        'changes': [
          {
            'change_seq': 10,
            'entity_type': 'customer',
            'entity_id': 'cust-1',
            'operation': 'upsert',
            'server_version': 2,
            'payload': {'name': 'Ali'},
          },
          {
            'change_seq': 11,
            'entity_type': 'customer',
            'entity_id': 'cust-2',
            'operation': 'delete',
            'server_version': 1,
            'payload': null,
          },
        ],
        'next_cursor': 11,
        'has_more': true,
      }, cursor: 4);

      expect(page.changes, hasLength(2));
      expect(page.changes.first.changeSeq, 10);
      expect(page.changes.first.entityType, 'customer');
      expect(page.changes.first.entityId, 'cust-1');
      expect(page.changes.first.payload, {'name': 'Ali'});
      expect(page.changes.first.isDelete, isFalse);
      expect(page.changes.last.isDelete, isTrue);
      expect(page.changes.last.payload, isNull);
      expect(page.nextCursor, 11);
      expect(page.hasMore, isTrue);
    });

    test('String gövde jsonDecode edilerek ayrıştırılır', () {
      final body = jsonEncode({
        'result': 'ok',
        'changes': const <Map<String, Object?>>[],
        'next_cursor': 4,
        'has_more': false,
      });

      final page = parseChangesPage(body, cursor: 4);

      expect(page.changes, isEmpty);
      expect(page.nextCursor, 4);
    });

    test('nesne olmayan cevap FormatException fırlatır', () {
      expect(
        () => parseChangesPage(const [1, 2, 3], cursor: 4),
        throwsFormatException,
      );
    });
  });

  group('parseCustomerSnapshotPage', () {
    test('auth_required zarfını yansıtır', () {
      final page = parseCustomerSnapshotPage({'result': 'auth_required'});

      expect(page.authRequired, isTrue);
      expect(page.ok, isFalse);
    });

    test(
      'herhangi bir ret merge/tombstone yapılmaması için rejected sayılır',
      () {
        final page = parseCustomerSnapshotPage({
          'result': 'rejected',
          'error_code': 'FORBIDDEN',
        });

        expect(page.ok, isFalse);
        expect(page.authRequired, isFalse);
        expect(page.customers, isEmpty);
      },
    );

    test('ok zarfı müşteri alanlarını tam ayrıştırır', () {
      final page = parseCustomerSnapshotPage({
        'result': 'ok',
        'customers': [
          {
            'id': 'cust-1',
            'business_id': 'biz-1',
            'name': 'Ali Veli',
            'phone': '5551234567',
            'email': 'ali@example.com',
            'notes': 'not',
            'is_active': true,
            'server_version': 4,
            'created_at': '2026-01-01T00:00:00Z',
            'updated_at': '2026-01-02T00:00:00Z',
          },
        ],
        'next_after_id': 'cust-2',
        'has_more': true,
        'server_cursor': 42,
      });

      expect(page.ok, isTrue);
      expect(page.customers, hasLength(1));
      final customer = page.customers.single;
      expect(customer.id, 'cust-1');
      expect(customer.businessId, 'biz-1');
      expect(customer.name, 'Ali Veli');
      expect(customer.phone, '5551234567');
      expect(customer.email, 'ali@example.com');
      expect(customer.notes, 'not');
      expect(customer.isActive, isTrue);
      expect(customer.serverVersion, 4);
      expect(customer.createdAt, DateTime.utc(2026));
      expect(customer.updatedAt, DateTime.utc(2026, 1, 2));
      expect(page.nextAfterId, 'cust-2');
      expect(page.hasMore, isTrue);
      expect(page.serverCursor, 42);
    });

    test('nesne olmayan cevap FormatException fırlatır', () {
      expect(
        () => parseCustomerSnapshotPage('sadece metin'),
        throwsFormatException,
      );
    });
  });
}
