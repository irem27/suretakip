import 'package:suretakip/core/domain/domain_enums.dart';
import 'package:suretakip/core/errors/domain_exception.dart';
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
    id: _requiredString(json, 'id'),
    businessId: _requiredString(json, 'business_id'),
    customerId: json['customer_id'] as String?,
    serviceId: _requiredString(json, 'service_id'),
    openedByMemberId: _requiredString(json, 'opened_by_member_id'),
    closedByMemberId: json['closed_by_member_id'] as String?,
    status: _sessionStatus(_requiredString(json, 'status')),
    startedAt: DateTime.parse(_requiredString(json, 'started_at')),
    endedAt: _date(json['ended_at']),
    chargedMinutes: json['charged_minutes'] as int?,
    serviceNameSnapshot: _requiredString(json, 'service_name_snapshot'),
    pricePerMinuteMinorSnapshot: _requiredInt(
      json,
      'price_per_minute_minor_snapshot',
    ),
    roundingIntervalMinutesSnapshot: _requiredInt(
      json,
      'rounding_interval_minutes_snapshot',
    ),
    minimumChargeMinutesSnapshot: _requiredInt(
      json,
      'minimum_charge_minutes_snapshot',
    ),
    currencyCodeSnapshot: _requiredString(json, 'currency_code_snapshot'),
    serviceSubtotalMinor: json['service_subtotal_minor'] as int?,
    productsSubtotalMinor: json['products_subtotal_minor'] as int?,
    discountMinor: _requiredInt(json, 'discount_minor'),
    taxMinor: _requiredInt(json, 'tax_minor'),
    grandTotalMinor: json['grand_total_minor'] as int?,
    notes: json['notes'] as String?,
    createdAt: DateTime.parse(_requiredString(json, 'created_at')),
    updatedAt: DateTime.parse(_requiredString(json, 'updated_at')),
  );

  SessionItem _itemFromJson(Map<String, dynamic> json) => SessionItem(
    id: _requiredString(json, 'id'),
    businessId: _requiredString(json, 'business_id'),
    sessionId: _requiredString(json, 'session_id'),
    productId: json['product_id'] as String?,
    productNameSnapshot: _requiredString(json, 'product_name_snapshot'),
    skuSnapshot: json['sku_snapshot'] as String?,
    unitPriceMinorSnapshot: _requiredInt(json, 'unit_price_minor_snapshot'),
    currencyCodeSnapshot: _requiredString(json, 'currency_code_snapshot'),
    quantity: _requiredInt(json, 'quantity'),
    discountMinor: _requiredInt(json, 'discount_minor'),
    taxMinor: _requiredInt(json, 'tax_minor'),
    lineTotalMinor: _requiredInt(json, 'line_total_minor'),
    createdAt: DateTime.parse(_requiredString(json, 'created_at')),
    updatedAt: DateTime.parse(_requiredString(json, 'updated_at')),
  );

  SessionTimeEntry _timeEntryFromJson(Map<String, dynamic> json) =>
      SessionTimeEntry(
        id: _requiredString(json, 'id'),
        businessId: _requiredString(json, 'business_id'),
        sessionId: _requiredString(json, 'session_id'),
        entryType: switch (_requiredString(json, 'entry_type')) {
          'active' => TimeEntryType.active,
          'paused' => TimeEntryType.paused,
          final value => throw FormatException('Bilinmeyen zaman türü: $value'),
        },
        startedAt: DateTime.parse(_requiredString(json, 'started_at')),
        endedAt: _date(json['ended_at']),
        createdAt: DateTime.parse(_requiredString(json, 'created_at')),
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

  /// Sunucudan gelen zorunlu bir metin alanını güvenli biçimde ayrıştırır.
  ///
  /// `as String` yerine kullanılır: alan `null` veya beklenmeyen bir türde
  /// gelirse ham `TypeError` yerine kök nedeni açıklayan bir
  /// [DatabaseException] fırlatılır.
  String _requiredString(Map<String, dynamic> json, String field) {
    final value = json[field];
    if (value is String) return value;
    throw DatabaseException(
      'Sunucudan gelen "$field" alanı eksik veya geçersiz türde.',
      code: 'invalid_row_field',
    );
  }

  /// Sunucudan gelen zorunlu bir sayısal alanı güvenli biçimde ayrıştırır.
  ///
  /// `as int` yerine kullanılır: alan `null` veya beklenmeyen bir türde
  /// gelirse ham `TypeError` yerine kök nedeni açıklayan bir
  /// [DatabaseException] fırlatılır.
  int _requiredInt(Map<String, dynamic> json, String field) {
    final value = json[field];
    if (value is int) return value;
    throw DatabaseException(
      'Sunucudan gelen "$field" alanı eksik veya geçersiz türde.',
      code: 'invalid_row_field',
    );
  }

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
