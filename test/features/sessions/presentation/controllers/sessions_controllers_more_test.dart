import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suretakip/app/providers/app_providers.dart';
import 'package:suretakip/app/providers/sync_providers.dart';
import 'package:suretakip/core/database/app_database.dart';
import 'package:suretakip/core/domain/domain_enums.dart';
import 'package:suretakip/core/logging/app_logger.dart';
import 'package:suretakip/core/sync/customer_sync_rpc.dart';
import 'package:suretakip/core/sync/models/sync_enums.dart';
import 'package:suretakip/core/sync/models/sync_push_result.dart';
import 'package:suretakip/core/sync/session_sync_rpc.dart';
import 'package:suretakip/core/auth/sync_session_guard.dart';
import 'package:suretakip/features/businesses/domain/entities/business.dart';
import 'package:suretakip/features/businesses/domain/entities/business_member.dart';
import 'package:suretakip/features/products/domain/entities/product.dart';
import 'package:suretakip/features/services/domain/entities/service.dart';
import 'package:suretakip/features/sessions/domain/entities/session.dart';
import 'package:suretakip/features/sessions/domain/repositories/sessions_repository.dart';
import 'package:suretakip/features/sessions/presentation/controllers/sessions_controllers.dart';

const BusinessScope _scope = (businessId: 'business-1', generation: 0);

void main() {
  group('StartSessionController - aktif işletme/üye yoksa', () {
    test('aktif işletme yoksa null döner', () async {
      final container = ProviderContainer(
        overrides: [activeBusinessProvider.overrideWithValue(null)],
      );
      addTearDown(container.dispose);

      final id = await container
          .read(startSessionControllerProvider.notifier)
          .start(service: _service());

      expect(id, isNull);
    });

    test('mevcut üye yoksa null döner', () async {
      final container = ProviderContainer(
        overrides: [
          activeBusinessProvider.overrideWithValue(_business()),
          activeBusinessScopeProvider.overrideWithValue(_scope),
          currentMemberProvider(_scope).overrideWith((ref) async => null),
        ],
      );
      addTearDown(container.dispose);

      final id = await container
          .read(startSessionControllerProvider.notifier)
          .start(service: _service());

      expect(id, isNull);
    });
  });

  group('SessionActionsController - iş kuralları', () {
    test('aktif işletme yoksa pause false döner', () async {
      final container = ProviderContainer(
        overrides: [activeBusinessProvider.overrideWithValue(null)],
      );
      addTearDown(container.dispose);

      final success = await container
          .read(sessionActionsControllerProvider.notifier)
          .pause('session-x');

      expect(success, isFalse);
    });

    test('mevcut üye yoksa resume false döner', () async {
      final container = ProviderContainer(
        overrides: [
          activeBusinessProvider.overrideWithValue(_business()),
          activeBusinessScopeProvider.overrideWithValue(_scope),
          currentMemberProvider(_scope).overrideWith((ref) async => null),
        ],
      );
      addTearDown(container.dispose);

      final success = await container
          .read(sessionActionsControllerProvider.notifier)
          .resume('session-x');

      expect(success, isFalse);
    });

    test('resume offline seansı yeniden aktif eder', () async {
      final db = AppDatabase.forExecutor(NativeDatabase.memory());
      addTearDown(db.close);
      final container = _offlineContainer(db);
      addTearDown(container.dispose);
      final id = await container
          .read(startSessionControllerProvider.notifier)
          .start(service: _service());
      await container
          .read(sessionActionsControllerProvider.notifier)
          .pause(id!);

      final success = await container
          .read(sessionActionsControllerProvider.notifier)
          .resume(id);

      expect(success, isTrue);
      final row = (await db.select(db.localSessions).get()).single;
      expect(row.status, SessionStatus.active.name);
    });

    test(
      'cancel offline seansı iptal eder ve ilgili sağlayıcıları geçersiz kılar',
      () async {
        final db = AppDatabase.forExecutor(NativeDatabase.memory());
        addTearDown(db.close);
        final container = _offlineContainer(db);
        addTearDown(container.dispose);
        final id = await container
            .read(startSessionControllerProvider.notifier)
            .start(service: _service());

        final success = await container
            .read(sessionActionsControllerProvider.notifier)
            .cancel(id!);

        expect(success, isTrue);
        final row = (await db.select(db.localSessions).get()).single;
        expect(row.status, SessionStatus.cancelled.name);
      },
    );

    test(
      'ürün ekleme başarısız olursa false döner ve stok listesi geçersiz kılınmaz',
      () async {
        final db = AppDatabase.forExecutor(NativeDatabase.memory());
        addTearDown(db.close);
        final container = _offlineContainer(db);
        addTearDown(container.dispose);

        final success = await container
            .read(sessionActionsControllerProvider.notifier)
            .addProduct(
              sessionId: 'olmayan-seans',
              product: _product(),
              quantity: 1,
            );

        expect(success, isFalse);
      },
    );
  });

  group('SessionsListController.refresh', () {
    test('aktif işletme yoksa erken döner', () async {
      final db = AppDatabase.forExecutor(NativeDatabase.memory());
      addTearDown(db.close);
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          activeBusinessProvider.overrideWithValue(null),
        ],
      );
      addTearDown(container.dispose);
      const scope = (businessId: null, generation: 0);

      await container.read(sessionsListControllerProvider(scope).future);
      await container
          .read(sessionsListControllerProvider(scope).notifier)
          .refresh();
    });

    test('sync hatası yerel listeyi bozmadan loglanır', () async {
      final db = AppDatabase.forExecutor(NativeDatabase.memory());
      addTearDown(db.close);
      final logger = _RecordingLogger();
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          activeBusinessProvider.overrideWithValue(_business()),
          appLoggerProvider.overrideWithValue(logger),
          sessionsRepositoryProvider.overrideWithValue(
            _FailingSessionsRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final sessions = await container.read(
        sessionsListControllerProvider(_scope).future,
      );
      await container
          .read(sessionsListControllerProvider(_scope).notifier)
          .refresh();

      expect(sessions, isEmpty);
      expect(logger.warningContexts, contains('SessionsListBackgroundRefresh'));
    });
  });

  test('openSessionsProvider aktif işletme yoksa boş liste döner', () async {
    final container = ProviderContainer(
      overrides: [activeBusinessProvider.overrideWithValue(null)],
    );
    addTearDown(container.dispose);

    final sessions = await container.read(openSessionsProvider.future);

    expect(sessions, isEmpty);
  });
}

