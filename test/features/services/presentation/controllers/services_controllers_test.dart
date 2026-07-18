import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suretakip/app/providers/app_providers.dart';
import 'package:suretakip/core/value_objects/money.dart';
import 'package:suretakip/features/businesses/domain/entities/business.dart';
import 'package:suretakip/features/services/domain/entities/service.dart';
import 'package:suretakip/features/services/domain/entities/service_input.dart';
import 'package:suretakip/features/services/domain/repositories/services_repository.dart';
import 'package:suretakip/features/services/presentation/controllers/services_controllers.dart';

void main() {
  test('liste controller aktif işletmenin tüm hizmetlerini yükler', () async {
    final repository = _FakeServicesRepository(services: [_service()]);
    final container = _container(repository);
    addTearDown(container.dispose);

    final state = await container.read(
      servicesListControllerProvider(_scope).future,
    );

    expect(state.services, hasLength(1));
    expect(repository.businessId, 'business-1');
    expect(repository.includeInactive, isTrue);
  });

  test('liste controller pasif filtreyi immutable state ile uygular', () async {
    final repository = _FakeServicesRepository(
      services: [
        _service(),
        _service(id: 'service-2', isActive: false),
      ],
    );
    final container = _container(repository);
    addTearDown(container.dispose);
    final provider = servicesListControllerProvider(_scope);
    final subscription = container.listen(
      provider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);
    await container.read(provider.future);

    await container
        .read(provider.notifier)
        .setFilter(ServiceStatusFilter.inactive);

    final state = container.read(provider).requireValue;
    expect(state.visibleServices.single.id, 'service-2');
    expect(repository.includeInactive, isTrue);
  });

  test('form controller ServiceInput ile hizmet oluşturur', () async {
    final repository = _FakeServicesRepository();
    final container = _container(repository);
    addTearDown(container.dispose);
    final input = ServiceInput(
      businessId: 'business-1',
      name: 'Bilardo',
      pricePerMinute: Money(minorUnits: 250, currencyCode: 'TRY'),
      roundingIntervalMinutes: 5,
      minimumChargeMinutes: 10,
    );

    final created = await container
        .read(serviceFormControllerProvider.notifier)
        .create(input);

    expect(created?.id, 'service-1');
    expect(repository.createdInput, same(input));
  });

  test(
    'form controller güncellenen tam entityyi repositoryye iletir',
    () async {
      final repository = _FakeServicesRepository();
      final container = _container(repository);
      addTearDown(container.dispose);
      final inactive = _service().copyWith(
        isActive: false,
        archivedAt: DateTime.utc(2026, 7, 17),
      );

      final updated = await container
          .read(serviceFormControllerProvider.notifier)
          .updateService(inactive);

      expect(updated?.isActive, isFalse);
      expect(repository.updatedService, inactive);
    },
  );

  test(
    'setActive yalnızca id ve durumu iletir (tam entity göndermez)',
    () async {
      final repository = _FakeServicesRepository(services: [_service()]);
      final container = _container(repository);
      addTearDown(container.dispose);

      final ok = await container
          .read(serviceFormControllerProvider.notifier)
          .setActive('service-1', isActive: false);

      expect(ok, isTrue);
      expect(repository.toggledId, 'service-1');
      expect(repository.toggledActive, isFalse);
      // Toggle yolu updateService'i (tam entity) HİÇ çağırmamalı.
      expect(repository.updatedService, isNull);
    },
  );
}

const BusinessScope _scope = (businessId: 'business-1', generation: 0);

ProviderContainer _container(_FakeServicesRepository repository) =>
    ProviderContainer(
      overrides: [
        servicesRepositoryProvider.overrideWithValue(repository),
        activeBusinessProvider.overrideWithValue(_business()),
      ],
    );

Business _business() => Business(
  id: 'business-1',
  name: 'Test İşletmesi',
  currencyCode: 'TRY',
  timezone: 'Europe/Istanbul',
  isActive: true,
  archivedAt: null,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

Service _service({String id = 'service-1', bool isActive = true}) => Service(
  id: id,
  businessId: 'business-1',
  name: 'Oyun Bilgisayarı',
  pricePerMinuteMinor: 350,
  roundingIntervalMinutes: 5,
  minimumChargeMinutes: 15,
  currencyCode: 'TRY',
  isActive: isActive,
  archivedAt: isActive ? null : DateTime.utc(2026, 7, 17),
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

class _FakeServicesRepository implements ServicesRepository {
  _FakeServicesRepository({List<Service>? services})
    : services = services ?? [_service()];

  final List<Service> services;
  String? businessId;
  bool? includeInactive;
  ServiceInput? createdInput;
  Service? updatedService;
  String? toggledId;
  bool? toggledActive;

  @override
  Future<Service> createService(ServiceInput input) async {
    createdInput = input;
    return _service().copyWith(
      name: input.name,
      pricePerMinuteMinor: input.pricePerMinute.minorUnits,
      roundingIntervalMinutes: input.roundingIntervalMinutes,
      minimumChargeMinutes: input.minimumChargeMinutes,
      currencyCode: input.pricePerMinute.currencyCode,
    );
  }

  @override
  Future<Service> getService(String serviceId) async =>
      services.firstWhere((service) => service.id == serviceId);

  @override
  Future<List<Service>> getServices({
    required String businessId,
    bool includeInactive = false,
  }) async {
    this.businessId = businessId;
    this.includeInactive = includeInactive;
    return includeInactive
        ? services
        : services.where((service) => service.isActive).toList();
  }

  @override
  Future<Service> updateService(Service service) async {
    updatedService = service;
    return service;
  }

  @override
  Future<Service> setServiceActive(
    String serviceId, {
    required bool isActive,
  }) async {
    toggledId = serviceId;
    toggledActive = isActive;
    return services
        .firstWhere((service) => service.id == serviceId)
        .copyWith(
          isActive: isActive,
          archivedAt: isActive ? null : DateTime.utc(2026, 7, 17),
        );
  }
}
