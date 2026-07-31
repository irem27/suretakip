import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suretakip/core/database/app_database.dart';
import 'package:suretakip/core/errors/domain_exception.dart';
import 'package:suretakip/core/value_objects/money.dart';
import 'package:suretakip/features/services/data/local/services_local_data_source.dart';
import 'package:suretakip/features/services/data/repositories/cached_services_repository.dart';
import 'package:suretakip/features/services/domain/entities/service.dart';
import 'package:suretakip/features/services/domain/entities/service_input.dart';
import 'package:suretakip/features/services/domain/repositories/services_repository.dart';

void main() {
  late AppDatabase db;
  late CachedServicesRepository repo;
  late _FakeRemote remote;
  late ServicesLocalDataSource local;

  setUp(() {
    db = AppDatabase.forExecutor(NativeDatabase.memory());
    remote = _FakeRemote();
    local = ServicesLocalDataSource(db);
    repo = CachedServicesRepository(remote: remote, local: local);
  });

  tearDown(() => db.close());

  test('önbellekte varsa getService anında döner ve arkada tazeler', () async {
    await local.upsertService(_service('cached'));
    remote.services = [_service('cached')];

    final result = await repo.getService('cached');

    expect(result.id, 'cached');
  });

  test(
    'önbellek boşken getService sunucudan çeker ve önbelleğe yazar',
    () async {
      remote.services = [_service('s1')];

      final result = await repo.getService('s1');

      expect(result.id, 's1');
      expect((await local.getService('s1'))?.id, 's1');
    },
  );

  test('önbellek boşken ağ hatası getService için yükseltilir', () async {
    remote.throwNetwork = true;
    expect(repo.getService('s1'), throwsA(isA<NetworkException>()));
  });

  test(
    'önbellek boşken getServices ağ hatasında boş liste döner (throw yerine)',
    () async {
      remote.throwNetwork = true;
      final result = await repo.getServices(businessId: 'b1');
      expect(result, isEmpty);
    },
  );

  test('createService sunucuya iletir ve sonucu önbelleğe yazar', () async {
    final input = ServiceInput(
      businessId: 'b1',
      name: 'Yeni Hizmet',
      pricePerMinute: Money(minorUnits: 300, currencyCode: 'TRY'),
      roundingIntervalMinutes: 15,
      minimumChargeMinutes: 10,
    );
    remote.createServiceResult = _service('created');

    final result = await repo.createService(input);

    expect(result.id, 'created');
    expect(remote.createServiceCalls.single, input);
    expect((await local.getService('created'))?.id, 'created');
  });

  test('updateService sunucuya iletir ve sonucu önbelleğe yazar', () async {
    final updated = _service('s1');

    final result = await repo.updateService(updated);

    expect(result.id, 's1');
    expect(remote.updateServiceCalls, [updated]);
    expect((await local.getService('s1'))?.id, 's1');
  });

  test('setServiceActive sunucuya iletir ve sonucu önbelleğe yazar', () async {
    remote.setActiveResult = _service('s1').copyWith(isActive: false);

    final result = await repo.setServiceActive('s1', isActive: false);

    expect(result.isActive, isFalse);
    expect(remote.setActiveCalls.single, ('s1', false));
    expect((await local.getService('s1'))?.isActive, isFalse);
  });
}

Service _service(String id) => Service(
  id: id,
  businessId: 'b1',
  name: 'Hizmet $id',
  pricePerMinuteMinor: 250,
  roundingIntervalMinutes: 15,
  minimumChargeMinutes: 10,
  currencyCode: 'TRY',
  isActive: true,
  archivedAt: null,
  createdAt: DateTime.utc(2026, 7, 1),
  updatedAt: DateTime.utc(2026, 7, 1),
);

class _FakeRemote implements ServicesRepository {
  List<Service> services = const [];
  bool throwNetwork = false;

  final List<ServiceInput> createServiceCalls = [];
  final List<Service> updateServiceCalls = [];
  final List<(String, bool)> setActiveCalls = [];

  Service? createServiceResult;
  Service? setActiveResult;

  @override
  Future<List<Service>> getServices({
    required String businessId,
    bool includeInactive = false,
  }) async {
    if (throwNetwork) throw const NetworkException('çevrimdışı');
    return services;
  }

  @override
  Future<Service> getService(String serviceId) async {
    if (throwNetwork) throw const NetworkException('çevrimdışı');
    return services.firstWhere((s) => s.id == serviceId);
  }

  @override
  Future<Service> createService(ServiceInput input) async {
    createServiceCalls.add(input);
    return createServiceResult!;
  }

  @override
  Future<Service> updateService(Service service) async {
    updateServiceCalls.add(service);
    return service;
  }

  @override
  Future<Service> setServiceActive(
    String serviceId, {
    required bool isActive,
  }) async {
    setActiveCalls.add((serviceId, isActive));
    return setActiveResult!;
  }
}
