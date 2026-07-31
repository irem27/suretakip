import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suretakip/core/database/app_database.dart';

void main() {
  group('LocalBusinessMembers tablosu', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forExecutor(NativeDatabase.memory());
    });

    tearDown(() => db.close());

    test('tüm kolonlar doldurulduğunda kalıcı saklanır', () async {
      final createdAt = DateTime.utc(2026, 7, 20);
      final updatedAt = DateTime.utc(2026, 7, 21);

      await db
          .into(db.localBusinessMembers)
          .insert(
            LocalBusinessMembersCompanion.insert(
              id: 'member-1',
              businessId: 'business-1',
              userId: 'user-1',
              role: 'owner',
              isActive: const Value(false),
              createdAt: createdAt,
              updatedAt: updatedAt,
            ),
          );

      final row = (await db.select(db.localBusinessMembers).get()).single;
      expect(row.id, 'member-1');
      expect(row.businessId, 'business-1');
      expect(row.userId, 'user-1');
      expect(row.role, 'owner');
      expect(row.isActive, isFalse);
      expect(row.createdAt.toUtc(), createdAt);
      expect(row.updatedAt.toUtc(), updatedAt);
    });

    test('varsayılan isActive true ile eklenir', () async {
      final createdAt = DateTime.utc(2026, 7, 20);
      final updatedAt = DateTime.utc(2026, 7, 20);

      await db
          .into(db.localBusinessMembers)
          .insert(
            LocalBusinessMembersCompanion.insert(
              id: 'member-2',
              businessId: 'business-1',
              userId: 'user-2',
              role: 'staff',
              createdAt: createdAt,
              updatedAt: updatedAt,
            ),
          );

      final row = (await db.select(db.localBusinessMembers).get()).single;
      expect(row.isActive, isTrue);
      expect(row.role, 'staff');
    });
  });
}
