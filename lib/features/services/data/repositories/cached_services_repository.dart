import 'dart:async';

import 'package:suretakip/core/errors/domain_exception.dart';
import 'package:suretakip/core/logging/app_logger.dart';
import 'package:suretakip/core/logging/noop_app_logger.dart';
import 'package:suretakip/features/services/data/local/services_local_data_source.dart';
import 'package:suretakip/features/services/domain/entities/service.dart';
import 'package:suretakip/features/services/domain/entities/service_input.dart';
import 'package:suretakip/features/services/domain/repositories/services_repository.dart';

/// Hizmet okumalarını local-first stale-while-revalidate önbellekle sarar.
/// Önbellek doluysa UI hemen açılır, sunucu yenilemesi arka planda çalışır.
/// Yazma internet ister.
class CachedServicesRepository implements ServicesRepository {
  CachedServicesRepository({
    required ServicesRepository remote,
    required ServicesLocalDataSource local,
    AppLogger logger = const NoopAppLogger(),
  }) : _remote = remote,
       _local = local,
       _logger = logger;

  final ServicesRepository _remote;
  final ServicesLocalDataSource _local;
  final AppLogger _logger;

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
    try {
      // Önbellek boş: tam katalog (pasif dahil) çekilir ki yönetim görünümü de
      // çevrimdışı doğru çalışsın; istenen filtre burada uygulanır.
      final all = await _remote.getServices(
        businessId: businessId,
        includeInactive: true,
      );
      await _cache(() => _local.replaceServices(businessId, all));
      return includeInactive
          ? all
          : all.where((s) => s.isActive).toList(growable: false);
    } on NetworkException {
      return cached;
    }
  }

  @override
  Future<Service> getService(String serviceId) async {
    final cached = await _local.getService(serviceId);
    if (cached != null) {
      unawaited(_refreshService(serviceId));
      return cached;
    }
    try {
      final service = await _remote.getService(serviceId);
      await _cache(() => _local.upsertService(service));
      return service;
    } on NetworkException {
      rethrow;
    }
  }

  @override
  Future<Service> createService(ServiceInput input) async {
    final created = await _remote.createService(input);
    await _cache(() => _local.upsertService(created));
    return created;
  }

  @override
  Future<Service> updateService(Service service) async {
    final updated = await _remote.updateService(service);
    await _cache(() => _local.upsertService(updated));
    return updated;
  }

  @override
  Future<Service> setServiceActive(
    String serviceId, {
    required bool isActive,
  }) async {
    final updated = await _remote.setServiceActive(
      serviceId,
      isActive: isActive,
    );
    await _cache(() => _local.upsertService(updated));
    return updated;
  }

  /// Arka plan yenilemesi her zaman TAM katalogu (pasif dahil) çeker; böylece
  /// aktif-only bir görünüm önbellekteki pasif kayıtları silmez.
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
      context: 'CachedServicesRepository.refresh.$target',
    );
  }

  Future<void> _cache(Future<void> Function() write) async {
    try {
      await write();
    } catch (error, stack) {
      _logger.warn(
        error,
        stackTrace: stack,
        context: 'CachedServicesRepository.cache',
      );
    }
  }
}
