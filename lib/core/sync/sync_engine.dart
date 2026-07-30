import 'dart:async';
import 'dart:convert';

import 'package:suretakip/core/database/app_database.dart';
import 'package:suretakip/core/auth/sync_session_guard.dart';
import 'package:suretakip/core/logging/app_logger.dart';
import 'package:suretakip/core/logging/noop_app_logger.dart';
import 'package:suretakip/core/sync/customer_sync_rpc.dart';
import 'package:suretakip/core/sync/models/sync_enums.dart';
import 'package:suretakip/core/sync/models/sync_push_result.dart';
import 'package:suretakip/core/sync/outbox_repository.dart';
import 'package:suretakip/core/sync/product_sync_rpc.dart';
import 'package:suretakip/core/sync/retry_policy.dart';
import 'package:suretakip/core/sync/service_sync_rpc.dart';
import 'package:suretakip/core/sync/session_sync_rpc.dart';
import 'package:suretakip/core/sync/sync_error_classifier.dart';

/// Bir push turunun özeti (gözlemleme ve test için).
final class SyncRunSummary {
  const SyncRunSummary({
    required this.pushed,
    required this.retried,
    required this.failed,
    required this.authRequired,
  });

  final int pushed;
  final int retried;
  final int failed;
  final bool authRequired;
}

/// Minimum push Sync Engine (Bölüm 10). Aynı anda tek worker çalışır; her
/// outbox kaydı idempotency anahtarıyla `create_customer` RPC'sine gönderilir.
class SyncEngine {
  static const maxOperationsPerRun = 50;

  SyncEngine({
    required OutboxRepository outbox,
    required CustomerSyncApi customerRpc,
    required SessionSyncApi sessionRpc,
    required SyncSessionGuard sessionGuard,
    // Ürün/hizmet RPC'leri opsiyoneldir (geriye dönük uyumluluk): mevcut
    // müşteri/seans testleri bunları hiç geçmeden çalışmaya devam eder.
    // Fabrika fonksiyonu olarak alınır (TEMBEL): Riverpod provider grafiğinde
    // yalnızca dispatch sırasında ilgili operasyon türüne rastlanırsa
    // çağrılır — böylece `productSyncApiProvider`/`serviceSyncApiProvider`
    // (ve onların `supabaseClientProvider` bağımlılığı), müşteri/seans
    // testlerinde override edilmemiş olsa bile SyncEngine inşa anında
    // TETİKLENMEZ.
    ProductSyncApi Function()? productRpc,
    ServiceSyncApi Function()? serviceRpc,
    RetryPolicy? retryPolicy,
    SyncErrorClassifier classifier = const SyncErrorClassifier(),
    DateTime Function()? clock,
    String? Function()? currentActorUserId,
    String? Function()? currentBusinessId,
    AppLogger logger = const NoopAppLogger(),
  }) : _outbox = outbox,
       _customerRpc = customerRpc,
       _sessionRpc = sessionRpc,
       _productRpc = productRpc,
       _serviceRpc = serviceRpc,
       _sessionGuard = sessionGuard,
       _retryPolicy = retryPolicy ?? RetryPolicy(),
       _classifier = classifier,
       _clock = clock ?? (() => DateTime.now().toUtc()),
       _currentActorUserId = currentActorUserId ?? (() => null),
       _currentBusinessId = currentBusinessId ?? (() => null),
       _logger = logger;

  final OutboxRepository _outbox;
  final CustomerSyncApi _customerRpc;
  final SessionSyncApi _sessionRpc;
  final ProductSyncApi Function()? _productRpc;
  final ServiceSyncApi Function()? _serviceRpc;
  final SyncSessionGuard _sessionGuard;
  final RetryPolicy _retryPolicy;
  final SyncErrorClassifier _classifier;
  final DateTime Function() _clock;
  final String? Function() _currentActorUserId;
  final String? Function() _currentBusinessId;
  final AppLogger _logger;

  Future<SyncRunSummary>? _inFlight;

  /// Tek worker garantisi: devam eden bir tur varsa onu döndürür.
  Future<SyncRunSummary> push() => _inFlight ??= _runGuarded();

  Future<SyncRunSummary> _runGuarded() async {
    try {
      return await _run();
    } finally {
      _inFlight = null;
    }
  }

