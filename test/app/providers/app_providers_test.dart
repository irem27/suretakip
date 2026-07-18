import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suretakip/app/providers/app_providers.dart';
import 'package:suretakip/app/providers/business_selection_controller.dart';
import 'package:suretakip/core/domain/domain_enums.dart';
import 'package:suretakip/features/auth/domain/entities/auth_session_state.dart';
import 'package:suretakip/features/businesses/domain/entities/business.dart';
import 'package:suretakip/features/businesses/domain/entities/business_capabilities.dart';
import 'package:suretakip/features/businesses/domain/entities/business_member.dart';
import 'package:suretakip/features/businesses/domain/repositories/businesses_repository.dart';
import 'package:suretakip/features/customers/presentation/controllers/customers_controllers.dart';
import 'package:suretakip/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:suretakip/features/history/presentation/controllers/history_controller.dart';
import 'package:suretakip/features/products/presentation/controllers/products_controllers.dart';
import 'package:suretakip/features/reports/presentation/controllers/reports_controller.dart';
import 'package:suretakip/features/services/domain/entities/service.dart';
import 'package:suretakip/features/services/domain/repositories/services_repository.dart';
import 'package:suretakip/features/services/presentation/controllers/services_controllers.dart';
import 'package:suretakip/features/sessions/presentation/controllers/sessions_controllers.dart';

void main() {
  test(
    'ikinci işletme seçilir ve kaldırılan üyelik güvenle temizlenir',
    () async {
      final repository = _FakeBusinessesRepository(
        businesses: [_business('business-1'), _business('business-2')],
      );
      final container = _container(repository);
      addTearDown(container.dispose);

      await container.read(userBusinessesProvider.future);
      expect(container.read(activeBusinessProvider)?.id, 'business-1');

      container
          .read(selectedBusinessIdProvider.notifier)
          .selectBusiness('business-2');
      expect(container.read(selectedBusinessIdProvider), 'business-2');
      expect(container.read(activeBusinessProvider)?.id, 'business-2');

      repository.businesses = [_business('business-1')];
      container.invalidate(userBusinessesProvider);
      await container.read(userBusinessesProvider.future);

      expect(container.read(selectedBusinessIdProvider), isNull);
      expect(container.read(activeBusinessProvider)?.id, 'business-1');
    },
  );

  test('boş veya geçersiz aktif işletme listesi null döndürür', () async {
    final repository = _FakeBusinessesRepository(
      businesses: [_business('business-1', isActive: false)],
    );
    final container = _container(repository);
    addTearDown(container.dispose);

    await container.read(userBusinessesProvider.future);
    container
        .read(selectedBusinessIdProvider.notifier)
        .selectBusiness('missing');

    expect(container.read(selectedBusinessIdProvider), isNull);
    expect(container.read(activeBusinessProvider), isNull);
  });

  test('currentMember yalnızca aktif kullanıcı üyeliğini döndürür', () async {
    final repository = _FakeBusinessesRepository(
      businesses: [_business('business-1')],
      members: [
        _member(role: MemberRole.staff, isActive: false),
        _member(id: 'member-2', role: MemberRole.admin),
      ],
    );
    final container = _container(repository);
    addTearDown(container.dispose);

    await container.read(userBusinessesProvider.future);
    final scope = container.read(activeBusinessScopeProvider);
    final member = await container.read(currentMemberProvider(scope).future);

    expect(member?.id, 'member-2');
    expect(member?.role, MemberRole.admin);
    expect(repository.requestedBusinessIds, ['business-1']);
  });

  test('rol matrisi owner, admin ve staff için sunucu ile eşleşir', () {
    for (final role in [MemberRole.owner, MemberRole.admin]) {
      final capabilities = BusinessCapabilities.forRole(role);
      expect(capabilities.canManageCatalog, isTrue);
      expect(capabilities.canManageMembers, isTrue);
      expect(capabilities.canEditBusinessSettings, isTrue);
      expect(capabilities.canCancelCompletedSession, isTrue);
    }

    final staff = BusinessCapabilities.forRole(MemberRole.staff);
    expect(staff.canManageCatalog, isFalse);
    expect(staff.canManageMembers, isFalse);
    expect(staff.canEditBusinessSettings, isFalse);
    expect(staff.canCancelCompletedSession, isFalse);
    expect(
      BusinessCapabilities.canManageMemberRow(
        actorRole: MemberRole.admin,
        targetRole: MemberRole.owner,
      ),
      isFalse,
    );
    expect(
      BusinessCapabilities.canManageMemberRow(
        actorRole: MemberRole.admin,
        targetRole: MemberRole.staff,
      ),
      isTrue,
    );
  });

  test('işletme değişiminde eski hizmet state’i hemen yok edilir', () async {
    final businessesRepository = _FakeBusinessesRepository(
      businesses: [_business('business-1'), _business('business-2')],
    );
    final servicesRepository = _FakeServicesRepository();
    final container = ProviderContainer(
      overrides: [
        authSessionStateProvider.overrideWith(
          (ref) => Stream.value(const AuthSessionState(userId: 'user-1')),
        ),
        businessesRepositoryProvider.overrideWithValue(businessesRepository),
        servicesRepositoryProvider.overrideWithValue(servicesRepository),
      ],
    );
    addTearDown(container.dispose);

    await container.read(userBusinessesProvider.future);
    final firstScope = container.read(activeBusinessScopeProvider);
    final firstProvider = servicesListControllerProvider(firstScope);
    final subscription = container.listen(
      firstProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);
    final firstState = await container.read(firstProvider.future);
    expect(firstState.services.single.businessId, 'business-1');

    container
        .read(businessSelectionControllerProvider.notifier)
        .selectBusiness('business-2');

    final secondScope = container.read(activeBusinessScopeProvider);
    expect(secondScope, isNot(firstScope));
    expect(
      container.read(servicesListControllerProvider(secondScope)).valueOrNull,
      isNull,
    );
    expect(
      container.read(productsListControllerProvider(secondScope)).valueOrNull,
      isNull,
    );
    expect(
      container.read(customersListControllerProvider(secondScope)).valueOrNull,
      isNull,
    );
    expect(
      container.read(sessionsListControllerProvider(secondScope)).valueOrNull,
      isNull,
    );
    expect(
      container.read(dashboardControllerProvider(secondScope)).valueOrNull,
      isNull,
    );
    expect(
      container.read(historyControllerProvider(secondScope)).valueOrNull,
      isNull,
    );
    expect(
      container.read(reportsControllerProvider(secondScope)).valueOrNull,
      isNull,
    );
    final secondState = await container.read(
      servicesListControllerProvider(secondScope).future,
    );
    expect(secondState.services.single.businessId, 'business-2');
    expect(servicesRepository.requestedBusinessIds, [
      'business-1',
      'business-2',
    ]);
  });
}

