import 'package:drift/drift.dart';

import 'package:suretakip/core/database/tables/customer_snapshot_staging_table.dart';
import 'package:suretakip/core/database/tables/local_customers_table.dart';
import 'package:suretakip/core/database/tables/local_session_time_entries_table.dart';
import 'package:suretakip/core/database/tables/local_sessions_table.dart';
import 'package:suretakip/core/database/tables/sync_conflicts_table.dart';
import 'package:suretakip/core/database/tables/sync_outbox_table.dart';
import 'package:suretakip/core/database/tables/sync_state_table.dart';
import 'package:suretakip/core/security/local_database_security.dart';

part 'app_database.g.dart';

/// Uygulamanın offline-first yerel veritabanı. UI, Supabase yerine bu
/// veritabanının stream'lerini izler; mutation'lar burada domain kaydı +
/// `sync_outbox` kaydı olarak atomik yazılır (Bölüm 3.4, 8.1).
@DriftDatabase(
  tables: [
    LocalCustomers,
    LocalSessions,
    LocalSessionTimeEntries,
    SyncOutbox,
    SyncState,
    SyncConflicts,
    CustomerSnapshotStaging,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Testler ve alternatif executor'lar (örn. in-memory) için.
  AppDatabase.forExecutor(super.executor);

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      // v2: offline seans tabloları (Faz C).
      if (from < 2) {
        await m.createTable(localSessions);
        await m.createTable(localSessionTimeEntries);
      }
      // v3: outbox worker lease fencing token'ı.
      if (from < 3) {
        await m.addColumn(syncOutbox, syncOutbox.processingToken);
      }
      // v4: çatışma kayıtları (Bölüm 13).
      if (from < 4) {
        await m.createTable(syncConflicts);
      }
      // v5: bootstrap snapshot staging (Bölüm 15.1.1).
      if (from < 5) {
        await m.createTable(customerSnapshotStaging);
      }
    },
  );

  static QueryExecutor _openConnection() => openEncryptedLocalDatabase();
}
