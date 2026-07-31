import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:suretakip/core/database/app_database.dart';
import 'package:suretakip/core/sync/models/sync_enums.dart';

/// Yeni müşteri oluşturma için gereken, senkronizasyondan bağımsız girdi.
final class EnqueueCreateCustomer {
  const EnqueueCreateCustomer({
    required this.customerId,
    required this.operationId,
    required this.businessId,
    required this.actorUserId,
    required this.deviceId,
    required this.name,
    required this.now,
    this.phone,
    this.email,
    this.notes,
    this.payloadVersion = 1,
  });

  final String customerId;
  final String operationId;
  final String businessId;
  final String actorUserId;
  final String deviceId;
  final String name;
  final String? phone;
  final String? email;
  final String? notes;
  final DateTime now;
  final int payloadVersion;

  /// {business_id}:{device_id}:{operation_id} (Bölüm 7.2).
  String get idempotencyKey => '$businessId:$deviceId:$operationId';
}

/// Mevcut müşteriyi güncelleme için gereken, senkronizasyondan bağımsız girdi.
final class EnqueueUpdateCustomer {
  const EnqueueUpdateCustomer({
    required this.customerId,
    required this.operationId,
    required this.businessId,
    required this.actorUserId,
    required this.deviceId,
    required this.name,
    required this.expectedVersion,
    required this.now,
    this.phone,
    this.email,
    this.notes,
    this.payloadVersion = 1,
  });

  final String customerId;
  final String operationId;
  final String businessId;
  final String actorUserId;
  final String deviceId;
  final String name;
  final String? phone;
  final String? email;
  final String? notes;

  /// Optimistic concurrency için yerelde bilinen `server_version` (Bölüm 8).
  final int expectedVersion;
  final DateTime now;
  final int payloadVersion;

  /// {business_id}:{device_id}:{operation_id} (Bölüm 7.2).
  String get idempotencyKey => '$businessId:$deviceId:$operationId';
}

/// Müşteriyi aktif/pasif yapma için gereken, senkronizasyondan bağımsız girdi.
final class EnqueueSetCustomerActive {
  const EnqueueSetCustomerActive({
    required this.customerId,
    required this.operationId,
    required this.businessId,
    required this.actorUserId,
    required this.deviceId,
    required this.isActive,
    required this.expectedVersion,
    required this.now,
    this.payloadVersion = 1,
  });

  final String customerId;
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

/// Sunucudan alınan müşteri kopyasının yerel tabloya uygulanacak alanları.
final class ServerCustomerSnapshot {
  const ServerCustomerSnapshot({
    required this.id,
    required this.businessId,
    required this.name,
    required this.isActive,
    required this.serverVersion,
    required this.createdAt,
    required this.updatedAt,
    this.phone,
    this.email,
    this.notes,
  });

  final String id;
  final String businessId;
  final String name;
  final String? phone;
  final String? email;
  final String? notes;
  final bool isActive;
  final int serverVersion;
  final DateTime createdAt;
  final DateTime updatedAt;
}

/// Müşteri okuma ve "müşteri + outbox" atomik yazımını yöneten Drift katmanı.
class CustomersLocalDataSource {
  const CustomersLocalDataSource(this._db);

  final AppDatabase _db;

  Stream<List<LocalCustomerRow>> watchCustomers({
    required String businessId,
    bool includeInactive = false,
  }) {
    return _customersQuery(
      businessId: businessId,
      includeInactive: includeInactive,
    ).watch();
  }

  /// Canlı abonelik gerektirmeyen ekranlar için tek seferlik yerel okuma.
  Future<List<LocalCustomerRow>> getCustomers({
    required String businessId,
    bool includeInactive = false,
  }) => _customersQuery(
    businessId: businessId,
    includeInactive: includeInactive,
  ).get();

  SimpleSelectStatement<$LocalCustomersTable, LocalCustomerRow>
  _customersQuery({required String businessId, required bool includeInactive}) {
    final query = _db.select(_db.localCustomers)
      ..where(
        (t) => t.businessId.equals(businessId) & t.isDeleted.equals(false),
      )
      ..orderBy([(t) => OrderingTerm(expression: t.name)]);
    if (!includeInactive) {
      query.where((t) => t.isActive.equals(true));
    }
    return query;
  }

