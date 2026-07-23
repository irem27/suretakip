import 'package:flutter_test/flutter_test.dart';
import 'package:suretakip/core/sync/sync_pull_rpc.dart';

void main() {
  group('parseCustomerSnapshotPage', () {
    test('yalnız açık ok sonucu snapshot olarak kabul eder', () {
      final page = parseCustomerSnapshotPage({
        'result': 'ok',
        'customers': const <Map<String, Object?>>[],
        'server_cursor': 12,
        'has_more': false,
      });

      expect(page.ok, isTrue);
      expect(page.serverCursor, 12);
    });

    test('eksik result alanını reddeder', () {
      expect(
        () => parseCustomerSnapshotPage({
          'customers': const <Map<String, Object?>>[],
          'server_cursor': 0,
        }),
        throwsFormatException,
      );
    });

    test('bilinmeyen result alanını reddeder', () {
      expect(
        () => parseCustomerSnapshotPage({
          'result': 'future_contract',
          'customers': const <Map<String, Object?>>[],
        }),
        throwsFormatException,
      );
    });

    test('ok zarfında zorunlu snapshot alanları eksikse reddeder', () {
      expect(
        () => parseCustomerSnapshotPage({
          'result': 'ok',
          'server_cursor': 12,
          'has_more': false,
        }),
        throwsFormatException,
      );
      expect(
        () => parseCustomerSnapshotPage({
          'result': 'ok',
          'customers': const <Map<String, Object?>>[],
          'has_more': false,
        }),
        throwsFormatException,
      );
      expect(
        () => parseCustomerSnapshotPage({
          'result': 'ok',
          'customers': const <Map<String, Object?>>[],
          'server_cursor': 12,
        }),
        throwsFormatException,
      );
    });
  });

  group('parseChangesPage', () {
    test('eksik veya bilinmeyen result değerini reddeder', () {
      expect(
        () => parseChangesPage(const {}, cursor: 4),
        throwsFormatException,
      );
      expect(
        () => parseChangesPage({
          'result': 'future_contract',
          'changes': const <Map<String, Object?>>[],
        }, cursor: 4),
        throwsFormatException,
      );
    });

    test('ok zarfında zorunlu delta alanları eksikse reddeder', () {
      expect(
        () => parseChangesPage({
          'result': 'ok',
          'next_cursor': 4,
          'has_more': false,
        }, cursor: 4),
        throwsFormatException,
      );
      expect(
        () => parseChangesPage({
          'result': 'ok',
          'changes': const <Map<String, Object?>>[],
          'has_more': false,
        }, cursor: 4),
        throwsFormatException,
      );
      expect(
        () => parseChangesPage({
          'result': 'ok',
          'changes': const <Map<String, Object?>>[],
          'next_cursor': 4,
        }, cursor: 4),
        throwsFormatException,
      );
    });
  });
}
