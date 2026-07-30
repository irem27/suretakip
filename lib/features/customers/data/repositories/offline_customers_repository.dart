import 'dart:async';

import 'package:uuid/uuid.dart';
import 'package:suretakip/core/database/app_database.dart';
import 'package:suretakip/core/logging/app_logger.dart';
import 'package:suretakip/core/logging/noop_app_logger.dart';
import 'package:suretakip/core/sync/device_identity.dart';
import 'package:suretakip/core/sync/sync_engine.dart';
import 'package:suretakip/features/customers/data/datasources/customers_remote_data_source.dart';
import 'package:suretakip/features/customers/data/local/customers_local_data_source.dart';
import 'package:suretakip/features/customers/data/local/local_customer_mappers.dart';
import 'package:suretakip/features/customers/domain/entities/customer.dart';
import 'package:suretakip/features/customers/domain/entities/customer_input.dart';

/// Offline-first müşteri yazımı (Sprint 1). Müşteri + outbox tek transaction'da
/// yerelde oluşturulur, sonra push denemesi tetiklenir. UI, dönüşü beklemeden
/// yerel stream üzerinden kaydı anında görür.
class OfflineCustomersRepository {
  OfflineCustomersRepository({
    required CustomersLocalDataSource local,
    required CustomersRemoteDataSource remote,
    required DeviceIdentity deviceIdentity,
    required SyncEngine syncEngine,
    Uuid? uuid,
    DateTime Function()? clock,
    AppLogger logger = const NoopAppLogger(),
  }) : _local = local,
       _remote = remote,
       _deviceIdentity = deviceIdentity,
       _syncEngine = syncEngine,
       _uuid = uuid ?? const Uuid(),
       _clock = clock ?? (() => DateTime.now().toUtc()),
       _logger = logger;

  final CustomersLocalDataSource _local;
  final CustomersRemoteDataSource _remote;
  final DeviceIdentity _deviceIdentity;
  final SyncEngine _syncEngine;
  final Uuid _uuid;
  final DateTime Function() _clock;
  final AppLogger _logger;

  Stream<List<LocalCustomerRow>> watchCustomers({
    required String businessId,
    bool includeInactive = false,
  }) => _local.watchCustomers(
    businessId: businessId,
    includeInactive: includeInactive,
  );

  Stream<List<Customer>> watchCustomersDomain({
    required String businessId,
    bool includeInactive = false,
  }) => watchCustomers(
    businessId: businessId,
    includeInactive: includeInactive,
  ).map((rows) => rows.map(mapLocalCustomerToDomain).toList(growable: false));

  /// Tek müşteriyi Drift'ten okur (offline detay); yoksa null.
  Future<Customer?> getCustomer(String id) async {
    final row = await _local.findCustomer(id);
    return row == null ? null : mapLocalCustomerToDomain(row);
  }

  /// Sprint 1 mini-bootstrap: mevcut online müşteri listesini tam çeker ve
  /// yalnız temiz yerel kopyalara uygular. Delta/cursor bootstrap Sprint 2'dir.
  Future<void> pullFromServer(String businessId) async {
    final rows = await _remote.getCustomers(
      businessId: businessId,
      includeInactive: true,
    );
    await _local.upsertServerCustomers(rows.map(_serverSnapshotFromJson));
  }

  /// Yeni müşteriyi yerelde kalıcı yazar ve arka planda senkronizasyonu
  /// tetikler. Push başarısız olsa bile kayıt cihazda korunur.
  Future<LocalCustomerRow> createCustomer(
    CustomerInput input, {
    required String actorUserId,
  }) async {
    final deviceId = await _deviceIdentity.getOrCreate();
    final row = await _local.enqueueCreateCustomer(
      EnqueueCreateCustomer(
        customerId: _uuid.v4(),
        operationId: _uuid.v4(),
        businessId: input.businessId,
        actorUserId: actorUserId,
        deviceId: deviceId,
        name: input.name,
        phone: input.phone,
        email: input.email,
        notes: input.notes,
        now: _clock(),
      ),
    );

    // Fire-and-forget: bağlantı yoksa kayıt pending kalır, sonra denenir. Arka
    // plan sync hatası (ör. offline) çağıranı asla düşürmemelidir.
    unawaited(_syncEngine.push().catchError(_handleBackgroundSyncError));
    return row;
  }

