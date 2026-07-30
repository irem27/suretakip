import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suretakip/core/auth/sync_session_guard.dart';
import 'package:suretakip/core/database/app_database.dart';
import 'package:suretakip/core/errors/domain_exception.dart';
import 'package:suretakip/core/sync/customer_sync_rpc.dart';
import 'package:suretakip/core/sync/device_identity.dart';
import 'package:suretakip/core/sync/models/sync_enums.dart';
import 'package:suretakip/core/sync/models/sync_push_result.dart';
import 'package:suretakip/core/sync/outbox_repository.dart';
import 'package:suretakip/core/sync/payment_sync_rpc.dart';
import 'package:suretakip/core/sync/session_sync_rpc.dart';
import 'package:suretakip/core/sync/sync_engine.dart';
import 'package:suretakip/core/value_objects/money.dart';
import 'package:suretakip/features/payments/data/repositories/offline_payments_repository.dart';
import 'package:suretakip/features/payments/domain/entities/payment.dart';
import 'package:suretakip/features/payments/domain/entities/payment_input.dart';
import 'package:suretakip/features/payments/domain/entities/payment_mutation_result.dart';
import 'package:suretakip/features/payments/domain/entities/refund_input.dart';
import 'package:suretakip/features/payments/domain/entities/session_payment_summary.dart';
import 'package:suretakip/features/payments/domain/entities/session_payment_status_summary.dart';
import 'package:suretakip/features/payments/domain/repositories/payments_repository.dart';
import 'package:suretakip/features/sessions/data/local/sessions_local_data_source.dart';

void main() {
  late AppDatabase db;
  late OutboxRepository outbox;
  late SessionsLocalDataSource sessionsLocal;
  late _FakeRemotePayments remote;
  late _RecordingPaymentApi paymentApi;
  late SyncEngine engine;
  late OfflinePaymentsRepository repo;

  DateTime clock() => DateTime.utc(2026, 4, 1, 10);

  final paymentInput = PaymentInput(
    sessionId: 'session-1',
    method: PaymentMethod.cash,
    amount: Money(minorUnits: 5000, currencyCode: 'TRY'),
    idempotencyKey: 'idem-1',
  );

  setUp(() async {
    db = AppDatabase.forExecutor(NativeDatabase.memory());
    outbox = OutboxRepository(db);
    sessionsLocal = SessionsLocalDataSource(db);
    remote = _FakeRemotePayments();
    paymentApi = _RecordingPaymentApi();
    engine = SyncEngine(
      outbox: outbox,
      customerRpc: _UnusedCustomerApi(),
      sessionRpc: _UnusedSessionApi(),
      paymentRpc: () => paymentApi,
      sessionGuard: _OkGuard(),
      clock: clock,
      currentActorUserId: () => 'user-1',
    );
    repo = OfflinePaymentsRepository(
      remote: remote,
      db: db,
      sessionsLocal: sessionsLocal,
      outbox: outbox,
      deviceIdentity: DeviceIdentity(db, clock: clock),
      syncEngine: engine,
      currentActorUserId: () => 'user-1',
      clock: clock,
    );

    // Ödemenin ait olacağı seans yerelde önceden var olmalı (çevrimdışı
    // seans akışında zaten böyledir): businessId buradan çözülür.
    await sessionsLocal.startSession(
      StartSessionLocally(
        sessionId: 'session-1',
        timeEntryId: 'entry-1',
        businessId: 'biz-1',
        serviceId: 'svc-1',
        openedByMemberId: 'member-1',
        serviceName: 'Koltuk',
        pricePerMinuteMinor: 250,
        roundingIntervalMinutes: 1,
        minimumChargeMinutes: 0,
        currencyCode: 'TRY',
        startedAt: clock(),
        startedOffline: false,
      ),
    );
  });

  tearDown(() async => db.close());

  test('online iken doğrudan sunucu sonucu döner, outbox yazılmaz', () async {
    final result = await repo.recordSessionPayment(paymentInput);

    expect(result.paymentId, 'server-payment-1');
    expect(remote.calls, hasLength(1));
    final ops = await db.select(db.syncOutbox).get();
    expect(ops, isEmpty);
  });

  test(
    'bağlantı yokken NetworkException fırlatılır ama ödeme kuyruğa alınır',
    () async {
      remote.throwNetworkError = true;

      await expectLater(
        repo.recordSessionPayment(paymentInput),
        throwsA(isA<NetworkException>()),
      );

      final ops = await db.select(db.syncOutbox).get();
      expect(ops, hasLength(1));
      expect(
        ops.single.operationType,
        SyncOperationType.recordSessionPayment.wireName,
      );
      expect(ops.single.aggregateType, 'session');
      expect(ops.single.aggregateId, 'session-1');
      expect(ops.single.businessId, 'biz-1');
      expect(ops.single.idempotencyKey, 'idem-1');
      // Seansın kendi (start) op'una bağımlı: seans sunucuda oluşmadan
      // ödeme gönderilemez.
      final sessionOp = (await (db.select(db.syncOutbox)..where(
                (t) => t.operationType.equals('startSession'),
              ))
              .getSingleOrNull());
      // Bu testte seans doğrudan yerel yazıldığı için outbox'ta start op'u
      // yok; dependsOnOperationId bu durumda null kalmalı (zincir kırılmaz).
      expect(sessionOp, isNull);
      expect(ops.single.dependsOnOperationId, isNull);
    },
  );

  test(
    'aynı idempotency key ile tekrar deneme İKİNCİ outbox kaydı AÇMAZ '
    '(çift-tahsilat koruması)',
    () async {
      remote.throwNetworkError = true;

      await expectLater(
        repo.recordSessionPayment(paymentInput),
        throwsA(isA<NetworkException>()),
      );
      await expectLater(
        repo.recordSessionPayment(paymentInput),
        throwsA(isA<NetworkException>()),
      );

      final ops = await db.select(db.syncOutbox).get();
      expect(ops, hasLength(1));
    },
  );

  test('push sonrası ödeme senkronize olur ve doğru payload gönderilir', () async {
    remote.throwNetworkError = true;
    await expectLater(
      repo.recordSessionPayment(paymentInput),
      throwsA(isA<NetworkException>()),
    );

    final summary = await engine.push();

    expect(summary.pushed, 1);
    expect(paymentApi.calls, hasLength(1));
    final payload = paymentApi.calls.single;
    expect(payload['session_id'], 'session-1');
    expect(payload['amount_minor'], 5000);
    expect(payload['payment_method'], 'cash');
    final op = (await db.select(db.syncOutbox).get()).single;
    expect(op.status, SyncStatus.synced.wireName);
    // Seans (aggregate) durumu senkronize kalmalı: yalnızca bu op vardı.
    final session = (await db.select(db.localSessions).get()).single;
    expect(session.syncStatus, SyncStatus.synced.wireName);
  });
}