  Future<SyncRunSummary> _run() async {
    final sessionProblem = await _sessionGuard.ensureValidSession();
    if (sessionProblem == SyncResultType.authRequired) {
      return const SyncRunSummary(
        pushed: 0,
        retried: 0,
        failed: 0,
        authRequired: true,
      );
    }
    if (sessionProblem == SyncResultType.retryableFailure) {
      return const SyncRunSummary(
        pushed: 0,
        retried: 0,
        failed: 0,
        authRequired: false,
      );
    }

    var pushed = 0;
    var retried = 0;
    var failed = 0;

    final now = _clock();
    await _outbox.recoverStaleProcessing(now: now);
    for (var processed = 0; processed < maxOperationsPerRun; processed++) {
      // Lease, dispatch'ten hemen önce tek kayıt için alınır. Böylece
      // auth nedeniyle erken çıkışta gönderilmemiş batch kayıtları
      // `processing` durumunda beklemez.
      // Yalnız oturumdaki kullanıcının kendi işletmesindeki operasyonları
      // claim edilir; başka kullanıcının/işletmenin kayıtları gönderilmez.
      final ready = await _outbox.claimReady(
        now: _clock(),
        actorUserId: _currentActorUserId(),
        businessId: _currentBusinessId(),
        limit: 1,
      );
      if (ready.isEmpty) break;
      final row = ready.single;
      final outcome = await _process(row);
      switch (outcome) {
        case _Outcome.pushed:
          pushed++;
        case _Outcome.retried:
          retried++;
        case _Outcome.failed:
          failed++;
        case _Outcome.superseded:
          break;
        case _Outcome.authRequired:
          return SyncRunSummary(
            pushed: pushed,
            retried: retried,
            failed: failed,
            authRequired: true,
          );
      }
    }

    return SyncRunSummary(
      pushed: pushed,
      retried: retried,
      failed: failed,
      authRequired: false,
    );
  }

  Future<_Outcome> _process(SyncOutboxRow row) async {
    SyncPushResult result;
    try {
      result = await _dispatch(row);
    } catch (error, stack) {
      return _handleThrown(row, error, stack);
    }
    return _handleResult(row, result);
  }

  Future<SyncPushResult> _dispatch(SyncOutboxRow row) {
    final type = SyncOperationType.fromWire(row.operationType);
    final payload = jsonDecode(row.payloadJson) as Map<String, Object?>;
    switch (type) {
      case SyncOperationType.createCustomer:
        return _customerRpc.createCustomer(
          operationId: row.operationId,
          idempotencyKey: row.idempotencyKey,
          businessId: row.businessId,
          customer: payload,
          payloadVersion: row.payloadVersion,
        );
      case SyncOperationType.updateCustomer:
        return _customerRpc.updateCustomer(
          operationId: row.operationId,
          idempotencyKey: row.idempotencyKey,
          businessId: row.businessId,
          customer: payload,
          expectedVersion: row.expectedServerVersion ?? 0,
          payloadVersion: row.payloadVersion,
        );
      case SyncOperationType.setCustomerActive:
        return _customerRpc.setCustomerActive(
          operationId: row.operationId,
          idempotencyKey: row.idempotencyKey,
          businessId: row.businessId,
          customerId: payload['id'] as String,
          isActive: payload['is_active'] as bool,
          expectedVersion: row.expectedServerVersion ?? 0,
          payloadVersion: row.payloadVersion,
        );
      case SyncOperationType.createProduct:
        return _requireProductRpc().createProduct(
          operationId: row.operationId,
          idempotencyKey: row.idempotencyKey,
          businessId: row.businessId,
          product: payload,
          payloadVersion: row.payloadVersion,
        );
      case SyncOperationType.updateProduct:
        return _requireProductRpc().updateProduct(
          operationId: row.operationId,
          idempotencyKey: row.idempotencyKey,
          businessId: row.businessId,
          product: payload,
          expectedVersion: row.expectedServerVersion ?? 0,
          payloadVersion: row.payloadVersion,
        );
      case SyncOperationType.setProductActive:
        return _requireProductRpc().setProductActive(
          operationId: row.operationId,
          idempotencyKey: row.idempotencyKey,
          businessId: row.businessId,
          productId: payload['id'] as String,
          isActive: payload['is_active'] as bool,
          expectedVersion: row.expectedServerVersion ?? 0,
          payloadVersion: row.payloadVersion,
        );
      case SyncOperationType.createService:
        return _requireServiceRpc().createService(
          operationId: row.operationId,
          idempotencyKey: row.idempotencyKey,
          businessId: row.businessId,
          service: payload,
          payloadVersion: row.payloadVersion,
        );
      case SyncOperationType.updateService:
        return _requireServiceRpc().updateService(
          operationId: row.operationId,
          idempotencyKey: row.idempotencyKey,
          businessId: row.businessId,
          service: payload,
          expectedVersion: row.expectedServerVersion ?? 0,
          payloadVersion: row.payloadVersion,
        );
      case SyncOperationType.setServiceActive:
        return _requireServiceRpc().setServiceActive(
          operationId: row.operationId,
          idempotencyKey: row.idempotencyKey,
          businessId: row.businessId,
          serviceId: payload['id'] as String,
          isActive: payload['is_active'] as bool,
          expectedVersion: row.expectedServerVersion ?? 0,
          payloadVersion: row.payloadVersion,
        );
      case SyncOperationType.startSession:
        return _sessionRpc.startSession(
          operationId: row.operationId,
          idempotencyKey: row.idempotencyKey,
          businessId: row.businessId,
          session: payload,
          payloadVersion: row.payloadVersion,
        );
      case SyncOperationType.pauseSession:
      case SyncOperationType.resumeSession:
      case SyncOperationType.addSessionProduct:
      case SyncOperationType.completeSession:
      case SyncOperationType.cancelSession:
        return _sessionRpc.sessionEvent(
          operationId: row.operationId,
          idempotencyKey: row.idempotencyKey,
          businessId: row.businessId,
          event: payload,
          payloadVersion: row.payloadVersion,
        );
    }
  }

