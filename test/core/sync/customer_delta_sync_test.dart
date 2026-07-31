import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suretakip/core/database/app_database.dart';
import 'package:suretakip/core/sync/customer_delta_store.dart';
import 'package:suretakip/core/sync/customer_delta_sync_service.dart';
import 'package:suretakip/core/sync/models/delta_models.dart';
import 'package:suretakip/core/sync/models/sync_enums.dart';
import 'package:suretakip/core/sync/sync_pull_rpc.dart';
import 'package:suretakip/features/customers/data/local/customers_local_data_source.dart';

/// Sıraya konmuş sayfaları döndüren sahte pull API'si.
class _FakePullApi implements SyncPullApi {
  _FakePullApi({this.snapshots = const [], this.changes = const []});

  final List<CustomerSnapshotPage> snapshots;
  final List<ChangesPage> changes;
  int _snap = 0;
  int _chg = 0;
  final snapshotCalls = <String?>[];
  final changeCalls = <int>[];

  @override
  Future<CustomerSnapshotPage> getCustomersSnapshot({
    required String businessId,
    String? afterId,
    int limit = 500,
  }) async {
    snapshotCalls.add(afterId);
    if (_snap >= snapshots.length) {
      return const CustomerSnapshotPage(
        customers: [],
        nextAfterId: null,
        hasMore: false,
        serverCursor: 0,
      );
    }
    return snapshots[_snap++];
  }

  @override
  Future<ChangesPage> getChanges({
    required String businessId,
    required int cursor,
    int limit = 500,
  }) async {
    changeCalls.add(cursor);
    if (_chg >= changes.length) {
      return ChangesPage(changes: const [], nextCursor: cursor, hasMore: false);
    }
    return changes[_chg++];
  }
}