ProviderContainer _container(_FakeBusinessesRepository repository) =>
    ProviderContainer(
      overrides: [
        authSessionStateProvider.overrideWith(
          (ref) => Stream.value(const AuthSessionState(userId: 'user-1')),
        ),
        businessesRepositoryProvider.overrideWithValue(repository),
      ],
    );

class _FakeBusinessesRepository implements BusinessesRepository {
  _FakeBusinessesRepository({
    required this.businesses,
    this.members = const [],
  });

  List<Business> businesses;
  final List<BusinessMember> members;
  final List<String> requestedBusinessIds = [];

  @override
  Future<List<Business>> getBusinesses() async => businesses;

  @override
  Future<List<BusinessMember>> getMembers(String businessId) async {
    requestedBusinessIds.add(businessId);
    return members;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeServicesRepository implements ServicesRepository {
  final List<String> requestedBusinessIds = [];

  @override
  Future<List<Service>> getServices({
    required String businessId,
    bool includeInactive = false,
  }) async {
    requestedBusinessIds.add(businessId);
    return [_service(businessId)];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Business _business(String id, {bool isActive = true}) => Business(
  id: id,
  name: id,
  currencyCode: 'TRY',
  timezone: 'Europe/Istanbul',
  isActive: isActive,
  archivedAt: null,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

BusinessMember _member({
  String id = 'member-1',
  MemberRole role = MemberRole.staff,
  bool isActive = true,
}) => BusinessMember(
  id: id,
  businessId: 'business-1',
  userId: 'user-1',
  role: role,
  isActive: isActive,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

Service _service(String businessId) => Service(
  id: 'service-$businessId',
  businessId: businessId,
  name: businessId,
  pricePerMinuteMinor: 100,
  roundingIntervalMinutes: 1,
  minimumChargeMinutes: 1,
  currencyCode: 'TRY',
  isActive: true,
  archivedAt: null,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);
