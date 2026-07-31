import 'package:drift/drift.dart';

import 'package:suretakip/core/database/tables/customer_snapshot_staging_table.dart';
import 'package:suretakip/core/database/tables/local_business_members_table.dart';
import 'package:suretakip/core/database/tables/local_businesses_table.dart';
import 'package:suretakip/core/database/tables/local_customers_table.dart';
import 'package:suretakip/core/database/tables/local_products_table.dart';
import 'package:suretakip/core/database/tables/local_services_table.dart';
import 'package:suretakip/core/database/tables/local_session_items_table.dart';
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
    LocalSessionItems,
    LocalBusinesses,
    LocalBusinessMembers,
    LocalServices,
    LocalProducts,
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
  int get schemaVersion => 9;

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
      // v6: sunucu-otoriteli seans ürün kalemlerinin offline önbelleği.
      if (from < 6) {
        await m.createTable(localSessionItems);
      }
      // v7: internetsiz açılış için işletme + üyelik read-through önbelleği.
      if (from < 7) {
        await m.createTable(localBusinesses);
        await m.createTable(localBusinessMembers);
      }
      // v8: hizmet + ürün read-through önbelleği (seans döngüsü offline).
      if (from < 8) {
        await m.createTable(localServices);
        await m.createTable(localProducts);
      }
      // v9: ürün + hizmet katalog yazma yolu offline-first (müşteri
      // deseniyle birebir aynı sync_status/server_version/tombstone alanları).
      // NOT: from < 8 ise localServices/localProducts bu migration'da YENİ
      // oluşturulur (yukarıdaki blok) ve canlı tablo tanımı zaten v9
      // kolonlarını içerir; bu durumda addColumn tekrarı "duplicate column"
      // hatası verir. Bu yüzden yalnız v8'den v9'a yükselen (tablo daha önce
      // v9 kolonları OLMADAN var olan) cihazlarda addColumn çalıştırılır.
      if (from < 9 && from >= 8) {
        await m.addColumn(localProducts, localProducts.syncStatus);
        await m.addColumn(localProducts, localProducts.serverVersion);
        await m.addColumn(localProducts, localProducts.isDeleted);
        await m.addColumn(localProducts, localProducts.deletedAt);
        await m.addColumn(localProducts, localProducts.lastSyncError);
        await m.addColumn(localServices, localServices.syncStatus);
        await m.addColumn(localServices, localServices.serverVersion);
        await m.addColumn(localServices, localServices.isDeleted);
        await m.addColumn(localServices, localServices.deletedAt);
        await m.addColumn(localServices, localServices.lastSyncError);
      }
    },
  );

  static QueryExecutor _openConnection() => openEncryptedLocalDatabase();
}
