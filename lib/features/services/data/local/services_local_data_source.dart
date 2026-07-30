import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:suretakip/core/database/app_database.dart';
import 'package:suretakip/core/sync/models/sync_enums.dart';
import 'package:suretakip/features/services/domain/entities/service.dart';

/// Yeni hizmet oluşturma için gereken, senkronizasyondan bağımsız girdi.
final class EnqueueCreateService {
  const EnqueueCreateService({
    required this.serviceId,
    required this.operationId,
    required this.businessId,
    required this.actorUserId,
    required this.deviceId,
    required this.name,
    required this.pricePerMinuteMinor,
    required this.roundingIntervalMinutes,
    required this.minimumChargeMinutes,
    required this.currencyCode,
    required this.now,
    this.payloadVersion = 1,
  });

  final String serviceId;
  final String operationId;
  final String businessId;
  final String actorUserId;
  final String deviceId;
  final String name;
  final int pricePerMinuteMinor;
  final int roundingIntervalMinutes;
  final int minimumChargeMinutes;
  final String currencyCode;
  final DateTime now;
  final int payloadVersion;

  /// {business_id}:{device_id}:{operation_id} (Bölüm 7.2).
  String get idempotencyKey => '$businessId:$deviceId:$operationId';
}

/// Var olan hizmeti güncelleme için gereken, senkronizasyondan bağımsız
/// girdi. Yalnız düzenlenebilir alanlar taşınır (is_active/currency hariç).
final class EnqueueUpdateService {
  const EnqueueUpdateService({
    required this.serviceId,
    required this.operationId,
    required this.businessId,
    required this.actorUserId,
    required this.deviceId,
    required this.name,
    required this.pricePerMinuteMinor,
    required this.roundingIntervalMinutes,
    required this.minimumChargeMinutes,
    required this.expectedVersion,
    required this.now,
    this.payloadVersion = 1,
  });

  final String serviceId;
  final String operationId;
  final String businessId;
  final String actorUserId;
  final String deviceId;
  final String name;
  final int pricePerMinuteMinor;
  final int roundingIntervalMinutes;
  final int minimumChargeMinutes;

  /// Optimistic concurrency için yerelde bilinen `server_version` (Bölüm 8).
  final int expectedVersion;
  final DateTime now;
  final int payloadVersion;

  /// {business_id}:{device_id}:{operation_id} (Bölüm 7.2).
  String get idempotencyKey => '$businessId:$deviceId:$operationId';
}

/// Hizmeti aktif/pasif yapma için gereken, senkronizasyondan bağımsız girdi.
final class EnqueueSetServiceActive {
  const EnqueueSetServiceActive({
    required this.serviceId,
    required this.operationId,
    required this.businessId,
    required this.actorUserId,
    required this.deviceId,
    required this.isActive,
    required this.expectedVersion,
    required this.now,
    this.payloadVersion = 1,
  });

  final String serviceId;
  final String operationId;
  final String businessId;
  final String actorUserId;
  final String deviceId;
  final bool isActive;

  /// Optimistic concurrency için yerelde bilinen `server_version` (Bölüm 8).
  final int expectedVersion;
  final DateTime now;
  final int payloadVersion;

  /// {business_id}:{device_id}:{operation_id} (Bölüm 7.2).
  String get idempotencyKey => '$businessId:$deviceId:$operationId';
}

/// Hizmet okuma ve "hizmet + outbox" atomik yazımını yöneten Drift katmanı.
class ServicesLocalDataSource {
  const ServicesLocalDataSource(this._db);

  final AppDatabase _db;

  /// Yalnız temiz (dirty olmayan) yerel kopyalar sunucu snapshot'ı ile
  /// ezilir; offline yazılmış bekleyen/çakışmalı kayıtlar korunur
  /// (`upsertServerCustomers` ile aynı desen).
  Future<void> replaceServices(String businessId, List<Service> services) =>
      _db.transaction(() async {
        const dirtyStatuses = <String>{
          'localOnly',
          'pending',
          'processing',
          'retrying',
          'conflicted',
        };
        final existingRows = await (_db.select(
          _db.localServices,
        )..where((t) => t.businessId.equals(businessId))).get();
        final dirtyIds = {
          for (final row in existingRows)
            if (dirtyStatuses.contains(row.syncStatus)) row.id,
        };
        for (final row in existingRows) {
          if (dirtyIds.contains(row.id)) continue;
          await (_db.delete(
            _db.localServices,
          )..where((t) => t.id.equals(row.id))).go();
        }
        for (final service in services) {
          if (dirtyIds.contains(service.id)) continue;
          await _db
              .into(_db.localServices)
              .insertOnConflictUpdate(_toCompanion(service));
        }
      });