class _FakeRemotePayments implements PaymentsRepository {
  bool throwNetworkError = false;
  final calls = <PaymentInput>[];

  @override
  Future<PaymentMutationResult> recordSessionPayment(
    PaymentInput input,
  ) async {
    calls.add(input);
    if (throwNetworkError) {
      throw const NetworkException(NetworkException.offlineMessage);
    }
    return PaymentMutationResult(
      summary: _summary,
      paymentId: 'server-payment-1',
      replayed: false,
    );
  }

  @override
  Future<SessionPaymentSummary> getSessionPaymentSummary(
    String sessionId,
  ) async => _summary;

  @override
  Future<List<SessionPaymentStatusSummary>> getSessionsPaymentStatus(
    List<String> sessionIds,
  ) async => const [];

  @override
  Future<PaymentMutationResult> refundPayment(RefundInput input) async =>
      PaymentMutationResult(summary: _summary, paymentId: 'x', replayed: false);

  @override
  Future<PaymentMutationResult> voidPayment({
    required String paymentId,
    required String reason,
  }) async =>
      PaymentMutationResult(summary: _summary, paymentId: 'x', replayed: false);
}

final _summary = SessionPaymentSummary(
  sessionId: 'session-1',
  sessionTotal: Money(minorUnits: 10000, currencyCode: 'TRY'),
  collected: Money.zero('TRY'),
  refunded: Money.zero('TRY'),
  netPaid: Money.zero('TRY'),
  remaining: Money(minorUnits: 10000, currencyCode: 'TRY'),
  paymentStatus: SessionPaymentStatus.unpaid,
  currencyCode: 'TRY',
  payments: const [],
);

class _RecordingPaymentApi implements PaymentSyncApi {
  final calls = <Map<String, Object?>>[];

  @override
  Future<SyncPushResult> recordSessionPayment({
    required String operationId,
    required String idempotencyKey,
    required String businessId,
    required Map<String, Object?> payment,
    required int payloadVersion,
  }) async {
    calls.add(payment);
    return const SyncPushResult(type: SyncResultType.applied);
  }
}

class _OkGuard implements SyncSessionGuard {
  @override
  Future<SyncResultType?> ensureValidSession() async => null;
}

class _UnusedCustomerApi implements CustomerSyncApi {
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

class _UnusedSessionApi implements SessionSyncApi {
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
