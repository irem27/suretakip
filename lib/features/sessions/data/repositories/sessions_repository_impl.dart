import 'package:suretakip/core/domain/domain_enums.dart';
import 'package:suretakip/core/errors/supabase_error_guard.dart';
import 'package:suretakip/core/logging/app_logger.dart';
import 'package:suretakip/core/logging/noop_app_logger.dart';
import 'package:suretakip/features/sessions/data/datasources/sessions_remote_data_source.dart';
import 'package:suretakip/features/sessions/domain/entities/session.dart';
import 'package:suretakip/features/sessions/domain/entities/session_history_filter.dart';
import 'package:suretakip/features/sessions/domain/entities/session_item.dart';
import 'package:suretakip/features/sessions/domain/entities/session_time_entry.dart';
import 'package:suretakip/features/sessions/domain/repositories/sessions_repository.dart';

class SessionsRepositoryImpl implements SessionsRepository {
  const SessionsRepositoryImpl(
    this._dataSource, {
    AppLogger logger = const NoopAppLogger(),
  }) : _logger = logger;

  final SessionsRemoteDataSource _dataSource;
  final AppLogger _logger;

  @override
  Future<List<Session>> getSessions({
    required String businessId,
    String? customerId,
  }) => _guard(() async {
    final rows = await _dataSource.getSessions(
      businessId: businessId,
      customerId: customerId,
    );
    return rows.map(_sessionFromJson).toList(growable: false);
  });

  @override
  Future<Session> getSession(String sessionId) => _guard(
    () async => _sessionFromJson(await _dataSource.getSession(sessionId)),
  );

  @override
  Future<List<Session>> getOpenSessions({required String businessId}) =>
      _guard(() async {
        final rows = await _dataSource.getOpenSessions(businessId);
        return rows.map(_sessionFromJson).toList(growable: false);
      });

  @override
  Future<List<Session>> getSessionsByIds({
    required String businessId,
    required List<String> sessionIds,
  }) => _guard(() async {
    final rows = await _dataSource.getSessionsByIds(businessId, sessionIds);
    return rows.map(_sessionFromJson).toList(growable: false);
  });

  @override
  Future<List<Session>> getSessionHistory({
    required String businessId,
    required SessionHistoryFilter filter,
  }) => _guard(() async {
    final rows = await _dataSource.getSessionHistory(
      businessId: businessId,
      filter: filter,
    );
    return rows.map(_sessionFromJson).toList(growable: false);
  });

  @override
  Future<List<SessionItem>> getSessionItems(String sessionId) =>
      _guard(() async {
        final rows = await _dataSource.getSessionItems(sessionId);
        return rows.map(_itemFromJson).toList(growable: false);
      });

  @override
  Future<List<SessionTimeEntry>> getSessionTimeEntries(String sessionId) =>
      _guard(() async {
        final rows = await _dataSource.getSessionTimeEntries(sessionId);
        return rows.map(_timeEntryFromJson).toList(growable: false);
      });

  @override
  Future<Map<String, List<SessionTimeEntry>>> getTimeEntriesForSessions(
    List<String> sessionIds,
  ) => _guard(() async {
    if (sessionIds.isEmpty) return const {};
    final rows = await _dataSource.getTimeEntriesForSessions(sessionIds);
    final grouped = <String, List<SessionTimeEntry>>{};
    for (final row in rows) {
      final entry = _timeEntryFromJson(row);
      (grouped[entry.sessionId] ??= <SessionTimeEntry>[]).add(entry);
    }
    return grouped;
  });

  @override
  Future<Map<String, List<SessionItem>>> getItemsForSessions(
    List<String> sessionIds,
  ) => _guard(() async {
    if (sessionIds.isEmpty) return const {};
    final rows = await _dataSource.getItemsForSessions(sessionIds);
    final grouped = <String, List<SessionItem>>{};
    for (final row in rows) {
      final item = _itemFromJson(row);
      (grouped[item.sessionId] ??= <SessionItem>[]).add(item);
    }
    return grouped;
  });

  @override
  Future<String> startSession({
    required String businessId,
    required String serviceId,
    String? customerId,
    String? notes,
  }) => _guard(() async {
    final result = await _dataSource.startSession(
      businessId: businessId,
      serviceId: serviceId,
      customerId: customerId,
      notes: _nullIfBlank(notes),
    );
    return result as String;
  });

  @override
  Future<String> pauseSession({required String sessionId}) =>
      _guard(() async => await _dataSource.pauseSession(sessionId) as String);

