import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suretakip/app/providers/app_providers.dart';
import 'package:suretakip/app/providers/business_selection_controller.dart';
import 'package:suretakip/features/auth/domain/entities/auth_session_state.dart';
import 'package:suretakip/features/businesses/domain/entities/business.dart';
import 'package:suretakip/features/businesses/domain/entities/business_member.dart';
import 'package:suretakip/features/businesses/domain/repositories/businesses_repository.dart';

void main() {
  group('BusinessSelectionController', () {
    test('aynı işletme tekrar seçilirse nesil ilerlemez', () async {
      final repository = _FakeBusinessesRepository(
        businesses: [_business('business-1'), _business('business-2')],
      );
      final container = _container(repository);
      addTearDown(container.dispose);

      await container.read(userBusinessesProvider.future);
      expect(container.read(activeBusinessProvider)?.id, 'business-1');
      final initialGeneration = container.read(businessScopeGenerationProvider);

      container
          .read(businessSelectionControllerProvider.notifier)
          .selectBusiness('business-1');

      expect(
        container.read(businessScopeGenerationProvider),
        initialGeneration,
      );
    });

    test('geçersiz işletme kimliği aktif işletmeyi değiştirmiyorsa '
        'nesil ilerlemez', () async {
      final repository = _FakeBusinessesRepository(
        businesses: [_business('business-1')],
      );
      final container = _container(repository);
      addTearDown(container.dispose);

      await container.read(userBusinessesProvider.future);
      expect(container.read(activeBusinessProvider)?.id, 'business-1');
      final initialGeneration = container.read(businessScopeGenerationProvider);

      container
          .read(businessSelectionControllerProvider.notifier)
          .selectBusiness('missing-business');

      expect(container.read(activeBusinessProvider)?.id, 'business-1');
      expect(
        container.read(businessScopeGenerationProvider),
        initialGeneration,
      );
    });

    test('farklı işletme seçildiğinde nesil ilerler', () async {
      final repository = _FakeBusinessesRepository(
        businesses: [_business('business-1'), _business('business-2')],
      );
      final container = _container(repository);
      addTearDown(container.dispose);

      await container.read(userBusinessesProvider.future);
      final initialGeneration = container.read(businessScopeGenerationProvider);

      container
          .read(businessSelectionControllerProvider.notifier)
          .selectBusiness('business-2');

      expect(container.read(activeBusinessProvider)?.id, 'business-2');
      expect(
        container.read(businessScopeGenerationProvider),
        initialGeneration + 1,
      );
    });
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
  _FakeBusinessesRepository({required this.businesses});

  final List<Business> businesses;

  @override
  Future<List<Business>> getBusinesses() async => businesses;

  @override
  Future<List<BusinessMember>> getMembers(String businessId) async => const [];

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
