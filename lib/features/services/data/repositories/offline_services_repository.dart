import 'dart:async';

import 'package:uuid/uuid.dart';
import 'package:suretakip/core/database/app_database.dart';
import 'package:suretakip/core/logging/app_logger.dart';
import 'package:suretakip/core/logging/noop_app_logger.dart';
import 'package:suretakip/core/sync/device_identity.dart';
import 'package:suretakip/core/sync/sync_engine.dart';
import 'package:suretakip/features/services/data/local/services_local_data_source.dart';
import 'package:suretakip/features/services/domain/entities/service.dart';
import 'package:suretakip/features/services/domain/entities/service_input.dart';
import 'package:suretakip/features/services/domain/repositories/services_repository.dart';

/// Offline-first hizmet katalog yazımı (müşteri deseninin birebir aynısı,
/// Sprint 1). Hizmet + outbox tek transaction'da yerelde yazılır, sonra push
/// denemesi tetiklenir. UI, dönüşü beklemeden yerel önbellek üzerinden
/// kaydı anında görür.
///
/// [ServicesRepository] sözleşmesini uygular; böylece mevcut controller/UI
/// katmanı hiç değişmeden `servicesRepositoryProvider` bağlaması ile
/// çevrimdışı yazma yoluna geçer (bkz. `app_providers.dart`).
class OfflineServicesRepository implements ServicesRepository {
  OfflineServicesRepository({
    required ServicesLocalDataSource local,
    required ServicesRepository remote,
    required DeviceIdentity deviceIdentity,
    required SyncEngine syncEngine,
    // ServicesRepository sözleşmesi actorUserId almaz (mevcut controller/UI
    // katmanını değiştirmemek için); denetim izi ve outbox aktör izolasyonu
    // için oturumdaki kullanıcı buradan okunur — SyncEngine.currentActorUserId
    // ile AYNI kaynak.
    required String? Function() currentActorUserId,
    Uuid? uuid,
    DateTime Function()? clock,
    AppLogger logger = const NoopAppLogger(),
  }) : _local = local,
       _remote = remote,
       _deviceIdentity = deviceIdentity,
       _syncEngine = syncEngine,
       _currentActorUserId = currentActorUserId,
       _uuid = uuid ?? const Uuid(),
       _clock = clock ?? (() => DateTime.now().toUtc()),
       _logger = logger;

  final ServicesLocalDataSource _local;
  final ServicesRepository _remote;
  final DeviceIdentity _deviceIdentity;
  final SyncEngine _syncEngine;
  final String? Function() _currentActorUserId;
  final Uuid _uuid;
  final DateTime Function() _clock;
  final AppLogger _logger;

  /// Önbellek doluysa yerelden döner ve arka planda tam katalogu tazeler;
  /// boşsa sunucudan (tam katalog) çeker ve önbelleğe yazar.
  @override
  Future<List<Service>> getServices({
    required String businessId,
    bool includeInactive = false,
  }) async {
    final cached = await _local.getServices(
      businessId: businessId,
      includeInactive: includeInactive,
    );
    if (cached.isNotEmpty) {
      unawaited(_refreshServices(businessId));
      return cached;
    }
    final all = await _remote.getServices(
      businessId: businessId,
      includeInactive: true,
    );
    await _cache(() => _local.replaceServices(businessId, all));
    return includeInactive
        ? all
        : all.where((s) => s.isActive).toList(growable: false);
  }

  /// Proaktif önbellek ısıtma: tam hizmet katalogunu sunucudan çekip yerele
  /// yazar. Online iken (ör. giriş/dashboard) çağrılır ki çevrimdışıyken
  /// hizmetler DAİMA mevcut olsun (offline seans başlatma buna bağlı).
  Future<void> pullFromServer(String businessId) async {
    final all = await _remote.getServices(
      businessId: businessId,
      includeInactive: true,
    );
    await _cache(() => _local.replaceServices(businessId, all));
  }

  @override
  Future<Service> getService(String serviceId) async {
    final cached = await _local.getService(serviceId);
    if (cached != null) {
      unawaited(_refreshService(serviceId));
      return cached;
    }
    final service = await _remote.getService(serviceId);
    await _cache(() => _local.upsertService(service));
    return service;
  }

