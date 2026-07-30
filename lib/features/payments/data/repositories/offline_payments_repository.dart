import 'dart:async';

import 'package:uuid/uuid.dart';
import 'package:suretakip/core/database/app_database.dart';
import 'package:suretakip/core/errors/domain_exception.dart';
import 'package:suretakip/core/logging/app_logger.dart';
import 'package:suretakip/core/logging/noop_app_logger.dart';
import 'package:suretakip/core/sync/device_identity.dart';
import 'package:suretakip/core/sync/models/sync_enums.dart';
import 'package:suretakip/core/sync/outbox_repository.dart';
import 'package:suretakip/core/sync/sync_engine.dart';
import 'package:suretakip/features/payments/domain/entities/payment.dart';
import 'package:suretakip/features/payments/domain/entities/payment_input.dart';
import 'package:suretakip/features/payments/domain/entities/payment_mutation_result.dart';
import 'package:suretakip/features/payments/domain/entities/refund_input.dart';
import 'package:suretakip/features/payments/domain/entities/session_payment_summary.dart';
import 'package:suretakip/features/payments/domain/entities/session_payment_status_summary.dart';
import 'package:suretakip/features/payments/domain/repositories/payments_repository.dart';
import 'package:suretakip/features/sessions/data/local/sessions_local_data_source.dart';

/// Offline-first seans ödeme (tahsilat) yazımı.
///
/// [PaymentsRepository] sözleşmesini uygular; böylece mevcut controller/UI
/// katmanı değişmeden `paymentsRepositoryProvider` bağlaması üzerinden
/// çevrimdışı yazma yoluna geçer (müşteri/ürün/seans deseniyle aynı fikir).
///
/// FİNANSAL RİSK NEDENİYLE BİLİNÇLİ TASARIM FARKI: müşteri/ürün/seans
/// depoları her zaman ÖNCE yerel yazar, sonra arka planda (fire-and-forget)
/// senkronize eder. Ödeme özetı (`SessionPaymentSummary`) ise tamamen
/// SUNUCUDA hesaplanan toplamlar taşır (tahsil edilen/kalan/durum) ve bu
/// depoda yerel bir ayna tablo YOKTUR. Bu toplamları istemcide "tahmin
/// ederek" üretmek, sunucu gerçeğinden sapabilir ve kullanıcıya yanlış
/// bakiye gösterme riski taşır — bu nedenle BİLEREK yapılmaz.
///
/// Bunun yerine: önce ÇEVRİMİÇİ yol (`record_session_payment` RPC, mevcut
/// davranış) denenir. Yalnızca bağlantı hatası ([NetworkException]) alınırsa
/// ödeme yerel outbox'a (aynı idempotency key ile) kuyruğa alınır ve arka
/// planda gönderilmesi tetiklenir; kayıt cihazda GÜVENLE bekler, ama çağıran
/// yine de bir [NetworkException] ile bilgilendirilir (mevcut controller bu
/// hatayı `AsyncError` + "tekrar deneyebilirsiniz" olarak zaten sunar; aynı
/// niyetin retry'ı AYNI idempotency key'i kullandığından ikinci kuyruğa
/// eklemeyi de engelleriz → çift kayıt riski yok).
class OfflinePaymentsRepository implements PaymentsRepository {
  OfflinePaymentsRepository({
    required PaymentsRepository remote,
    required AppDatabase db,
    required SessionsLocalDataSource sessionsLocal,
    required OutboxRepository outbox,
    required DeviceIdentity deviceIdentity,
    required SyncEngine syncEngine,
    required String? Function() currentActorUserId,
    Uuid? uuid,
    DateTime Function()? clock,
    AppLogger logger = const NoopAppLogger(),
  }) : _remote = remote,
       _db = db,
       _sessionsLocal = sessionsLocal,
       _outbox = outbox,
       _deviceIdentity = deviceIdentity,
       _syncEngine = syncEngine,
       _currentActorUserId = currentActorUserId,
       _uuid = uuid ?? const Uuid(),
       _clock = clock ?? (() => DateTime.now().toUtc()),
       _logger = logger;

  static const _aggregate = 'session';

  final PaymentsRepository _remote;
  final AppDatabase _db;
  final SessionsLocalDataSource _sessionsLocal;
  final OutboxRepository _outbox;
  final DeviceIdentity _deviceIdentity;
  final SyncEngine _syncEngine;
  final String? Function() _currentActorUserId;
  final Uuid _uuid;
  final DateTime Function() _clock;
  final AppLogger _logger;

