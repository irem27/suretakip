import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:suretakip/core/database/app_database.dart';
import 'package:suretakip/core/sync/models/sync_enums.dart';
import 'package:suretakip/core/sync/models/sync_push_result.dart';
import 'package:uuid/uuid.dart';

/// Sync Engine'in outbox üzerindeki tüm durum geçişlerini kapsüller. Domain
/// kaydı ile outbox kaydı birlikte güncellenmesi gereken yerlerde tek Drift
/// transaction'ı kullanır.
class OutboxRepository {
  const OutboxRepository(this._db);

  static const processingLease = Duration(minutes: 5);

  final AppDatabase _db;

  /// Yeni bir mutation'ı outbox'a ekler. `sequence_number` aynı transaction
  /// içinde üretilir (Bölüm 6). Domain kaydıyla atomik olması için ÇAĞIRAN
  /// bunu domain yazımıyla aynı transaction içinde çağırmalıdır.
  Future<void> enqueue({
    required String operationId,
    required String businessId,
    required String actorUserId,
    required String deviceId,
    required String aggregateType,
    required String aggregateId,
    required SyncOperationType operationType,
    required String idempotencyKey,
    required Map<String, Object?> payload,
    required DateTime now,
    String? dependsOnOperationId,
    int payloadVersion = 1,
  }) async {
    await _db
        .into(_db.syncOutbox)
        .insert(
          SyncOutboxCompanion.insert(
            id: operationId,
            operationId: operationId,
            businessId: businessId,
            originalActorUserId: actorUserId,
            deviceId: deviceId,
            aggregateType: aggregateType,
            aggregateId: aggregateId,
            operationType: operationType.wireName,
            sequenceNumber: await _nextSequence(aggregateType, aggregateId),
            dependsOnOperationId: Value(dependsOnOperationId),
            payloadJson: jsonEncode(payload),
            payloadVersion: Value(payloadVersion),
            idempotencyKey: idempotencyKey,
            status: SyncStatus.pending.wireName,
            createdAt: now,
          ),
        );
  }

  /// Bir aggregate için en son (en yüksek sıra) outbox operasyon kimliği.
  /// Yeni event'in `depends_on` zincirini kurmakta kullanılır.
  Future<String?> latestOperationId(
    String aggregateType,
    String aggregateId,
  ) async {
    final row =
        await (_db.select(_db.syncOutbox)
              ..where(
                (t) =>
                    t.aggregateType.equals(aggregateType) &
                    t.aggregateId.equals(aggregateId),
              )
              ..orderBy([
                (t) => OrderingTerm(
                  expression: t.sequenceNumber,
                  mode: OrderingMode.desc,
                ),
              ])
              ..limit(1))
            .getSingleOrNull();
    return row?.operationId;
  }

  Future<int> _nextSequence(String aggregateType, String aggregateId) async {
    final maxExpr = _db.syncOutbox.sequenceNumber.max();
    final query = _db.selectOnly(_db.syncOutbox)
      ..addColumns([maxExpr])
      ..where(
        _db.syncOutbox.aggregateType.equals(aggregateType) &
            _db.syncOutbox.aggregateId.equals(aggregateId),
      );
    final current = await query.map((row) => row.read(maxExpr)).getSingle();
    return (current ?? 0) + 1;
  }