  /// Yeni hizmeti yerelde kalıcı yazar ve arka planda senkronizasyonu
  /// tetikler. Push başarısız olsa bile kayıt cihazda korunur.
  @override
  Future<Service> createService(ServiceInput input) async {
    final deviceId = await _deviceIdentity.getOrCreate();
    final row = await _local.enqueueCreateService(
      EnqueueCreateService(
        serviceId: _uuid.v4(),
        operationId: _uuid.v4(),
        businessId: input.businessId,
        actorUserId: _requireActorUserId(),
        deviceId: deviceId,
        name: input.name,
        pricePerMinuteMinor: input.pricePerMinute.minorUnits,
        roundingIntervalMinutes: input.roundingIntervalMinutes,
        minimumChargeMinutes: input.minimumChargeMinutes,
        currencyCode: input.pricePerMinute.currencyCode,
        now: _clock(),
      ),
    );

    // Fire-and-forget: bağlantı yoksa kayıt pending kalır, sonra denenir.
    // Arka plan sync hatası (ör. offline) çağıranı asla düşürmemelidir.
    unawaited(_syncEngine.push().catchError(_handleBackgroundSyncError));
    return _fromRow(row);
  }

  /// Var olan hizmeti yerelde günceller ve arka planda senkronizasyonu
  /// tetikler. Push başarısız olsa (ör. offline) da kayıt cihazda "bekliyor"
  /// olarak korunur; bağlantı gelince otomatik gönderilir.
  @override
  Future<Service> updateService(Service service) async {
    final deviceId = await _deviceIdentity.getOrCreate();
    final existing = await _local.findServiceRow(service.id);
    if (existing == null) {
      throw StateError('Yerel hizmet kaydı bulunamadı: ${service.id}');
    }
    final row = await _local.enqueueUpdateService(
      EnqueueUpdateService(
        serviceId: service.id,
        operationId: _uuid.v4(),
        businessId: service.businessId,
        actorUserId: _requireActorUserId(),
        deviceId: deviceId,
        name: service.name,
        pricePerMinuteMinor: service.pricePerMinuteMinor,
        roundingIntervalMinutes: service.roundingIntervalMinutes,
        minimumChargeMinutes: service.minimumChargeMinutes,
        expectedVersion: existing.serverVersion ?? 1,
        now: _clock(),
      ),
    );

    unawaited(_syncEngine.push().catchError(_handleBackgroundSyncError));
    return _fromRow(row);
  }

  /// Hizmeti yerelde aktif/pasif yapar ve arka planda senkronizasyonu
  /// tetikler. Push başarısız olsa da kayıt cihazda "bekliyor" olarak korunur.
  @override
  Future<Service> setServiceActive(
    String serviceId, {
    required bool isActive,
  }) async {
    final deviceId = await _deviceIdentity.getOrCreate();
    final existing = await _local.findServiceRow(serviceId);
    if (existing == null) {
      throw StateError('Yerel hizmet kaydı bulunamadı: $serviceId');
    }
    final row = await _local.enqueueSetServiceActive(
      EnqueueSetServiceActive(
        serviceId: serviceId,
        operationId: _uuid.v4(),
        businessId: existing.businessId,
        actorUserId: _requireActorUserId(),
        deviceId: deviceId,
        isActive: isActive,
        expectedVersion: existing.serverVersion ?? 1,
        now: _clock(),
      ),
    );

    unawaited(_syncEngine.push().catchError(_handleBackgroundSyncError));
    return _fromRow(row);
  }

  Future<void> _refreshServices(String businessId) async {
    try {
      final all = await _remote.getServices(
        businessId: businessId,
        includeInactive: true,
      );
      await _cache(() => _local.replaceServices(businessId, all));
    } catch (error, stack) {
      _logRefreshError(error, stack, 'list');
    }
  }

  Future<void> _refreshService(String serviceId) async {
    try {
      final service = await _remote.getService(serviceId);
      await _cache(() => _local.upsertService(service));
    } catch (error, stack) {
      _logRefreshError(error, stack, 'detail');
    }
  }

  void _logRefreshError(Object error, StackTrace stack, String target) {
    _logger.warn(
      error,
      stackTrace: stack,
      context: 'OfflineServicesRepository.refresh.$target',
    );
  }

  Future<void> _cache(Future<void> Function() write) async {
    try {
      await write();
    } catch (error, stack) {
      _logger.warn(
        error,
        stackTrace: stack,
        context: 'OfflineServicesRepository.cache',
      );
    }
  }

  SyncRunSummary _handleBackgroundSyncError(Object error, StackTrace stack) {
    _logger.warn(
      error,
      stackTrace: stack,
      context: 'OfflineServiceBackgroundSync',
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

  /// Oturumsuz offline yazma engellenir: outbox aktör izolasyonu (Bölüm 16.2)
  /// `originalActorUserId`'nin doğru kullanıcıya ait olmasını gerektirir.
  String _requireActorUserId() {
    final actorUserId = _currentActorUserId();
    if (actorUserId == null) {
      throw StateError('Hizmet işlemi için oturum açık bir kullanıcı gerekir.');
    }
    return actorUserId;
  }

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