ServerCustomerSnapshot _snap(
  String id, {
  String name = 'Ad',
  int version = 1,
}) => ServerCustomerSnapshot(
  id: id,
  businessId: 'biz-1',
  name: name,
  isActive: true,
  serverVersion: version,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

CustomerSnapshotPage _snapshotPage(
  List<ServerCustomerSnapshot> customers, {
  String? nextAfterId,
  bool hasMore = false,
  int serverCursor = 0,
}) => CustomerSnapshotPage(
  customers: customers,
  nextAfterId: nextAfterId,
  hasMore: hasMore,
  serverCursor: serverCursor,
);

SyncChange _upsert(String id, {String name = 'Ad', int version = 1}) =>
    SyncChange(
      changeSeq: version,
      entityType: 'customer',
      entityId: id,
      operation: 'upsert',
      serverVersion: version,
      payload: {
        'id': id,
        'business_id': 'biz-1',
        'name': name,
        'is_active': true,
        'created_at': '2026-01-01T00:00:00Z',
        'updated_at': '2026-01-01T00:00:00Z',
      },
    );

void main() {
  late AppDatabase db;
  late CustomersLocalDataSource local;
  late CustomerDeltaStore store;

  DateTime clock() => DateTime.utc(2026, 6, 1);

  setUp(() {
    db = AppDatabase.forExecutor(NativeDatabase.memory());
    local = CustomersLocalDataSource(db);
    store = CustomerDeltaStore(db, local);
  });
  tearDown(() async => db.close());

  CustomerDeltaSyncService service(_FakePullApi api) =>
      CustomerDeltaSyncService(pull: api, store: store, clock: clock);

  Future<void> seedLocal(String id, String status) => db
      .into(db.localCustomers)
      .insert(
        LocalCustomersCompanion.insert(
          id: id,
          businessId: 'biz-1',
          name: 'Yerel $id',
          syncStatus: status,
          createdAtLocal: DateTime.utc(2026),
          updatedAtLocal: DateTime.utc(2026),
        ),
      );

  test('bootstrap snapshot müşterileri indirir ve cursor yakalar', () async {
    final api = _FakePullApi(
      snapshots: [
        _snapshotPage([_snap('c1', name: 'Ali')], serverCursor: 7),
      ],
    );
    await service(api).sync('biz-1');

    final rows = await db.select(db.localCustomers).get();
    expect(rows.single.id, 'c1');
    expect(rows.single.name, 'Ali');
    expect(rows.single.syncStatus, SyncStatus.synced.wireName);
    expect(await store.readCursor('biz-1'), 7);
    // Delta, snapshot cursor'ından (7) sonra çağrıldı.
    expect(api.changeCalls, contains(7));
  });

  test('bootstrap keyset pagination ile çok sayfa çeker', () async {
    final api = _FakePullApi(
      snapshots: [
        _snapshotPage(
          [_snap('c1')],
          nextAfterId: 'c1',
          hasMore: true,
          serverCursor: 3,
        ),
        _snapshotPage([_snap('c2')], serverCursor: 3),
      ],
    );
    await service(api).sync('biz-1');

    final rows = await db.select(db.localCustomers).get();
    expect(rows.map((r) => r.id).toSet(), {'c1', 'c2'});
    expect(api.snapshotCalls, [null, 'c1']); // ikinci sayfa keyset ile
  });

  test('bootstrap bekleyen yerel kaydı ezmez', () async {
    await seedLocal('c1', SyncStatus.pending.wireName);
    final api = _FakePullApi(
      snapshots: [
        _snapshotPage([_snap('c1', name: 'Sunucu Adı')], serverCursor: 2),
      ],
    );
    await service(api).sync('biz-1');

    final row = await local.findCustomer('c1');
    expect(row!.syncStatus, SyncStatus.pending.wireName);
    expect(row.name, 'Yerel c1'); // sunucu adı yazılmadı
  });

  test('delta pull upsert uygular ve cursor ilerletir', () async {
    await store.writeCursor('biz-1', 5, clock());
    final api = _FakePullApi(
      changes: [
        ChangesPage(
          changes: [_upsert('c2', name: 'Veli', version: 6)],
          nextCursor: 6,
          hasMore: false,
        ),
      ],
    );
    await service(api).sync('biz-1');

    final row = await local.findCustomer('c2');
    expect(row!.name, 'Veli');
    expect(row.syncStatus, SyncStatus.synced.wireName);
    expect(await store.readCursor('biz-1'), 6);
  });

  test('delta tombstone temizi siler, dirty kaydı korur', () async {
    await store.writeCursor('biz-1', 5, clock());
    await seedLocal('clean', SyncStatus.synced.wireName);
    await seedLocal('dirty', SyncStatus.pending.wireName);
    final api = _FakePullApi(
      changes: [
        const ChangesPage(
          changes: [
            SyncChange(
              changeSeq: 6,
              entityType: 'customer',
              entityId: 'clean',
              operation: 'delete',
              serverVersion: 2,
            ),
            SyncChange(
              changeSeq: 7,
              entityType: 'customer',
              entityId: 'dirty',
              operation: 'delete',
              serverVersion: 2,
            ),
          ],
          nextCursor: 7,
          hasMore: false,
        ),
      ],
    );
    await service(api).sync('biz-1');

    expect((await local.findCustomer('clean'))!.isDeleted, isTrue);
    final dirty = await local.findCustomer('dirty');
    expect(dirty!.isDeleted, isFalse); // dirty korunur
    expect(dirty.syncStatus, SyncStatus.pending.wireName);
  });

  test('CURSOR_TOO_OLD full resync yapar, bekleyen kaydı korur', () async {
    await store.writeCursor('biz-1', 5, clock());
    await seedLocal('pending-local', SyncStatus.pending.wireName);
    final api = _FakePullApi(
      changes: [const ChangesPage.cursorTooOld()],
      snapshots: [
        _snapshotPage([_snap('c1')], serverCursor: 20),
      ],
    );
    await service(api).sync('biz-1');

    // Bekleyen yerel kayıt korundu.
    final pending = await local.findCustomer('pending-local');
    expect(pending!.syncStatus, SyncStatus.pending.wireName);
    // Snapshot uygulandı ve cursor güncellendi.
    expect(
      (await local.findCustomer('c1'))!.syncStatus,
      SyncStatus.synced.wireName,
    );
    expect(await store.readCursor('biz-1'), 20);
  });

  test(
    'snapshot reddedilirse yerel önbellek silinmez (veri kaybı yok)',
    () async {
      await seedLocal('c-existing', SyncStatus.synced.wireName);
      // cursor=0 → bootstrap; sunucu FORBIDDEN/rejected döner.
      final api = _FakePullApi(
        snapshots: [const CustomerSnapshotPage.rejected()],
      );
      await service(api).sync('biz-1');

      final row = await local.findCustomer('c-existing');
      expect(row, isNotNull);
      expect(row!.isDeleted, isFalse); // tombstone edilmedi
      // Merge yapılmadığı için cursor da ilerlemedi.
      expect(await store.readCursor('biz-1'), 0);
    },
  );

  test('cursor işletmeye göre ayrılır (tenant izolasyonu)', () async {
    await store.writeCursor('biz-1', 10, clock());
    await store.writeCursor('biz-2', 20, clock());

    expect(await store.readCursor('biz-1'), 10);
    expect(await store.readCursor('biz-2'), 20);
  });
}
