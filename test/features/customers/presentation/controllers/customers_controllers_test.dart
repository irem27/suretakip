import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suretakip/app/providers/app_providers.dart';
import 'package:suretakip/app/providers/sync_providers.dart';
import 'package:suretakip/core/auth/sync_session_guard.dart';
import 'package:suretakip/core/database/app_database.dart';
import 'package:suretakip/core/domain/domain_enums.dart';
import 'package:suretakip/core/sync/customer_sync_rpc.dart';
import 'package:suretakip/core/sync/models/sync_enums.dart';
import 'package:suretakip/core/sync/models/sync_push_result.dart';
import 'package:suretakip/core/sync/session_sync_rpc.dart';
import 'package:suretakip/features/businesses/domain/entities/business.dart';
import 'package:suretakip/features/businesses/domain/entities/business_member.dart';
import 'package:suretakip/features/customers/data/datasources/customers_remote_data_source.dart';
import 'package:suretakip/features/customers/domain/entities/customer.dart';
import 'package:suretakip/features/customers/domain/entities/customer_input.dart';
import 'package:suretakip/features/customers/domain/repositories/customers_repository.dart';
import 'package:suretakip/features/customers/presentation/controllers/customers_controllers.dart';

void main() {
  test('liste controller müşterileri Drift streaminden yükler', () async {
    final db = AppDatabase.forExecutor(NativeDatabase.memory());
    addTearDown(db.close);
    final onlineRepository = _FakeCustomersRepository(
      customers: [_customer(name: 'Online Müşteri')],
    );
    final container = _offlineContainer(db, onlineRepository);
    addTearDown(container.dispose);
    final provider = customersListControllerProvider(_scope);
    final updated = Completer<CustomersListState>();
    final subscription = container.listen(provider, (_, next) {
      final value = next.valueOrNull;
      if (value != null && value.customers.isNotEmpty && !updated.isCompleted) {
        updated.complete(value);
      }
    }, fireImmediately: true);
    addTearDown(subscription.close);

    expect((await container.read(provider.future)).customers, isEmpty);
    await db
        .into(db.localCustomers)
        .insert(
          LocalCustomersCompanion.insert(
            id: 'local-customer',
            businessId: 'business-1',
            name: 'Yerel Müşteri',
            syncStatus: SyncStatus.synced.wireName,
            createdAtLocal: DateTime.utc(2026),
            updatedAtLocal: DateTime.utc(2026),
          ),
        );
    final state = await updated.future.timeout(const Duration(seconds: 2));

    expect(state.customers.single.id, 'local-customer');
    expect(state.customers.single.name, 'Yerel Müşteri');
    expect(onlineRepository.businessId, isNull);
  });

  test('arama adı telefon ve e-posta üzerinde client-side çalışır', () async {
    final db = AppDatabase.forExecutor(NativeDatabase.memory());
    addTearDown(db.close);
    Future<void> seed(String id, String name, String? phone, String? email) =>
        db
            .into(db.localCustomers)
            .insert(
              LocalCustomersCompanion.insert(
                id: id,
                businessId: 'business-1',
                name: name,
                phone: Value(phone),
                email: Value(email),
                syncStatus: SyncStatus.synced.wireName,
                createdAtLocal: DateTime.utc(2026),
                updatedAtLocal: DateTime.utc(2026),
              ),
            );
    await seed('customer-1', 'Ahmet Erdemir', null, null);
    await seed('customer-2', 'Banu Korkmaz', '05321234567', 'banu@example.com');

    final container = _offlineContainer(db, _FakeCustomersRepository());
    addTearDown(container.dispose);
    final provider = customersListControllerProvider(_scope);
    final subscription = container.listen(
      provider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);
    await container.read(provider.future);

    container.read(provider.notifier).setQuery('example');

    final state = container.read(provider).requireValue;
    expect(state.visibleCustomers.single.id, 'customer-2');
  });

  test(
    'form controller müşteriyi currentMember aktörüyle offline oluşturur',
    () async {
      final db = AppDatabase.forExecutor(NativeDatabase.memory());
      addTearDown(db.close);
      final onlineRepository = _FakeCustomersRepository();
      final container = _offlineContainer(db, onlineRepository);
      addTearDown(container.dispose);
      const input = CustomerInput(
        businessId: 'business-1',
        name: 'Can Yılmaz',
        phone: '5551234567',
        email: 'can@example.com',
      );

      final created = await container
          .read(customerFormControllerProvider.notifier)
          .create(input);

      expect(created?.name, 'Can Yılmaz');
      expect(onlineRepository.createdInput, isNull);
      final localRows = await db.select(db.localCustomers).get();
      expect(localRows.single.name, 'Can Yılmaz');
      final outboxRows = await db.select(db.syncOutbox).get();
      expect(outboxRows.single.originalActorUserId, 'user-1');
    },
  );

  test(
    'setActive offline-first yerelde günceller ve online repo çağrılmaz',
    () async {
      final db = AppDatabase.forExecutor(NativeDatabase.memory());
      addTearDown(db.close);
      await db
          .into(db.localCustomers)
          .insert(
            LocalCustomersCompanion.insert(
              id: 'customer-1',
              businessId: 'business-1',
              name: 'Ahmet Erdemir',
              syncStatus: SyncStatus.synced.wireName,
              serverVersion: const Value(3),
              createdAtLocal: DateTime.utc(2026),
              updatedAtLocal: DateTime.utc(2026),
            ),
          );
      final repository = _FakeCustomersRepository(customers: [_customer()]);
      final container = _offlineContainer(db, repository);
      addTearDown(container.dispose);

      final ok = await container
          .read(customerFormControllerProvider.notifier)
          .setActive('customer-1', isActive: false);

      expect(ok, isTrue);
      // Online repository artık kullanılmıyor: setActive tamamen offline-first.
      expect(repository.toggledId, isNull);
      expect(repository.updatedCustomer, isNull);
      final local = await (db.select(
        db.localCustomers,
      )..where((t) => t.id.equals('customer-1'))).getSingle();
      expect(local.isActive, isFalse);
      expect(local.syncStatus, SyncStatus.pending.wireName);
      final outboxRows = await db.select(db.syncOutbox).get();
      expect(outboxRows.single.operationType, 'setCustomerActive');
    },
  );

  test(
    'updateCustomer offline-first yerelde günceller ve online repo çağrılmaz',
    () async {
      final db = AppDatabase.forExecutor(NativeDatabase.memory());
      addTearDown(db.close);
      await db
          .into(db.localCustomers)
          .insert(
            LocalCustomersCompanion.insert(
              id: 'customer-1',
              businessId: 'business-1',
              name: 'Ahmet Erdemir',
              syncStatus: SyncStatus.synced.wireName,
              serverVersion: const Value(2),
              createdAtLocal: DateTime.utc(2026),
              updatedAtLocal: DateTime.utc(2026),
            ),
          );
      final repository = _FakeCustomersRepository(customers: [_customer()]);
      final container = _offlineContainer(db, repository);
      addTearDown(container.dispose);

      final updated = await container
          .read(customerFormControllerProvider.notifier)
          .updateCustomer(_customer(name: 'Ahmet Güncel'));

      expect(updated?.name, 'Ahmet Güncel');
      expect(repository.updatedCustomer, isNull);
      final local = await (db.select(
        db.localCustomers,
      )..where((t) => t.id.equals('customer-1'))).getSingle();
      expect(local.name, 'Ahmet Güncel');
      expect(local.syncStatus, SyncStatus.pending.wireName);
      final outboxRows = await db.select(db.syncOutbox).get();
      expect(outboxRows.single.operationType, 'updateCustomer');
    },
  );
}