  @override
  Future<String> resumeSession({required String sessionId}) =>
      _guard(() async => await _dataSource.resumeSession(sessionId) as String);

  @override
  Future<String> addProductToSession({
    required String sessionId,
    required String productId,
    required int quantity,
    int discountMinor = 0,
    int taxMinor = 0,
  }) => _guard(
    () async =>
        await _dataSource.addProductToSession(
              sessionId: sessionId,
              productId: productId,
              quantity: quantity,
              discountMinor: discountMinor,
              taxMinor: taxMinor,
            )
            as String,
  );

  @override
  Future<String> completeSession({
    required String sessionId,
    int discountMinor = 0,
    int taxMinor = 0,
  }) => _guard(
    () async =>
        await _dataSource.completeSession(
              sessionId: sessionId,
              discountMinor: discountMinor,
              taxMinor: taxMinor,
            )
            as String,
  );

  @override
  Future<String> cancelSession({required String sessionId}) =>
      _guard(() async => await _dataSource.cancelSession(sessionId) as String);

  @override
  Future<DateTime> serverNow() => _guard(
    () async => DateTime.parse(await _dataSource.serverNow() as String).toUtc(),
  );

  Session _sessionFromJson(Map<String, dynamic> json) => Session(
    id: json['id'] as String,
    businessId: json['business_id'] as String,
    customerId: json['customer_id'] as String?,
    serviceId: json['service_id'] as String,
    openedByMemberId: json['opened_by_member_id'] as String,
    closedByMemberId: json['closed_by_member_id'] as String?,
    status: _sessionStatus(json['status'] as String),
    startedAt: DateTime.parse(json['started_at'] as String),
    endedAt: _date(json['ended_at']),
    chargedMinutes: json['charged_minutes'] as int?,
    serviceNameSnapshot: json['service_name_snapshot'] as String,
    pricePerMinuteMinorSnapshot: json['price_per_minute_minor_snapshot'] as int,
    roundingIntervalMinutesSnapshot:
        json['rounding_interval_minutes_snapshot'] as int,
    minimumChargeMinutesSnapshot:
        json['minimum_charge_minutes_snapshot'] as int,
    currencyCodeSnapshot: json['currency_code_snapshot'] as String,
    serviceSubtotalMinor: json['service_subtotal_minor'] as int?,
    productsSubtotalMinor: json['products_subtotal_minor'] as int?,
    discountMinor: json['discount_minor'] as int,
    taxMinor: json['tax_minor'] as int,
    grandTotalMinor: json['grand_total_minor'] as int?,
    notes: json['notes'] as String?,
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
  );

  SessionItem _itemFromJson(Map<String, dynamic> json) => SessionItem(
    id: json['id'] as String,
    businessId: json['business_id'] as String,
    sessionId: json['session_id'] as String,
    productId: json['product_id'] as String?,
    productNameSnapshot: json['product_name_snapshot'] as String,
    skuSnapshot: json['sku_snapshot'] as String?,
    unitPriceMinorSnapshot: json['unit_price_minor_snapshot'] as int,
    currencyCodeSnapshot: json['currency_code_snapshot'] as String,
    quantity: json['quantity'] as int,
    discountMinor: json['discount_minor'] as int,
    taxMinor: json['tax_minor'] as int,
    lineTotalMinor: json['line_total_minor'] as int,
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
  );

  SessionTimeEntry _timeEntryFromJson(Map<String, dynamic> json) =>
      SessionTimeEntry(
        id: json['id'] as String,
        businessId: json['business_id'] as String,
        sessionId: json['session_id'] as String,
        entryType: switch (json['entry_type'] as String) {
          'active' => TimeEntryType.active,
          'paused' => TimeEntryType.paused,
          final value => throw FormatException('Bilinmeyen zaman türü: $value'),
        },
        startedAt: DateTime.parse(json['started_at'] as String),
        endedAt: _date(json['ended_at']),
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  SessionStatus _sessionStatus(String value) => switch (value) {
    'draft' => SessionStatus.draft,
    'active' => SessionStatus.active,
    'paused' => SessionStatus.paused,
    'completed' => SessionStatus.completed,
    'cancelled' => SessionStatus.cancelled,
    _ => throw FormatException('Bilinmeyen işlem durumu: $value'),
  };

  DateTime? _date(Object? value) =>
      value == null ? null : DateTime.parse(value as String);

  String? _nullIfBlank(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  Future<T> _guard<T>(Future<T> Function() operation) => SupabaseErrorGuard.run(
    operation,
    logger: _logger,
    context: 'SessionsRepository',
  );
}