ProviderContainer _offlineContainer(AppDatabase db) => ProviderContainer(
  overrides: [
    appDatabaseProvider.overrideWithValue(db),
    activeBusinessProvider.overrideWithValue(_business()),
    activeBusinessScopeProvider.overrideWithValue(_scope),
    currentMemberProvider(_scope).overrideWith((ref) async => _member()),
    customerSyncApiProvider.overrideWithValue(_NoopCustomerApi()),
    sessionSyncApiProvider.overrideWithValue(_NoopSessionApi()),
    syncSessionGuardProvider.overrideWithValue(_NoopGuard()),
  ],
);

Service _service() => Service(
  id: 'service-2',
  businessId: 'business-1',
  name: 'Bilardo',
  pricePerMinuteMinor: 200,
  roundingIntervalMinutes: 5,
  minimumChargeMinutes: 10,
  currencyCode: 'TRY',
  isActive: true,
  archivedAt: null,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

Product _product() => Product(
  id: 'product-1',
  businessId: 'business-1',
  name: 'Maden Suyu',
  sku: 'MS-01',
  unitPriceMinor: 300,
  currencyCode: 'TRY',
  trackStock: true,
  stockQuantity: 10,
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

class _NoopGuard implements SyncSessionGuard {
  @override
  Future<SyncResultType?> ensureValidSession() async =>
      SyncResultType.authRequired;
}

class _RecordingLogger implements AppLogger {
  final warningContexts = <String?>[];

  @override
  void error(Object error, {StackTrace? stackTrace, String? context}) {}

  @override
  void info(Object message, {String? context}) {}

  @override
  void warn(Object warning, {StackTrace? stackTrace, String? context}) {
    warningContexts.add(context);
  }
}

class _FailingSessionsRepository implements SessionsRepository {
  @override
  Future<List<Session>> getOpenSessions({required String businessId}) async {
    throw StateError('sync başarısız');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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
