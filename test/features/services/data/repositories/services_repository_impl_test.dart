import 'package:flutter_test/flutter_test.dart';
import 'package:suretakip/features/services/data/datasources/services_remote_data_source.dart';
import 'package:suretakip/features/services/data/repositories/services_repository_impl.dart';
import 'package:suretakip/features/services/domain/entities/service.dart';

void main() {
  test('updateService durum/arşiv kolonlarını göndermez', () async {
    final dataSource = _FakeServicesDataSource();
    final repository = ServicesRepositoryImpl(dataSource);

    await repository.updateService(_service());

    final values = dataSource.updatedValues!;
    // Durum yalnız setServiceActive ile değişir; burada gönderilirse
    // eşzamanlı aktif/pasif toggle ezilir.
    expect(values.containsKey('is_active'), isFalse);
    expect(values.containsKey('archived_at'), isFalse);
    expect(values.keys.toSet(), {
      'id',
      'name',
      'price_per_minute_minor',
      'rounding_interval_minutes',
      'minimum_charge_minutes',
    });
  });

  test('setServiceActive yalnızca durum kolonlarını gönderir', () async {
    final dataSource = _FakeServicesDataSource();
    final repository = ServicesRepositoryImpl(dataSource);

    await repository.setServiceActive('service-1', isActive: false);

    final values = dataSource.updatedValues!;
    expect(values.keys.toSet(), {'id', 'is_active', 'archived_at'});
    expect(values['is_active'], isFalse);
    expect(values['archived_at'], isNotNull);
  });
}

Service _service() => Service(
  id: 'service-1',
  businessId: 'business-1',
  name: 'Koltuk',
  pricePerMinuteMinor: 250,
  roundingIntervalMinutes: 15,
  minimumChargeMinutes: 10,
  currencyCode: 'TRY',
  isActive: true,
  archivedAt: null,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

Map<String, dynamic> _row() => {
  'id': 'service-1',
  'business_id': 'business-1',
  'name': 'Koltuk',
  'price_per_minute_minor': 250,
  'rounding_interval_minutes': 15,
  'minimum_charge_minutes': 10,
  'currency_code': 'TRY',
  'is_active': true,
  'archived_at': null,
  'created_at': '2026-01-01T00:00:00Z',
  'updated_at': '2026-01-01T00:00:00Z',
};

class _FakeServicesDataSource implements ServicesRemoteDataSource {
  Map<String, Object?>? updatedValues;

  @override
  Future<Map<String, dynamic>> updateService(
    Map<String, Object?> values,
  ) async {
    updatedValues = values;
    return _row();
  }

  @override
  Future<Map<String, dynamic>> createService(
    Map<String, Object?> values,
  ) async => _row();

  @override
  Future<Map<String, dynamic>> getService(String id) async => _row();

  @override
  Future<List<Map<String, dynamic>>> getServices({
    required String businessId,
    required bool includeInactive,
  }) async => [_row()];
}