  Future<LocalCustomerRow?> findCustomer(String id) => (_db.select(
    _db.localCustomers,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Basit Sprint 1 pull sonucunu uygular. Gönderilmemiş/çatışmalı yerel
  /// çalışma kopyaları server snapshot'ı ile ezilmez.
  Future<void> upsertServerCustomers(
    Iterable<ServerCustomerSnapshot> customers,
  ) => _db.transaction(() async {
    const dirtyStatuses = <String>{
      'localOnly',
      'pending',
      'processing',
      'retrying',
      'conflicted',
    };
    for (final customer in customers) {
      final existing = await findCustomer(customer.id);
      if (existing != null && dirtyStatuses.contains(existing.syncStatus)) {
        continue;
      }
      await _db
          .into(_db.localCustomers)
          .insertOnConflictUpdate(
            LocalCustomersCompanion.insert(
              id: customer.id,
              businessId: customer.businessId,
              name: customer.name,
              phone: Value(customer.phone),
              email: Value(customer.email),
              notes: Value(customer.notes),
              isActive: Value(customer.isActive),
              syncStatus: SyncStatus.synced.wireName,
              serverVersion: Value(customer.serverVersion),
              createdAtLocal: customer.createdAt,
              updatedAtLocal: customer.updatedAt,
              createdAtServer: Value(customer.createdAt),
              updatedAtServer: Value(customer.updatedAt),
              // Sunucu bir kaydı yeniden gönderiyorsa tombstone temizlenir;
              // silinip yeniden oluşturulan müşteri görünür olur.
              isDeleted: const Value(false),
              deletedAt: const Value(null),
            ),
          );
    }
  });

  /// Domain kaydı ve outbox kaydını TEK transaction'da yazar. `sequence_number`
  /// aynı transaction içinde üretilir (Bölüm 6).
  Future<LocalCustomerRow> enqueueCreateCustomer(
    EnqueueCreateCustomer command,
  ) {
    return _db.transaction(() async {
      final customer = LocalCustomersCompanion.insert(
        id: command.customerId,
        businessId: command.businessId,
        name: command.name,
        phone: Value(command.phone),
        email: Value(command.email),
        notes: Value(command.notes),
        syncStatus: SyncStatus.pending.wireName,
        createdAtLocal: command.now,
        updatedAtLocal: command.now,
      );
      await _db.into(_db.localCustomers).insert(customer);

      final payload = <String, Object?>{
        'id': command.customerId,
        'name': command.name,
        'phone': command.phone,
        'email': command.email,
        'notes': command.notes,
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
              aggregateType: 'customer',
              aggregateId: command.customerId,
              operationType: SyncOperationType.createCustomer.wireName,
              sequenceNumber: await _nextSequence(
                'customer',
                command.customerId,
              ),
              payloadJson: jsonEncode(payload),
              payloadVersion: Value(command.payloadVersion),
              idempotencyKey: command.idempotencyKey,
              status: SyncStatus.pending.wireName,
              createdAt: command.now,
            ),
          );

      final inserted = await findCustomer(command.customerId);
      if (inserted == null) {
        throw StateError('Yerel müşteri kaydı oluşturulamadı.');
      }
      return inserted;
    });
  }

  /// Var olan müşteriyi ve outbox kaydını TEK transaction'da yazar
  /// (`enqueueCreateCustomer` ile aynı desen). `server_version`, optimistic
  /// concurrency için yerel satırdan `expected_version` olarak okunur.
  Future<LocalCustomerRow> enqueueUpdateCustomer(
    EnqueueUpdateCustomer command,
  ) {
    return _db.transaction(() async {
      await (_db.update(
        _db.localCustomers,
      )..where((t) => t.id.equals(command.customerId))).write(
        LocalCustomersCompanion(
          name: Value(command.name),
          phone: Value(command.phone),
          email: Value(command.email),
          notes: Value(command.notes),
          syncStatus: Value(SyncStatus.pending.wireName),
          updatedAtLocal: Value(command.now),
        ),
      );

      final payload = <String, Object?>{
        'id': command.customerId,
        'name': command.name,
        'phone': command.phone,
        'email': command.email,
        'notes': command.notes,
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
              aggregateType: 'customer',
              aggregateId: command.customerId,
              operationType: SyncOperationType.updateCustomer.wireName,
              sequenceNumber: await _nextSequence(
                'customer',
                command.customerId,
              ),
              payloadJson: jsonEncode(payload),
              payloadVersion: Value(command.payloadVersion),
              idempotencyKey: command.idempotencyKey,
              expectedServerVersion: Value(command.expectedVersion),
              status: SyncStatus.pending.wireName,
              createdAt: command.now,
            ),
          );

      final updated = await findCustomer(command.customerId);
      if (updated == null) {
        throw StateError('Yerel müşteri kaydı bulunamadı.');
      }
      return updated;
    });
  }

  /// Müşteriyi aktif/pasif yapar; yalnız `is_active` alanını değiştirir ve
  /// domain kaydı + outbox kaydını TEK transaction'da yazar.
  Future<LocalCustomerRow> enqueueSetCustomerActive(
    EnqueueSetCustomerActive command,
  ) {
    return _db.transaction(() async {
      await (_db.update(
        _db.localCustomers,
      )..where((t) => t.id.equals(command.customerId))).write(
        LocalCustomersCompanion(
          isActive: Value(command.isActive),
          syncStatus: Value(SyncStatus.pending.wireName),
          updatedAtLocal: Value(command.now),
        ),
      );

      final payload = <String, Object?>{
        'id': command.customerId,
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
              aggregateType: 'customer',
              aggregateId: command.customerId,
              operationType: SyncOperationType.setCustomerActive.wireName,
              sequenceNumber: await _nextSequence(
                'customer',
                command.customerId,
              ),
              payloadJson: jsonEncode(payload),
              payloadVersion: Value(command.payloadVersion),
              idempotencyKey: command.idempotencyKey,
              expectedServerVersion: Value(command.expectedVersion),
              status: SyncStatus.pending.wireName,
              createdAt: command.now,
            ),
          );

      final updated = await findCustomer(command.customerId);
      if (updated == null) {
        throw StateError('Yerel müşteri kaydı bulunamadı.');
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
}