  /// Var olan müşteriyi yerelde günceller ve arka planda senkronizasyonu
  /// tetikler. Push başarısız olsa (ör. offline) da kayıt cihazda "bekliyor"
  /// olarak korunur; bağlantı gelince otomatik gönderilir.
  Future<LocalCustomerRow> updateCustomer(
    Customer customer, {
    required String actorUserId,
  }) async {
    final deviceId = await _deviceIdentity.getOrCreate();
    final existing = await _local.findCustomer(customer.id);
    if (existing == null) {
      throw StateError('Yerel müşteri kaydı bulunamadı: ${customer.id}');
    }
    final row = await _local.enqueueUpdateCustomer(
      EnqueueUpdateCustomer(
        customerId: customer.id,
        operationId: _uuid.v4(),
        businessId: customer.businessId,
        actorUserId: actorUserId,
        deviceId: deviceId,
        name: customer.name,
        phone: customer.phone,
        email: customer.email,
        notes: customer.notes,
        expectedVersion: existing.serverVersion ?? 1,
        now: _clock(),
      ),
    );

    unawaited(_syncEngine.push().catchError(_handleBackgroundSyncError));
    return row;
  }

  /// Müşteriyi yerelde aktif/pasif yapar ve arka planda senkronizasyonu
  /// tetikler. Push başarısız olsa da kayıt cihazda "bekliyor" olarak korunur.
  Future<LocalCustomerRow> setCustomerActive(
    String customerId, {
    required bool isActive,
    required String actorUserId,
  }) async {
    final deviceId = await _deviceIdentity.getOrCreate();
    final existing = await _local.findCustomer(customerId);
    if (existing == null) {
      throw StateError('Yerel müşteri kaydı bulunamadı: $customerId');
    }
    final row = await _local.enqueueSetCustomerActive(
      EnqueueSetCustomerActive(
        customerId: customerId,
        operationId: _uuid.v4(),
        businessId: existing.businessId,
        actorUserId: actorUserId,
        deviceId: deviceId,
        isActive: isActive,
        expectedVersion: existing.serverVersion ?? 1,
        now: _clock(),
      ),
    );

    unawaited(_syncEngine.push().catchError(_handleBackgroundSyncError));
    return row;
  }

  SyncRunSummary _handleBackgroundSyncError(Object error, StackTrace stack) {
    _logger.warn(
      error,
      stackTrace: stack,
      context: 'OfflineCustomerBackgroundSync',
    );
    return const SyncRunSummary(
      pushed: 0,
      retried: 0,
      failed: 0,
      authRequired: false,
    );
  }

  /// Bekleyen tüm kayıtları göndermeyi dener (uygulama açılışı, foreground,
  /// "şimdi senkronize et" gibi tetikleyiciler için).
  Future<SyncRunSummary> sync() => _syncEngine.push();

  ServerCustomerSnapshot _serverSnapshotFromJson(Map<String, dynamic> json) {
    return ServerCustomerSnapshot(
      id: json['id'] as String,
      businessId: json['business_id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      notes: json['notes'] as String?,
      isActive: json['is_active'] as bool,
      serverVersion: json['server_version'] as int,
      createdAt: _dateTime(json['created_at']),
      updatedAt: _dateTime(json['updated_at']),
    );
  }

  DateTime _dateTime(Object? value) {
    if (value is DateTime) return value;
    if (value is String) return DateTime.parse(value);
    throw const FormatException('Geçersiz müşteri zaman damgası.');
  }
}