  /// Gönderilmeye hazır kayıtlar: pending/retrying ve zamanı gelmiş; bağımlı
  /// olduğu operasyon henüz synced değilse atlanır (Bölüm 10, 11).
  /// Gönderilmeye hazır kayıtlar. [actorUserId] yalnız o kullanıcının
  /// oluşturduğu operasyonları claim eder; `null` ise (oturum kapalı) HİÇBİR
  /// kayıt claim edilmez → worker fiilen durur, veri korunur (Bölüm 16.2).
  /// [businessId] verilirse yalnız aktif işletmenin kayıtları gönderilir.
  Future<List<SyncOutboxRow>> claimReady({
    required DateTime now,
    String? actorUserId,
    String? businessId,
    int limit = 50,
  }) {
    if (actorUserId == null) return Future.value(const []);
    return _db.transaction(() async {
      final dependency = _db.alias(_db.syncOutbox, 'dependency');
      final candidates =
          await (_db.select(_db.syncOutbox)
                ..where((t) {
                  final unsyncedDependency = _db.selectOnly(dependency)
                    ..addColumns([dependency.id])
                    ..where(
                      dependency.operationId.equalsExp(t.dependsOnOperationId) &
                          dependency.status
                              .equals(SyncStatus.synced.wireName)
                              .not(),
                    );
                  return t.status.isIn([
                        SyncStatus.pending.wireName,
                        SyncStatus.retrying.wireName,
                      ]) &
                      t.originalActorUserId.equals(actorUserId) &
                      (businessId == null
                          ? const Constant(true)
                          : t.businessId.equals(businessId)) &
                      (t.nextAttemptAt.isNull() |
                          t.nextAttemptAt.isSmallerOrEqualValue(now)) &
                      (t.dependsOnOperationId.isNull() |
                          notExistsQuery(unsyncedDependency));
                })
                ..orderBy([
                  (t) => OrderingTerm(expression: t.priority),
                  (t) => OrderingTerm(expression: t.aggregateType),
                  (t) => OrderingTerm(expression: t.aggregateId),
                  (t) => OrderingTerm(expression: t.sequenceNumber),
                ])
                ..limit(limit))
              .get();

      final claimed = <SyncOutboxRow>[];
      for (final row in candidates) {
        final processingToken = const Uuid().v4();
        final updated =
            await (_db.update(_db.syncOutbox)..where(
                  (t) =>
                      t.id.equals(row.id) &
                      t.status.isIn([
                        SyncStatus.pending.wireName,
                        SyncStatus.retrying.wireName,
                      ]),
                ))
                .write(
                  SyncOutboxCompanion(
                    status: Value(SyncStatus.processing.wireName),
                    lastAttemptAt: Value(now),
                    processingToken: Value(processingToken),
                  ),
                );
        if (updated != 1) continue;
        claimed.add(
          await (_db.select(_db.syncOutbox)..where(
                (t) =>
                    t.id.equals(row.id) &
                    t.processingToken.equals(processingToken),
              ))
              .getSingle(),
        );
      }
      return claimed;
    });
  }

  /// Uygulama bir RPC sırasında kapanırsa `processing` kaydı kalabilir.
  /// Lease süresi dolan kayıtlar yeniden `pending` yapılır; sunucuda işlem
  /// uygulanmış olsa bile kararlı idempotency anahtarı tekrarı güvenli kılar.
  /// Taze lease'lere dokunulmaz; böylece başka bir aktif worker'la yarışılmaz.
  Future<int> recoverStaleProcessing({required DateTime now}) {
    final staleBefore = now.subtract(processingLease);
    return (_db.update(_db.syncOutbox)..where(
          (t) =>
              t.status.equals(SyncStatus.processing.wireName) &
              (t.lastAttemptAt.isNull() |
                  t.lastAttemptAt.isSmallerOrEqualValue(staleBefore)),
        ))
        .write(
          SyncOutboxCompanion(
            status: Value(SyncStatus.pending.wireName),
            nextAttemptAt: const Value(null),
            processingToken: const Value(null),
            lastErrorCode: const Value('PROCESSING_LEASE_EXPIRED'),
            lastErrorMessage: const Value(null),
          ),
        );
  }

  /// Başarı (applied/already_processed): domain kaydı ve outbox birlikte synced.
  Future<bool> applySuccess(
    SyncOutboxRow row,
    SyncPushResult result, {
    required DateTime now,
    required String submittedByUserId,
  }) {
    return _db.transaction(() async {
      final token = row.processingToken;
      if (token == null) return false;
      final updated =
          await (_db.update(_db.syncOutbox)..where(
                (t) =>
                    t.id.equals(row.id) &
                    t.status.equals(SyncStatus.processing.wireName) &
                    t.processingToken.equals(token),
              ))
              .write(
                SyncOutboxCompanion(
                  status: Value(SyncStatus.synced.wireName),
                  submittedByUserId: Value(submittedByUserId),
                  syncedAt: Value(now),
                  processingToken: const Value(null),
                  lastErrorCode: const Value(null),
                  lastErrorMessage: const Value(null),
                ),
              );
      if (updated != 1) return false;
      await _writeAggregateStatus(
        row,
        status: SyncStatus.synced,
        serverVersion: result.serverVersion,
        createdAtServer: result.createdAtServer,
        updatedAtServer: result.updatedAtServer,
      );
      return true;
    });
  }

