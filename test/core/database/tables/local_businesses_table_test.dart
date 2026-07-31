import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suretakip/core/database/app_database.dart';

void main() {
  group('LocalBusinesses tablosu', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forExecutor(NativeDatabase.memory());
    });

    tearDown(() => db.close());

    test('tüm kolonlar doldurulduğunda kalıcı saklanır', () async {
      final archivedAt = DateTime.utc(2026, 7, 22, 9);
      final createdAt = DateTime.utc(2026, 7, 20);
      final updatedAt = DateTime.utc(2026, 7, 21);

      await db
          .into(db.localBusinesses)
          .insert(
            LocalBusinessesCompanion.insert(
              id: 'business-1',
              name: 'Kuru Temizleme A.Ş.',
              currencyCode: 'TRY',
              timezone: 'Europe/Istanbul',
              isActive: const Value(false),
              archivedAt: Value(archivedAt),
              createdAt: createdAt,
              updatedAt: updatedAt,
            ),
          );

      final row = (await db.select(db.localBusinesses).get()).single;
      expect(row.id, 'business-1');
      expect(row.name, 'Kuru Temizleme A.Ş.');
      expect(row.currencyCode, 'TRY');
      expect(row.timezone, 'Europe/Istanbul');
      expect(row.isActive, isFalse);
      expect(row.archivedAt?.toUtc(), archivedAt);
      expect(row.createdAt.toUtc(), createdAt);
      expect(row.updatedAt.toUtc(), updatedAt);
    });

    test('opsiyonel kolonlar null ve varsayılan isActive true olur', () async {
      final createdAt = DateTime.utc(2026, 7, 20);
      final updatedAt = DateTime.utc(2026, 7, 20);

      await db
          .into(db.localBusinesses)
          .insert(
            LocalBusinessesCompanion.insert(
              id: 'business-2',
              name: 'Yeni İşletme',
              currencyCode: 'TRY',
              timezone: 'Europe/Istanbul',
              createdAt: createdAt,
              updatedAt: updatedAt,
            ),
          );

      final row = (await db.select(db.localBusinesses).get()).single;
      expect(row.isActive, isTrue);
      expect(row.archivedAt, isNull);
    });
  });
}
