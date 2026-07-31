import 'dart:async';

import 'package:uuid/uuid.dart';
import 'package:suretakip/core/database/app_database.dart';
import 'package:suretakip/core/domain/domain_enums.dart';
import 'package:suretakip/core/errors/domain_exception.dart';
import 'package:suretakip/core/logging/app_logger.dart';
import 'package:suretakip/core/logging/noop_app_logger.dart';
import 'package:suretakip/core/sync/device_identity.dart';
import 'package:suretakip/core/sync/models/sync_enums.dart';
import 'package:suretakip/core/sync/outbox_repository.dart';
import 'package:suretakip/core/sync/sync_engine.dart';
import 'package:suretakip/features/products/domain/entities/product.dart';
import 'package:suretakip/features/sessions/data/local/sessions_local_data_source.dart';
import 'package:suretakip/features/sessions/domain/entities/session_item.dart';

/// Yeni offline seans başlatma girdisi (hizmet snapshot'ı UI'dan gelir).
final class StartSessionInput {
  const StartSessionInput({
    required this.businessId,
    required this.serviceId,
    required this.openedByMemberId,
    required this.serviceName,
    required this.pricePerMinuteMinor,
    required this.roundingIntervalMinutes,
    required this.minimumChargeMinutes,
    required this.currencyCode,
    this.customerId,
    this.notes,
  });

  final String businessId;
  final String serviceId;
  final String openedByMemberId;
  final String serviceName;
  final int pricePerMinuteMinor;
  final int roundingIntervalMinutes;
  final int minimumChargeMinutes;
  final String currencyCode;
  final String? customerId;
  final String? notes;
}

/// Offline-first seans yazımı (Faz C / C2). Seans + zaman aralığı + outbox
/// event'i tek transaction'da yazılır; sonra push denenir. İnternet yoksa
/// kayıt yerelde kalır ve süre zaman damgasından hesaplanmaya devam eder.
class OfflineSessionsRepository {
  OfflineSessionsRepository({
    required AppDatabase db,
    required SessionsLocalDataSource local,
    required OutboxRepository outbox,
    required DeviceIdentity deviceIdentity,
    required SyncEngine syncEngine,
    Uuid? uuid,
    DateTime Function()? clock,
    AppLogger logger = const NoopAppLogger(),
  }) : _db = db,
       _local = local,
       _outbox = outbox,
       _deviceIdentity = deviceIdentity,
       _syncEngine = syncEngine,
       _uuid = uuid ?? const Uuid(),
       _clock = clock ?? (() => DateTime.now().toUtc()),
       _logger = logger;

  final AppDatabase _db;
  final SessionsLocalDataSource _local;
  final OutboxRepository _outbox;
  final DeviceIdentity _deviceIdentity;
  final SyncEngine _syncEngine;
  final Uuid _uuid;
  final DateTime Function() _clock;
  final AppLogger _logger;

  static const _aggregate = 'session';

  Stream<List<LocalSessionRow>> watchActiveSessions(String businessId) =>
      _local.watchActiveSessions(businessId);

  Stream<List<LocalSessionTimeEntryRow>> watchTimeEntries(String sessionId) =>
      _local.watchTimeEntries(sessionId);

  Future<LocalSessionRow> startSession(
    StartSessionInput input, {
    required String actorUserId,
  }) async {
    final deviceId = await _deviceIdentity.getOrCreate();
    final sessionId = _uuid.v4();
    final entryId = _uuid.v4();
    final operationId = _uuid.v4();
    final now = _clock();

    final row = await _db.transaction(() async {
      final created = await _local.startSession(
        StartSessionLocally(
          sessionId: sessionId,
          timeEntryId: entryId,
          businessId: input.businessId,
          serviceId: input.serviceId,
          openedByMemberId: input.openedByMemberId,
          serviceName: input.serviceName,
          pricePerMinuteMinor: input.pricePerMinuteMinor,
          roundingIntervalMinutes: input.roundingIntervalMinutes,
          minimumChargeMinutes: input.minimumChargeMinutes,
          currencyCode: input.currencyCode,
          startedAt: now,
          startedOffline: true,
          customerId: input.customerId,
          notes: input.notes,
        ),
      );
      await _outbox.enqueue(
        operationId: operationId,
        businessId: input.businessId,
        actorUserId: actorUserId,
        deviceId: deviceId,
        aggregateType: _aggregate,
        aggregateId: sessionId,
        operationType: SyncOperationType.startSession,
        idempotencyKey: '${input.businessId}:$deviceId:$operationId',
        payload: {
          'session_id': sessionId,
          'service_id': input.serviceId,
          'customer_id': input.customerId,
          'started_at': now.toIso8601String(),
          'first_entry_id': entryId,
          'notes': input.notes,
          'started_offline': true,
        },
        now: now,
      );
      return created;
    });

    unawaited(_syncEngine.push().catchError(_handleSyncError));
    return row;
  }