  Future<List<Service>> getServices({
    required String businessId,
    bool includeInactive = false,
  }) async {
    final query = _db.select(_db.localServices)
      ..where(
        (t) => t.businessId.equals(businessId) & t.isDeleted.equals(false),
      )
      ..orderBy([(t) => OrderingTerm(expression: t.name)]);
    if (!includeInactive) query.where((t) => t.isActive.equals(true));
    final rows = await query.get();
    return rows.map(_fromRow).toList(growable: false);
  }

  Future<Service?> getService(String id) async {
    final row = await findServiceRow(id);
    return row == null ? null : _fromRow(row);
  }

  Future<LocalServiceRow?> findServiceRow(String id) => (_db.select(
    _db.localServices,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> upsertService(Service service) => _db
      .into(_db.localServices)
      .insertOnConflictUpdate(_toCompanion(service));

  /// Domain kaydı ve outbox kaydını TEK transaction'da yazar (Bölüm 6).
  Future<LocalServiceRow> enqueueCreateService(
    EnqueueCreateService command,
  ) {
    return _db.transaction(() async {
      final service = LocalServicesCompanion.insert(
        id: command.serviceId,
        businessId: command.businessId,
        name: command.name,
        pricePerMinuteMinor: command.pricePerMinuteMinor,
        roundingIntervalMinutes: command.roundingIntervalMinutes,
        minimumChargeMinutes: command.minimumChargeMinutes,
        currencyCode: command.currencyCode,
        syncStatus: Value(SyncStatus.pending.wireName),
        createdAt: command.now,
        updatedAt: command.now,
      );
      await _db.into(_db.localServices).insert(service);

      final payload = <String, Object?>{
        'id': command.serviceId,
        'name': command.name,
        'price_per_minute_minor': command.pricePerMinuteMinor,
        'rounding_interval_minutes': command.roundingIntervalMinutes,
        'minimum_charge_minutes': command.minimumChargeMinutes,
        'currency_code': command.currencyCode,
      };

      await _db
          .into(_db.syncOutbox)
          .insert(
            SyncOutboxCompanion.insert(
              id: command.operationId,
              operationId: command.operationId,
              businessId: command.businessId,
              originalActorUserId: command.actorUserId,
              deviceId: command.deviceId,
              aggregateType: 'service',
              aggregateId: command.serviceId,
              operationType: SyncOperationType.createService.wireName,
              sequenceNumber: await _nextSequence(
                'service',
                command.serviceId,
              ),
              payloadJson: jsonEncode(payload),
              payloadVersion: Value(command.payloadVersion),
              idempotencyKey: command.idempotencyKey,
              status: SyncStatus.pending.wireName,
              createdAt: command.now,
            ),
          );

      final inserted = await findServiceRow(command.serviceId);
      if (inserted == null) {
        throw StateError('Yerel hizmet kaydı oluşturulamadı.');
      }
      return inserted;
    });
  }

  /// Var olan hizmeti ve outbox kaydını TEK transaction'da yazar
  /// (`enqueueCreateService` ile aynı desen). `server_version`, optimistic
  /// concurrency için yerel satırdan `expected_version` olarak okunur.
  Future<LocalServiceRow> enqueueUpdateService(
    EnqueueUpdateService command,
  ) {
    return _db.transaction(() async {
      await (_db.update(
        _db.localServices,
      )..where((t) => t.id.equals(command.serviceId))).write(
        LocalServicesCompanion(
          name: Value(command.name),
          pricePerMinuteMinor: Value(command.pricePerMinuteMinor),
          roundingIntervalMinutes: Value(command.roundingIntervalMinutes),
          minimumChargeMinutes: Value(command.minimumChargeMinutes),
          syncStatus: Value(SyncStatus.pending.wireName),
          updatedAt: Value(command.now),
        ),
      );

      final payload = <String, Object?>{
        'id': command.serviceId,
        'name': command.name,
        'price_per_minute_minor': command.pricePerMinuteMinor,
        'rounding_interval_minutes': command.roundingIntervalMinutes,
        'minimum_charge_minutes': command.minimumChargeMinutes,
      };

      await _db
          .into(_db.syncOutbox)
          .insert(
            SyncOutboxCompanion.insert(
              id: command.operationId,
              operationId: command.operationId,
              businessId: command.businessId,
              originalActorUserId: command.actorUserId,
              deviceId: command.deviceId,
              aggregateType: 'service',
              aggregateId: command.serviceId,
              operationType: SyncOperationType.updateService.wireName,
              sequenceNumber: await _nextSequence(
                'service',
                command.serviceId,
              ),
              payloadJson: jsonEncode(payload),
              payloadVersion: Value(command.payloadVersion),
              idempotencyKey: command.idempotencyKey,
              expectedServerVersion: Value(command.expectedVersion),
              status: SyncStatus.pending.wireName,
              createdAt: command.now,
            ),
          );

      final updated = await findServiceRow(command.serviceId);
      if (updated == null) {
        throw StateError('Yerel hizmet kaydı bulunamadı.');
      }
      return updated;
    });
  }

  /// Hizmeti aktif/pasif yapar; yalnız `is_active` alanını değiştirir ve
  /// domain kaydı + outbox kaydını TEK transaction'da yazar.
  Future<LocalServiceRow> enqueueSetServiceActive(
    EnqueueSetServiceActive command,
  ) {
    return _db.transaction(() async {
      await (_db.update(
        _db.localServices,
      )..where((t) => t.id.equals(command.serviceId))).write(
        LocalServicesCompanion(
          isActive: Value(command.isActive),
          syncStatus: Value(SyncStatus.pending.wireName),
          updatedAt: Value(command.now),
        ),
      );

      final payload = <String, Object?>{
        'id': command.serviceId,
        'is_active': command.isActive,
      };

      await _db
          .into(_db.syncOutbox)
          .insert(
            SyncOutboxCompanion.insert(
              id: command.operationId,
              operationId: command.operationId,
              businessId: command.businessId,
              originalActorUserId: command.actorUserId,
              deviceId: command.deviceId,
              aggregateType: 'service',
              aggregateId: command.serviceId,
              operationType: SyncOperationType.setServiceActive.wireName,
              sequenceNumber: await _nextSequence(
                'service',
                command.serviceId,
              ),
              payloadJson: jsonEncode(payload),
              payloadVersion: Value(command.payloadVersion),
              idempotencyKey: command.idempotencyKey,
              expectedServerVersion: Value(command.expectedVersion),
              status: SyncStatus.pending.wireName,
              createdAt: command.now,
            ),
          );

      final updated = await findServiceRow(command.serviceId);
      if (updated == null) {
        throw StateError('Yerel hizmet kaydı bulunamadı.');
      }
      return updated;
    });
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

  LocalServicesCompanion _toCompanion(Service s) => LocalServicesCompanion.insert(
    id: s.id,
    businessId: s.businessId,
    name: s.name,
    pricePerMinuteMinor: s.pricePerMinuteMinor,
    roundingIntervalMinutes: s.roundingIntervalMinutes,
    minimumChargeMinutes: s.minimumChargeMinutes,
    currencyCode: s.currencyCode,
    isActive: Value(s.isActive),
    archivedAt: Value(s.archivedAt),
    createdAt: s.createdAt,
    updatedAt: s.updatedAt,
    syncStatus: const Value('synced'),
  );

  Service _fromRow(LocalServiceRow row) => Service(
    id: row.id,
    businessId: row.businessId,
    name: row.name,
    pricePerMinuteMinor: row.pricePerMinuteMinor,
    roundingIntervalMinutes: row.roundingIntervalMinutes,
    minimumChargeMinutes: row.minimumChargeMinutes,
    currencyCode: row.currencyCode,
    isActive: row.isActive,
    archivedAt: row.archivedAt,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
  );
}