const BusinessScope _scope = (businessId: 'business-1', generation: 0);

ProviderContainer _offlineContainer(
  AppDatabase db,
  _FakeCustomersRepository onlineRepository,
) => ProviderContainer(
  overrides: [
    appDatabaseProvider.overrideWithValue(db),
    activeBusinessProvider.overrideWithValue(_business()),
    activeBusinessScopeProvider.overrideWithValue(_scope),
    currentMemberProvider(_scope).overrideWith((ref) async => _member()),
    customersRepositoryProvider.overrideWithValue(onlineRepository),
    customersRemoteDataSourceProvider.overrideWithValue(
      _NoopCustomersRemoteDataSource(),
    ),
    customerSyncApiProvider.overrideWithValue(_NoopCustomerApi()),
    sessionSyncApiProvider.overrideWithValue(_NoopSessionApi()),
    syncSessionGuardProvider.overrideWithValue(_AuthRequiredGuard()),
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

BusinessMember _member() => BusinessMember(
  id: 'member-1',
  businessId: 'business-1',
  userId: 'user-1',
  role: MemberRole.owner,
  isActive: true,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

Customer _customer({
  String id = 'customer-1',
  String name = 'Ahmet Erdemir',
  String? phone,
  String? email,
}) => Customer(
  id: id,
  businessId: 'business-1',
  name: name,
  phone: phone,
  email: email,
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
  String? businessId;
  bool? includeInactive;
  CustomerInput? createdInput;
  Customer? updatedCustomer;
  String? toggledId;
  bool? toggledActive;

  @override
  Future<Customer> createCustomer(CustomerInput input) async {
    createdInput = input;
    return _customer().copyWith(
      name: input.name,
      phone: input.phone,
      email: input.email,
      notes: input.notes,
    );
  }

  @override
  Future<Customer> getCustomer(String customerId) async =>
      customers.firstWhere((customer) => customer.id == customerId);

  @override
  Future<List<Customer>> getCustomers({
    required String businessId,
    bool includeInactive = false,
  }) async {
    this.businessId = businessId;
    this.includeInactive = includeInactive;
    return customers;
  }

  @override
  Future<Customer> updateCustomer(Customer customer) async {
    updatedCustomer = customer;
    return customer;
  }

  @override
  Future<Customer> setCustomerActive(
    String customerId, {
    required bool isActive,
    DateTime? expectedUpdatedAt,
  }) async {
    toggledId = customerId;
    toggledActive = isActive;
    return customers
        .firstWhere((customer) => customer.id == customerId)
        .copyWith(isActive: isActive);
  }
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
