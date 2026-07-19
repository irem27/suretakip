import 'package:suretakip/core/errors/supabase_error_guard.dart';
import 'package:suretakip/core/logging/app_logger.dart';
import 'package:suretakip/core/logging/noop_app_logger.dart';
import 'package:suretakip/core/value_objects/money.dart';
import 'package:suretakip/features/payments/data/datasources/payments_remote_data_source.dart';
import 'package:suretakip/features/payments/domain/entities/payment.dart';
import 'package:suretakip/features/payments/domain/entities/payment_input.dart';
import 'package:suretakip/features/payments/domain/entities/payment_mutation_result.dart';
import 'package:suretakip/features/payments/domain/entities/refund_input.dart';
import 'package:suretakip/features/payments/domain/entities/session_payment_summary.dart';
import 'package:suretakip/features/payments/domain/entities/session_payment_status_summary.dart';
import 'package:suretakip/features/payments/domain/repositories/payments_repository.dart';

class PaymentsRepositoryImpl implements PaymentsRepository {
  const PaymentsRepositoryImpl(
    this._dataSource, {
    AppLogger logger = const NoopAppLogger(),
  }) : _logger = logger;

  final PaymentsRemoteDataSource _dataSource;
  final AppLogger _logger;

  @override
  Future<SessionPaymentSummary> getSessionPaymentSummary(String sessionId) =>
      _guard(
        () async => _summaryFromResponse(
          await _dataSource.getSessionPaymentSummary({
            'p_session_id': sessionId,
          }),
        ),
      );

  @override
  Future<List<SessionPaymentStatusSummary>> getSessionsPaymentStatus(
    List<String> sessionIds,
  ) => _guard(
    () async => _paymentStatusesFromResponse(
      await _dataSource.getSessionsPaymentStatus({'p_session_ids': sessionIds}),
    ),
  );

  @override
  Future<PaymentMutationResult> recordSessionPayment(PaymentInput input) =>
      _guard(
        () async => _mutationFromResponse(
          await _dataSource.recordSessionPayment({
            'p_session_id': input.sessionId,
            'p_payment_method': paymentMethodDatabaseValue(input.method),
            'p_amount_minor': input.amount.minorUnits,
            'p_idempotency_key': input.idempotencyKey,
            'p_external_reference': input.externalReference,
            'p_note': input.note,
          }),
        ),
      );

  @override
  Future<PaymentMutationResult> voidPayment({
    required String paymentId,
    required String reason,
  }) => _guard(
    () async => _mutationFromResponse(
      await _dataSource.voidPayment({
        'p_payment_id': paymentId,
        'p_reason': reason,
      }),
      replayedFallback: false,
    ),
  );

  @override
  Future<PaymentMutationResult> refundPayment(RefundInput input) => _guard(
    () async => _mutationFromResponse(
      await _dataSource.refundPayment({
        'p_payment_id': input.paymentId,
        'p_amount_minor': input.amount.minorUnits,
        'p_idempotency_key': input.idempotencyKey,
        'p_reason': input.reason,
      }),
    ),
  );

  PaymentMutationResult _mutationFromResponse(
    Object? response, {
    bool? replayedFallback,
  }) {
    if (response is! Map) {
      throw const FormatException(
        'Ödeme mutasyonu geçerli bir JSON nesnesi değil.',
      );
    }
    final json = Map<String, dynamic>.from(response);
    return PaymentMutationResult(
      summary: _summaryFromResponse(json),
      paymentId: json['payment_id'] as String,
      replayed: json['replayed'] as bool? ?? replayedFallback ?? false,
    );
  }

  SessionPaymentSummary _summaryFromResponse(Object? response) {
    if (response is! Map) {
      throw const FormatException(
        'Ödeme özeti geçerli bir JSON nesnesi değil.',
      );
    }
    final json = Map<String, dynamic>.from(response);
    final currencyCode = json['currency_code'] as String;
    final paymentRows = json['payments'] as List<dynamic>;
    return SessionPaymentSummary(
      sessionId: json['session_id'] as String,
      sessionTotal: _money(json['session_total_minor'], currencyCode),
      collected: _money(json['collected_minor'], currencyCode),
      refunded: _money(json['refunded_minor'], currencyCode),
      netPaid: _money(json['net_paid_minor'], currencyCode),
      remaining: _money(json['remaining_minor'], currencyCode),
      paymentStatus: sessionPaymentStatusFromDatabase(
        json['payment_status'] as String,
      ),
      currencyCode: currencyCode,
      // Sunucu received_at ASC sırasını garanti eder; istemci tekrar sıralamaz.
      payments: paymentRows
          .map((row) => _paymentFromJson(Map<String, dynamic>.from(row as Map)))
          .toList(growable: false),
    );
  }

  List<SessionPaymentStatusSummary> _paymentStatusesFromResponse(
    Object? response,
  ) {
    if (response is! List) {
      throw const FormatException(
        'Toplu ödeme durumu geçerli bir JSON dizisi değil.',
      );
    }
    return response
        .map(
          (row) =>
              _paymentStatusFromJson(Map<String, dynamic>.from(row as Map)),
        )
        .toList(growable: false);
  }

  SessionPaymentStatusSummary _paymentStatusFromJson(
    Map<String, dynamic> json,
  ) {
    final currencyCode = json['currency_code'] as String;
    return SessionPaymentStatusSummary(
      sessionId: json['session_id'] as String,
      sessionTotal: _money(json['session_total_minor'], currencyCode),
      collected: _money(json['collected_minor'], currencyCode),
      refunded: _money(json['refunded_minor'], currencyCode),
      netPaid: _money(json['net_paid_minor'], currencyCode),
      remaining: _money(json['remaining_minor'], currencyCode),
      paymentStatus: sessionPaymentStatusFromDatabase(
        json['payment_status'] as String,
      ),
      currencyCode: currencyCode,
    );
  }

  Payment _paymentFromJson(Map<String, dynamic> json) => Payment(
    id: json['id'] as String,
    kind: paymentKindFromDatabase(json['payment_kind'] as String),
    method: paymentMethodFromDatabase(json['payment_method'] as String),
    status: paymentRecordStatusFromDatabase(json['status'] as String),
    amountMinor: json['amount_minor'] as int,
    currencyCode: json['currency_code'] as String,
    originalPaymentId: json['original_payment_id'] as String?,
    externalReference: json['external_reference'] as String?,
    note: json['note'] as String?,
    receivedByMemberId: json['received_by_member_id'] as String,
    receivedByMe: json['received_by_me'] as bool,
    receivedAt: DateTime.parse(json['received_at'] as String).toUtc(),
    voidedByMemberId: json['voided_by_member_id'] as String?,
    voidedAt: _date(json['voided_at']),
    voidReason: json['void_reason'] as String?,
  );

  Money _money(Object? minorUnits, String currencyCode) =>
      Money(minorUnits: minorUnits as int, currencyCode: currencyCode);

  DateTime? _date(Object? value) =>
      value == null ? null : DateTime.parse(value as String).toUtc();

  Future<T> _guard<T>(Future<T> Function() operation) => SupabaseErrorGuard.run(
    operation,
    logger: _logger,
    context: 'PaymentsRepository',
  );
}
