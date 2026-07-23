import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suretakip/core/database/app_database.dart';

void main() {
  test(
    'schema v5 verisini koruyarak yerel seans ürün tablosunu ekler',
    () async {
      final executor = NativeDatabase.memory(
        setup: (database) {
          database.execute(
            'CREATE TABLE legacy_marker (id INTEGER PRIMARY KEY, value TEXT);',
          );
          database.execute(
            'INSERT INTO legacy_marker (id, value) VALUES (1, \'koru\');',
          );
          database.userVersion = 5;
        },
      );
      final database = AppDatabase.forExecutor(executor);
      addTearDown(database.close);

      final itemTable = await database
          .customSelect(
            'SELECT name FROM sqlite_master '
            'WHERE type = \'table\' AND name = \'local_session_items\';',
          )
          .getSingle();
      final marker = await database
          .customSelect('SELECT value FROM legacy_marker WHERE id = 1;')
          .getSingle();

      expect(itemTable.read<String>('name'), 'local_session_items');
      expect(marker.read<String>('value'), 'koru');
    },
  );
}