  // Okuma ve void/iade sunucu-otoriteli kalır (mevcut davranış): finansal
  // özet ve iptal/iade akışları offline'a taşınmaz.
  @override
  Future<SessionPaymentSummary> getSessionPaymentSummary(String sessionId) =>
      _remote.getSessionPaymentSummary(sessionId);

  @override
  Future<List<SessionPaymentStatusSummary>> getSessionsPaymentStatus(
    List<String> sessionIds,
  ) => _remote.getSessionsPaymentStatus(sessionIds);

  @override
  Future<PaymentMutationResult> voidPayment({
    required String paymentId,
    required String reason,
  }) => _remote.voidPayment(paymentId: paymentId, reason: reason);

  @override
  Future<PaymentMutationResult> refundPayment(RefundInput input) =>
      _remote.refundPayment(input);

  @override
  Future<PaymentMutationResult> recordSessionPayment(
    PaymentInput input,
  ) async {
    try {
      return await _remote.recordSessionPayment(input);
    } on NetworkException {
      await _queueOffline(input);
      rethrow;
    }
  }

  /// Bağlantı yoksa ödemeyi cihazda kalıcı kuyruğa alır. Aynı [input]
  /// idempotency key'i ile daha önce kuyruğa alınmışsa (ör. kullanıcı
  /// "tekrar dene"ye bastı) YENİ bir outbox kaydı AÇILMAZ — yalnız gönderim
  /// tekrar denenir. Bu, çift-tahsilatın istemci tarafındaki ilk savunma
  /// katmanıdır (sunucudaki ikinci katman: migration'daki kitap + UNIQUE
  /// kısıt).
  Future<void> _queueOffline(PaymentInput input) async {
    final existing = await _outbox.findByIdempotencyKey(input.idempotencyKey);
    if (existing == null) {
      final session = await _sessionsLocal.findSession(input.sessionId);
      if (session == null) {
        // Seans bu cihazda hiç görülmemiş: hangi işletmeye ait olduğunu
        // güvenle bilemeyiz, bu yüzden yanlış işletmeye yazmak yerine
        // kuyruğa ALMADAN vazgeçilir (çağıran zaten NetworkException alacak).
        _logger.warn(
          StateError(
            'Seans yerelde bulunamadığı için ödeme kuyruğa alınamadı: '
            '${input.sessionId}',
          ),
          context: 'OfflinePaymentsRepository.queueOffline',
        );
        return;
      }
      final actorUserId = _currentActorUserId();
      if (actorUserId == null) {
        _logger.warn(
          StateError('Oturum yokken ödeme kuyruğa alınamadı.'),
          context: 'OfflinePaymentsRepository.queueOffline',
        );
        return;
      }
      final deviceId = await _deviceIdentity.getOrCreate();
      final paymentId = _uuid.v4();
      final operationId = _uuid.v4();
      final now = _clock();
      await _db.transaction(() async {
        final dependsOn = await _outbox.latestOperationId(
          _aggregate,
          input.sessionId,
        );
        await _outbox.enqueue(
          operationId: operationId,
          businessId: session.businessId,
          actorUserId: actorUserId,
          deviceId: deviceId,
          aggregateType: _aggregate,
          aggregateId: input.sessionId,
          operationType: SyncOperationType.recordSessionPayment,
          idempotencyKey: input.idempotencyKey,
          payload: {
            'payment_id': paymentId,
            'session_id': input.sessionId,
            'payment_method': paymentMethodDatabaseValue(input.method),
            'amount_minor': input.amount.minorUnits,
            'external_reference': input.externalReference,
            'note': input.note,
          },
          now: now,
          dependsOnOperationId: dependsOn,
        );
      });
    }

    // Fire-and-forget: bağlantı hâlâ yoksa kayıt "bekliyor" kalır, sonra
    // otomatik denenir. Arka plan sync hatası çağıranı asla düşürmemelidir.
    unawaited(_syncEngine.push().catchError(_handleBackgroundSyncError));
  }

  SyncRunSummary _handleBackgroundSyncError(Object error, StackTrace stack) {
    _logger.warn(
      error,
      stackTrace: stack,
      context: 'OfflinePaymentBackgroundSync',
    );
    return const SyncRunSummary(
      pushed: 0,
      retried: 0,
      failed: 0,
      authRequired: false,
    );
  }

  /// Bekleyen tüm kayıtları göndermeyi dener (uygulama açılışı, foreground,
  /// "şimdi senkronize et" gibi tetikleyiciler için).
  Future<SyncRunSummary> sync() => _syncEngine.push();
}