  /// Aggregate türüne (`customer`/`session`) göre ilgili domain kaydının
  /// senkronizasyon durumunu günceller.
  Future<void> _writeAggregateStatus(
    SyncOutboxRow row, {
    required SyncStatus status,
    int? serverVersion,
    DateTime? createdAtServer,
    DateTime? updatedAtServer,
    String? errorCode,
  }) async {
    switch (row.aggregateType) {
      case 'customer':
        await (_db.update(
          _db.localCustomers,
        )..where((t) => t.id.equals(row.aggregateId))).write(
          LocalCustomersCompanion(
            syncStatus: Value(status.wireName),
            serverVersion: Value(serverVersion),
            createdAtServer: Value(createdAtServer),
            updatedAtServer: Value(updatedAtServer),
            lastSyncError: Value(errorCode),
          ),
        );
      case 'session':
        await (_db.update(
          _db.localSessions,
        )..where((t) => t.id.equals(row.aggregateId))).write(
          LocalSessionsCompanion(
            syncStatus: Value(status.wireName),
            serverVersion: Value(serverVersion),
          ),
        );
    }
  }

  /// Worker auth nedeniyle durduğunda `processing`'i tekrar `pending` yapar;
  /// deneme sayısına dokunmaz (Bölüm 10, adım 3/12).
  Future<bool> resetToPending(SyncOutboxRow row) async {
    final token = row.processingToken;
    if (token == null) return false;
    final updated =
        await (_db.update(_db.syncOutbox)..where(
              (t) =>
                  t.id.equals(row.id) &
                  t.status.equals(SyncStatus.processing.wireName) &
                  t.processingToken.equals(token),
            ))
            .write(
              SyncOutboxCompanion(
                status: Value(SyncStatus.pending.wireName),
                processingToken: const Value(null),
              ),
            );
    return updated == 1;
  }

  Future<bool> markRetrying(
    SyncOutboxRow row, {
    required int attemptCount,
    required DateTime nextAttemptAt,
    String? errorCode,
    String? errorMessage,
  }) async {
    final token = row.processingToken;
    if (token == null) return false;
    final updated =
        await (_db.update(_db.syncOutbox)..where(
              (t) =>
                  t.id.equals(row.id) &
                  t.status.equals(SyncStatus.processing.wireName) &
                  t.processingToken.equals(token),
            ))
            .write(
              SyncOutboxCompanion(
                status: Value(SyncStatus.retrying.wireName),
                attemptCount: Value(attemptCount),
                nextAttemptAt: Value(nextAttemptAt),
                processingToken: const Value(null),
                lastErrorCode: Value(errorCode),
                lastErrorMessage: Value(errorMessage),
              ),
            );
    return updated == 1;
  }

  /// Kalıcı ret veya çatışma: outbox ve müşteri birlikte işaretlenir; kayıt
  /// SİLİNMEZ (Bölüm 8.3).
  Future<bool> markTerminal(
    SyncOutboxRow row, {
    required SyncStatus status,
    String? errorCode,
    String? errorMessage,
  }) {
    return _db.transaction(() async {
      final token = row.processingToken;
      if (token == null) return false;
      final updated =
          await (_db.update(_db.syncOutbox)..where(
                (t) =>
                    t.id.equals(row.id) &
                    t.status.equals(SyncStatus.processing.wireName) &
                    t.processingToken.equals(token),
              ))
              .write(
                SyncOutboxCompanion(
                  status: Value(status.wireName),
                  processingToken: const Value(null),
                  lastErrorCode: Value(errorCode),
                  lastErrorMessage: Value(errorMessage),
                ),
              );
      if (updated != 1) return false;
      await _writeAggregateStatus(row, status: status, errorCode: errorCode);
      return true;
    });
  }
}