  ProductSyncApi _requireProductRpc() {
    final factory = _productRpc;
    if (factory == null) {
      throw StateError('SyncEngine.productRpc yapılandırılmadı.');
    }
    return factory();
  }

  ServiceSyncApi _requireServiceRpc() {
    final factory = _serviceRpc;
    if (factory == null) {
      throw StateError('SyncEngine.serviceRpc yapılandırılmadı.');
    }
    return factory();
  }

  Future<_Outcome> _handleResult(
    SyncOutboxRow row,
    SyncPushResult result,
  ) async {
    if (result.isSuccess) {
      final applied = await _outbox.applySuccess(
        row,
        result,
        now: _clock(),
        submittedByUserId: row.originalActorUserId,
      );
      return applied ? _Outcome.pushed : _Outcome.superseded;
    }
    switch (result.type) {
      case SyncResultType.authRequired:
        final reset = await _outbox.resetToPending(row);
        return reset ? _Outcome.authRequired : _Outcome.superseded;
      case SyncResultType.retryableFailure:
        final attemptCount = row.attemptCount + 1;
        final marked = await _outbox.markRetrying(
          row,
          attemptCount: attemptCount,
          nextAttemptAt: _clock().add(_retryPolicy.nextDelay(attemptCount)),
          errorCode: result.errorCode ?? 'RETRYABLE',
        );
        return marked ? _Outcome.retried : _Outcome.superseded;
      case SyncResultType.conflict:
        final marked = await _outbox.markTerminal(
          row,
          status: SyncStatus.conflicted,
          errorCode: result.errorCode,
        );
        return marked ? _Outcome.failed : _Outcome.superseded;
      case SyncResultType.rejected:
      default:
        final marked = await _outbox.markTerminal(
          row,
          status: SyncStatus.rejected,
          errorCode: result.errorCode,
        );
        return marked ? _Outcome.failed : _Outcome.superseded;
    }
  }

  Future<_Outcome> _handleThrown(
    SyncOutboxRow row,
    Object error,
    StackTrace stack,
  ) async {
    final classified = _classifier.classify(error);
    _logger.warn(error, stackTrace: stack, context: 'SyncEngine');
    switch (classified) {
      case SyncResultType.authRequired:
        final reset = await _outbox.resetToPending(row);
        return reset ? _Outcome.authRequired : _Outcome.superseded;
      case SyncResultType.retryableFailure:
        final attemptCount = row.attemptCount + 1;
        final marked = await _outbox.markRetrying(
          row,
          attemptCount: attemptCount,
          nextAttemptAt: _clock().add(_retryPolicy.nextDelay(attemptCount)),
          errorCode: 'RETRYABLE',
        );
        return marked ? _Outcome.retried : _Outcome.superseded;
      default:
        final marked = await _outbox.markTerminal(
          row,
          status: SyncStatus.rejected,
          errorCode: 'TRANSPORT_REJECTED',
        );
        return marked ? _Outcome.failed : _Outcome.superseded;
    }
  }
}

enum _Outcome { pushed, retried, failed, authRequired, superseded }
