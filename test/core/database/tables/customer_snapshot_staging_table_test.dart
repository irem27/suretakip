import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suretakip/core/database/app_database.dart';

void main() {
  group('CustomerSnapshotStaging tablosu', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forExecutor(NativeDatabase.memory());
    });

    tearDown(() => db.close());

    test('tüm kolonlar doldurulduğunda kalıcı saklanır', () async {
      final createdAt = DateTime.utc(2026, 7, 20);
      final updatedAt = DateTime.utc(2026, 7, 21);

      await db
          .into(db.customerSnapshotStaging)
          .insert(
            CustomerSnapshotStagingCompanion.insert(
              generationId: 'gen-1',
              id: 'customer-1',
              businessId: 'business-1',
              name: 'Ali Veli',
              phone: const Value('5551112233'),
              email: const Value('ali@example.com'),
              notes: const Value('VIP'),
              isActive: const Value(false),
              serverVersion: 6,
              createdAt: createdAt,
              updatedAt: updatedAt,
            ),
          );

      final row = (await db.select(db.customerSnapshotStaging).get()).single;
      expect(row.generationId, 'gen-1');
      expect(row.id, 'customer-1');
      expect(row.businessId, 'business-1');
      expect(row.name, 'Ali Veli');
      expect(row.phone, '5551112233');
      expect(row.email, 'ali@example.com');
      expect(row.notes, 'VIP');
      expect(row.isActive, isFalse);
      expect(row.serverVersion, 6);
      expect(row.createdAt.toUtc(), createdAt);
      expect(row.updatedAt.toUtc(), updatedAt);
    });

    test('opsiyonel kolonlar null ve varsayılan isActive true olur', () async {
      final createdAt = DateTime.utc(2026, 7, 20);
      final updatedAt = DateTime.utc(2026, 7, 20);

      await db
          .into(db.customerSnapshotStaging)
          .insert(
            CustomerSnapshotStagingCompanion.insert(
              generationId: 'gen-1',
              id: 'customer-2',
              businessId: 'business-1',
              name: 'Ayşe',
              serverVersion: 1,
              createdAt: createdAt,
              updatedAt: updatedAt,
            ),
          );

      final row = (await db.select(db.customerSnapshotStaging).get()).single;
      expect(row.phone, isNull);
      expect(row.email, isNull);
      expect(row.notes, isNull);
      expect(row.isActive, isTrue);
    });
  });
}