  Future<void> pauseSession({
    required String sessionId,
    required String businessId,
    required String actorUserId,
  }) => _enqueueEvent(
    sessionId: sessionId,
    businessId: businessId,
    actorUserId: actorUserId,
    eventType: 'pause',
    operationType: SyncOperationType.pauseSession,
    apply: (entryId, now) => _local.pauseSession(
      sessionId: sessionId,
      newEntryId: entryId,
      now: now,
    ),
  );

  Future<void> resumeSession({
    required String sessionId,
    required String businessId,
    required String actorUserId,
  }) => _enqueueEvent(
    sessionId: sessionId,
    businessId: businessId,
    actorUserId: actorUserId,
    eventType: 'resume',
    operationType: SyncOperationType.resumeSession,
    apply: (entryId, now) => _local.resumeSession(
      sessionId: sessionId,
      newEntryId: entryId,
      now: now,
    ),
  );

  Future<void> completeSession({
    required String sessionId,
    required String businessId,
    required String actorUserId,
    int discountMinor = 0,
    int taxMinor = 0,
  }) => _enqueueTerminal(
    sessionId: sessionId,
    businessId: businessId,
    actorUserId: actorUserId,
    eventType: 'complete',
    operationType: SyncOperationType.completeSession,
    status: SessionStatus.completed,
    extraPayload: {'discount_minor': discountMinor, 'tax_minor': taxMinor},
  );

  Future<void> cancelSession({
    required String sessionId,
    required String businessId,
    required String actorUserId,
  }) => _enqueueTerminal(
    sessionId: sessionId,
    businessId: businessId,
    actorUserId: actorUserId,
    eventType: 'cancel',
    operationType: SyncOperationType.cancelSession,
    status: SessionStatus.cancelled,
  );

  Future<void> addProduct({
    required String sessionId,
    required String businessId,
    required String actorUserId,
    required Product product,
    required int quantity,
    int discountMinor = 0,
    int taxMinor = 0,
  }) async {
    if (quantity <= 0) {
      throw const ValidationException('Ürün adedi sıfırdan büyük olmalıdır.');
    }
    if (discountMinor < 0 || taxMinor < 0) {
      throw const ValidationException('İndirim ve vergi negatif olamaz.');
    }
    if (product.businessId != businessId) {
      throw const ValidationException('Ürün farklı bir işletmeye ait.');
    }
    if (!product.isActive || product.archivedAt != null) {
      throw const ValidationException('Bu ürün artık satışta değil.');
    }
    if (product.trackStock && product.stockQuantity < quantity) {
      throw const ValidationException('Stok yetersiz.');
    }
    final session = await _local.findSession(sessionId);
    if (session == null) {
      throw const NotFoundException('İşlem cihazda bulunamadı.');
    }
    if (session.businessId != businessId) {
      throw const ValidationException('İşlem farklı bir işletmeye ait.');
    }
    if (session.currencyCodeSnapshot != product.currencyCode) {
      throw const ValidationException('Ürün para birimi işlemle uyuşmuyor.');
    }

    final lineTotal =
        product.unitPriceMinor * quantity - discountMinor + taxMinor;
    if (lineTotal < 0) {
      throw const ValidationException('İndirim ürün toplamını aşamaz.');
    }

    final deviceId = await _deviceIdentity.getOrCreate();
    final operationId = _uuid.v4();
    final itemId = _uuid.v4();
    final now = _clock();
    await _db.transaction(() async {
      await _local.addPendingSessionItem(
        item: SessionItem(
          id: itemId,
          businessId: businessId,
          sessionId: sessionId,
          productId: product.id,
          productNameSnapshot: product.name,
          skuSnapshot: product.sku,
          unitPriceMinorSnapshot: product.unitPriceMinor,
          currencyCodeSnapshot: product.currencyCode,
          quantity: quantity,
          discountMinor: discountMinor,
          taxMinor: taxMinor,
          lineTotalMinor: lineTotal,
          createdAt: now,
          updatedAt: now,
        ),
        now: now,
      );
      final dependsOn = await _outbox.latestOperationId(_aggregate, sessionId);
      await _outbox.enqueue(
        operationId: operationId,
        businessId: businessId,
        actorUserId: actorUserId,
        deviceId: deviceId,
        aggregateType: _aggregate,
        aggregateId: sessionId,
        operationType: SyncOperationType.addSessionProduct,
        idempotencyKey: '$businessId:$deviceId:$operationId',
        payload: {
          'session_id': sessionId,
          'event_type': 'add_product',
          'event_id': itemId,
          'occurred_at': now.toIso8601String(),
          'product_id': product.id,
          'quantity': quantity,
          'discount_minor': discountMinor,
          'tax_minor': taxMinor,
        },
        now: now,
        dependsOnOperationId: dependsOn,
      );
    });
    unawaited(_syncEngine.push().catchError(_handleSyncError));
  }

