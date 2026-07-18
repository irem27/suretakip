import 'package:suretakip/core/errors/supabase_error_guard.dart';
import 'package:suretakip/core/logging/app_logger.dart';
import 'package:suretakip/core/logging/noop_app_logger.dart';
import 'package:suretakip/features/services/data/datasources/services_remote_data_source.dart';
import 'package:suretakip/features/services/domain/entities/service.dart';
import 'package:suretakip/features/services/domain/entities/service_input.dart';
import 'package:suretakip/features/services/domain/repositories/services_repository.dart';

class ServicesRepositoryImpl implements ServicesRepository {
  const ServicesRepositoryImpl(
    this._dataSource, {
    AppLogger logger = const NoopAppLogger(),
  }) : _logger = logger;
  final ServicesRemoteDataSource _dataSource;
  final AppLogger _logger;

  @override
  Future<List<Service>> getServices({
    required String businessId,
    bool includeInactive = false,
  }) => _guard(() async {
    final rows = await _dataSource.getServices(
      businessId: businessId,
      includeInactive: includeInactive,
    );
    return rows.map(_fromJson).toList(growable: false);
  });

  @override
  Future<Service> getService(String serviceId) =>
      _guard(() async => _fromJson(await _dataSource.getService(serviceId)));

  @override
  Future<Service> createService(ServiceInput input) => _guard(
    () async => _fromJson(
      await _dataSource.createService({
        'business_id': input.businessId,
        'name': input.name,
        'price_per_minute_minor': input.pricePerMinute.minorUnits,
        'rounding_interval_minutes': input.roundingIntervalMinutes,
        'minimum_charge_minutes': input.minimumChargeMinutes,
        'currency_code': input.pricePerMinute.currencyCode,
      }),
    ),
  );

  @override
  Future<Service> updateService(Service service) => _guard(
    () async => _fromJson(
      // Yalnızca düzenlenebilir alanlar; is_active/archived_at/currency/
      // business_id GÖNDERİLMEZ — bayat snapshot'ın toggle'ı ezmesini önler.
      await _dataSource.updateService({
        'id': service.id,
        'name': service.name,
        'price_per_minute_minor': service.pricePerMinuteMinor,
        'rounding_interval_minutes': service.roundingIntervalMinutes,
        'minimum_charge_minutes': service.minimumChargeMinutes,
      }),
    ),
  );

  @override
  Future<Service> setServiceActive(
    String serviceId, {
    required bool isActive,
  }) => _guard(
    () async => _fromJson(
      await _dataSource.updateService({
        'id': serviceId,
        'is_active': isActive,
        'archived_at': isActive
            ? null
            : DateTime.now().toUtc().toIso8601String(),
      }),
    ),
  );

  Service _fromJson(Map<String, dynamic> json) => Service(
    id: json['id'] as String,
    businessId: json['business_id'] as String,
    name: json['name'] as String,
    pricePerMinuteMinor: json['price_per_minute_minor'] as int,
    roundingIntervalMinutes: json['rounding_interval_minutes'] as int,
    minimumChargeMinutes: json['minimum_charge_minutes'] as int,
    currencyCode: json['currency_code'] as String,
    isActive: json['is_active'] as bool,
    archivedAt: json['archived_at'] == null
        ? null
        : DateTime.parse(json['archived_at'] as String),
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
  );

  Future<T> _guard<T>(Future<T> Function() operation) => SupabaseErrorGuard.run(
    operation,
    logger: _logger,
    context: 'ServicesRepository',
  );
}
