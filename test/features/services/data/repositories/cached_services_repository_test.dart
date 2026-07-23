import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suretakip/core/database/app_database.dart';
import 'package:suretakip/core/errors/domain_exception.dart';
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
    repo = CachedServicesRepository(
      remote: remote,
      local: local,
    );
  });

  tearDown(() => db.close());

  test('çevrimiçi getServices sunucudan döner ve önbelleğe yazar', () async {
    remote.services = [_service('s1'), _service('s2')];
    final result = await repo.getServices(businessId: 'b1');
    expect(result.map((s) => s.id), ['s1', 's2']);
  });

  test('ağ hatasında getServices önbellekten okur', () async {
    remote.services = [_service('s1')];
    await repo.getServices(businessId: 'b1');

    remote.throwNetwork = true;
    final cached = await repo.getServices(businessId: 'b1');
    expect(cached.single.id, 's1');
  });

  test('önbellek varsa hizmetleri uzak yanıtı beklemeden döndürür', () async {
    await local.replaceServices('b1', [_service('cached')]);
    remote.servicesCompleter = Completer<List<Service>>();

    final result = await repo
        .getServices(businessId: 'b1')
        .timeout(const Duration(milliseconds: 100));

    expect(result.single.id, 'cached');
    remote.servicesCompleter!.complete([_service('fresh')]);
    await Future<void>.delayed(Duration.zero);
  });

  test('önbellek boşken tam katalog önbelleklenir, pasifler korunur', () async {
    // Regresyon: aktif-only istek, önbellekteki pasif hizmetleri SİLMEMELİ.
    final passive = _service('s2').copyWith(isActive: false);
    remote.services = [_service('s1'), passive];

    final activeOnly = await repo.getServices(businessId: 'b1');
    expect(activeOnly.map((s) => s.id), ['s1']); // filtre uygulanır

    // Ama tam katalog (pasif dahil) önbelleğe yazılmış olmalı.
    final all = await local.getServices(businessId: 'b1', includeInactive: true);
    expect(all.map((s) => s.id), containsAll(['s1', 's2']));
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
  Completer<List<Service>>? servicesCompleter;

  @override
  Future<List<Service>> getServices({
    required String businessId,
    bool includeInactive = false,
  }) async {
    if (throwNetwork) throw const NetworkException('çevrimdışı');
    final completer = servicesCompleter;
    if (completer != null) return completer.future;
    return services;
  }

  @override
  Future<Service> getService(String serviceId) async {
    if (throwNetwork) throw const NetworkException('çevrimdışı');
    return services.firstWhere((s) => s.id == serviceId);
  }

  @override
  Future<Service> createService(ServiceInput input) => throw UnimplementedError();

  @override
  Future<Service> updateService(Service service) => throw UnimplementedError();

  @override
  Future<Service> setServiceActive(String serviceId, {required bool isActive}) =>
      throw UnimplementedError();
}
