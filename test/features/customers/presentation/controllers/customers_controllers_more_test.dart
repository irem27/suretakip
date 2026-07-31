import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suretakip/app/providers/app_providers.dart';
import 'package:suretakip/app/providers/sync_providers.dart';
import 'package:suretakip/core/auth/sync_session_guard.dart';
import 'package:suretakip/core/database/app_database.dart';
import 'package:suretakip/core/errors/domain_exception.dart';
import 'package:suretakip/core/sync/customer_sync_rpc.dart';
import 'package:suretakip/core/sync/models/sync_enums.dart';
import 'package:suretakip/core/sync/models/sync_push_result.dart';
import 'package:suretakip/core/sync/session_sync_rpc.dart';
import 'package:suretakip/features/businesses/domain/entities/business.dart';
import 'package:suretakip/features/customers/data/datasources/customers_remote_data_source.dart';
import 'package:suretakip/features/customers/domain/entities/customer.dart';
import 'package:suretakip/features/customers/domain/entities/customer_input.dart';
import 'package:suretakip/features/customers/domain/repositories/customers_repository.dart';
import 'package:suretakip/features/customers/presentation/controllers/customers_controllers.dart';

const BusinessScope _scope = (businessId: 'business-1', generation: 0);

void main() {
  group('CustomersListController - işletme yoksa', () {
    test('boş durum döner', () async {
      final container = ProviderContainer(
        overrides: [activeBusinessProvider.overrideWithValue(_business())],
      );
      addTearDown(container.dispose);
      const scope = (businessId: null, generation: 0);

      final state = await container.read(
        customersListControllerProvider(scope).future,
      );

      expect(state.customers, isEmpty);
    });

    test('refresh businessId null ise sunucu çağrısı yapmaz', () async {
      final db = AppDatabase.forExecutor(NativeDatabase.memory());
      addTearDown(db.close);
      final container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);
      const scope = (businessId: null, generation: 0);

      await container.read(customersListControllerProvider(scope).future);
      await container
          .read(customersListControllerProvider(scope).notifier)
          .refresh();
    });
  });

  group('CustomerFormController - üyelik hazır değilse', () {
    test('create üyelik hazır değilse ValidationException üretir', () async {
      final container = ProviderContainer(
        overrides: [
          activeBusinessScopeProvider.overrideWithValue(_scope),
          currentMemberProvider(_scope).overrideWith((ref) async => null),
        ],
      );
      addTearDown(container.dispose);

      final created = await container
          .read(customerFormControllerProvider.notifier)
          .create(const CustomerInput(businessId: 'business-1', name: 'Test'));

      expect(created, isNull);
      final state = container.read(customerFormControllerProvider);
      expect(state.hasError, isTrue);
      expect(state.error, isA<ValidationException>());
    });

    test(
      'updateCustomer üyelik hazır değilse ValidationException üretir',
      () async {
        final container = ProviderContainer(
          overrides: [
            activeBusinessScopeProvider.overrideWithValue(_scope),
            currentMemberProvider(_scope).overrideWith((ref) async => null),
          ],
        );
        addTearDown(container.dispose);

        final updated = await container
            .read(customerFormControllerProvider.notifier)
            .updateCustomer(_customer());

        expect(updated, isNull);
        expect(
          container.read(customerFormControllerProvider).error,
          isA<ValidationException>(),
        );
      },
    );

    test('setActive üyelik hazır değilse false döner', () async {
      final container = ProviderContainer(
        overrides: [
          activeBusinessScopeProvider.overrideWithValue(_scope),
          currentMemberProvider(_scope).overrideWith((ref) async => null),
        ],
      );
      addTearDown(container.dispose);

      final ok = await container
          .read(customerFormControllerProvider.notifier)
          .setActive('customer-1', isActive: false);

      expect(ok, isFalse);
    });
  });

  test('customerDetailProvider yerelde yoksa online repoya düşer', () async {
    final db = AppDatabase.forExecutor(NativeDatabase.memory());
    addTearDown(db.close);
    final onlineRepository = _FakeCustomersRepository(
      customers: [_customer(name: 'Online Müşteri')],
    );
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        activeBusinessProvider.overrideWithValue(_business()),
        activeBusinessScopeProvider.overrideWithValue(_scope),
        customersRepositoryProvider.overrideWithValue(onlineRepository),
        customersRemoteDataSourceProvider.overrideWithValue(
          _NoopCustomersRemoteDataSource(),
        ),
        customerSyncApiProvider.overrideWithValue(_NoopCustomerApi()),
        sessionSyncApiProvider.overrideWithValue(_NoopSessionApi()),
        syncSessionGuardProvider.overrideWithValue(_AuthRequiredGuard()),
      ],
    );
    addTearDown(container.dispose);

    final customer = await container.read(
      customerDetailProvider('customer-1').future,
    );

    expect(customer.name, 'Online Müşteri');
  });
}

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