  Future<void> _enqueueTerminal({
    required String sessionId,
    required String businessId,
    required String actorUserId,
    required String eventType,
    required SyncOperationType operationType,
    required SessionStatus status,
    Map<String, Object?> extraPayload = const {},
  }) async {
    final deviceId = await _deviceIdentity.getOrCreate();
    final operationId = _uuid.v4();
    final eventId = _uuid.v4();
    final now = _clock();
    await _db.transaction(() async {
      await _local.finalizeSessionLocally(
        sessionId: sessionId,
        status: status,
        endedAt: now,
      );
      final dependsOn = await _outbox.latestOperationId(_aggregate, sessionId);
      await _outbox.enqueue(
        operationId: operationId,
        businessId: businessId,
        actorUserId: actorUserId,
        deviceId: deviceId,
        aggregateType: _aggregate,
        aggregateId: sessionId,
        operationType: operationType,
        idempotencyKey: '$businessId:$deviceId:$operationId',
        payload: {
          'session_id': sessionId,
          'event_type': eventType,
          'event_id': eventId,
          'occurred_at': now.toIso8601String(),
          ...extraPayload,
        },
        now: now,
        dependsOnOperationId: dependsOn,
      );
    });
    unawaited(_syncEngine.push().catchError(_handleSyncError));
  }

  Future<void> _enqueueEvent({
    required String sessionId,
    required String businessId,
    required String actorUserId,
    required String eventType,
    required SyncOperationType operationType,
    required Future<void> Function(String entryId, DateTime now) apply,
  }) async {
    final deviceId = await _deviceIdentity.getOrCreate();
    final entryId = _uuid.v4();
    final operationId = _uuid.v4();
    final now = _clock();

    await _db.transaction(() async {
      await apply(entryId, now);
      final dependsOn = await _outbox.latestOperationId(_aggregate, sessionId);
      await _outbox.enqueue(
        operationId: operationId,
        businessId: businessId,
        actorUserId: actorUserId,
        deviceId: deviceId,
        aggregateType: _aggregate,
        aggregateId: sessionId,
        operationType: operationType,
        idempotencyKey: '$businessId:$deviceId:$operationId',
        payload: {
          'session_id': sessionId,
          'event_type': eventType,
          'event_id': entryId,
          'occurred_at': now.toIso8601String(),
        },
        now: now,
        dependsOnOperationId: dependsOn,
      );
    });

    unawaited(_syncEngine.push().catchError(_handleSyncError));
  }

  Future<SyncRunSummary> sync() => _syncEngine.push();

  SyncRunSummary _handleSyncError(Object error, StackTrace stack) {
    _logger.warn(
      error,
      stackTrace: stack,
      context: 'OfflineSessionBackgroundSync',
    );
    return const SyncRunSummary(
      pushed: 0,
      retried: 0,
      failed: 0,
      authRequired: false,
    );
  }
}