Customer _customer({String id = 'customer-1', String name = 'Ahmet Erdemir'}) =>
    Customer(
      id: id,
      businessId: 'business-1',
      name: name,
      phone: null,
      email: null,
      notes: null,
      isActive: true,
      archivedAt: null,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );

class _FakeCustomersRepository implements CustomersRepository {
  _FakeCustomersRepository({List<Customer>? customers})
    : customers = customers ?? [_customer()];

  final List<Customer> customers;

  @override
  Future<Customer> getCustomer(String customerId) async =>
      customers.firstWhere((customer) => customer.id == customerId);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoopCustomersRemoteDataSource implements CustomersRemoteDataSource {
  @override
  Future<List<Map<String, dynamic>>> getCustomers({
    required String businessId,
    required bool includeInactive,
  }) async => const [];

  @override
  Future<Map<String, dynamic>> createCustomer(Map<String, Object?> values) =>
      throw UnimplementedError();

  @override
  Future<Map<String, dynamic>> getCustomer(String id) =>
      throw UnimplementedError();

  @override
  Future<Map<String, dynamic>> updateCustomer(
    Map<String, Object?> values, {
    DateTime? expectedUpdatedAt,
  }) => throw UnimplementedError();
}

class _AuthRequiredGuard implements SyncSessionGuard {
  @override
  Future<SyncResultType?> ensureValidSession() async =>
      SyncResultType.authRequired;
}

class _NoopCustomerApi implements CustomerSyncApi {
  @override
  Future<SyncPushResult> createCustomer({
    required String operationId,
    required String idempotencyKey,
    required String businessId,
    required Map<String, Object?> customer,
    required int payloadVersion,
  }) async => const SyncPushResult(type: SyncResultType.applied);

  @override
  Future<SyncPushResult> updateCustomer({
    required String operationId,
    required String idempotencyKey,
    required String businessId,
    required Map<String, Object?> customer,
    required int expectedVersion,
    required int payloadVersion,
  }) async => const SyncPushResult(type: SyncResultType.applied);

  @override
  Future<SyncPushResult> setCustomerActive({
    required String operationId,
    required String idempotencyKey,
    required String businessId,
    required String customerId,
    required bool isActive,
    required int expectedVersion,
    required int payloadVersion,
  }) async => const SyncPushResult(type: SyncResultType.applied);
}

class _NoopSessionApi implements SessionSyncApi {
  @override
  Future<SyncPushResult> startSession({
    required String operationId,
    required String idempotencyKey,
    required String businessId,
    required Map<String, Object?> session,
    required int payloadVersion,
  }) async => const SyncPushResult(type: SyncResultType.applied);

  @override
  Future<SyncPushResult> sessionEvent({
    required String operationId,
    required String idempotencyKey,
    required String businessId,
    required Map<String, Object?> event,
    required int payloadVersion,
  }) async => const SyncPushResult(type: SyncResultType.applied);
}
