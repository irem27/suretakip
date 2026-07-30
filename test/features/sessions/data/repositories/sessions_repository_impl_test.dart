import 'package:flutter_test/flutter_test.dart';
import 'package:suretakip/core/errors/domain_exception.dart';
import 'package:suretakip/features/sessions/data/datasources/sessions_remote_data_source.dart';
import 'package:suretakip/features/sessions/data/repositories/sessions_repository_impl.dart';
import 'package:suretakip/features/sessions/domain/entities/session_history_filter.dart';

void main() {
  test(
    'zorunlu bir alan null geldiğinde ham TypeError yerine '
    'DatabaseException fırlatır',
    () async {
      final malformedRow = Map<String, dynamic>.from(_sessionRow)
        ..['service_name_snapshot'] = null;
      final dataSource = _FakeSessionsDataSource()
        ..sessionRowOverride = malformedRow;
      final repository = SessionsRepositoryImpl(dataSource);

      expect(
        () => repository.getSessions(businessId: 'business-1'),
        throwsA(isA<DatabaseException>()),
      );
    },
  );


  test('seans satırını snapshot alanlarıyla domain modeline eşler', () async {
    final repository = SessionsRepositoryImpl(_FakeSessionsDataSource());

    final session = (await repository.getSessions(
      businessId: 'business-1',
    )).single;

    expect(session.id, 'session-1');
    expect(session.serviceNameSnapshot, 'Bilardo');
    expect(session.pricePerMinuteMinorSnapshot, 250);
    expect(session.grandTotalMinor, isNull);
  });

  test('boş notu RPC çağrısına null olarak iletir', () async {
    final dataSource = _FakeSessionsDataSource();
    final repository = SessionsRepositoryImpl(dataSource);

    await repository.startSession(
      businessId: 'business-1',
      serviceId: 'service-1',
      notes: '   ',
    );

    expect(dataSource.notes, isNull);
  });

  test('sunucu zamanını UTC olarak eşler', () async {
    final repository = SessionsRepositoryImpl(_FakeSessionsDataSource());

    final now = await repository.serverNow();

    expect(now.isUtc, isTrue);
    expect(now, DateTime.utc(2026, 7, 18, 10));
  });
}

class _FakeSessionsDataSource implements SessionsRemoteDataSource {
  String? notes;
  Map<String, dynamic>? sessionRowOverride;

  Map<String, dynamic> get _row => sessionRowOverride ?? _sessionRow;

  @override
  Future<List<Map<String, dynamic>>> getSessions({
    required String businessId,
    String? customerId,
  }) async => [_row];

  @override
  Future<List<Map<String, dynamic>>> getOpenSessions(String businessId) async =>
      [_sessionRow];

  @override
  Future<List<Map<String, dynamic>>> getSessionsByIds(
    String businessId,
    List<String> sessionIds,
  ) async => sessionIds.contains(_sessionRow['id']) ? [_sessionRow] : [];

  @override
  Future<Map<String, dynamic>> getSession(String sessionId) async =>
      _sessionRow;

  @override
  Future<List<Map<String, dynamic>>> getSessionHistory({
    required String businessId,
    required SessionHistoryFilter filter,
  }) async => [_sessionRow];

  @override
  Future<List<Map<String, dynamic>>> getSessionItems(String sessionId) async =>
      [];

  @override
  Future<List<Map<String, dynamic>>> getSessionTimeEntries(
    String sessionId,
  ) async => [];

  @override
  Future<List<Map<String, dynamic>>> getItemsForSessions(
    List<String> sessionIds,
  ) async => [];

  @override
  Future<List<Map<String, dynamic>>> getTimeEntriesForSessions(
    List<String> sessionIds,
  ) async => [];

  @override
  Future<dynamic> startSession({
    required String businessId,
    required String serviceId,
    String? customerId,
    String? notes,
  }) async {
    this.notes = notes;
    return 'session-1';
  }

  @override
  Future<dynamic> pauseSession(String sessionId) async => sessionId;

  @override
  Future<dynamic> resumeSession(String sessionId) async => sessionId;

  @override
  Future<dynamic> addProductToSession({
    required String sessionId,
    required String productId,
    required int quantity,
    required int discountMinor,
    required int taxMinor,
  }) async => sessionId;

  @override
  Future<dynamic> completeSession({
    required String sessionId,
    required int discountMinor,
    required int taxMinor,
  }) async => sessionId;

  @override
  Future<dynamic> cancelSession(String sessionId) async => sessionId;

  @override
  Future<dynamic> serverNow() async => '2026-07-18T13:00:00+03:00';
}

final _sessionRow = <String, dynamic>{
  'id': 'session-1',
  'business_id': 'business-1',
  'customer_id': null,
  'service_id': 'service-1',
  'opened_by_member_id': 'member-1',
  'closed_by_member_id': null,
  'status': 'active',
  'started_at': '2026-07-18T10:00:00Z',
  'ended_at': null,
  'charged_minutes': null,
  'service_name_snapshot': 'Bilardo',
  'price_per_minute_minor_snapshot': 250,
  'rounding_interval_minutes_snapshot': 15,
  'minimum_charge_minutes_snapshot': 10,
  'currency_code_snapshot': 'TRY',
  'service_subtotal_minor': null,
  'products_subtotal_minor': null,
  'discount_minor': 0,
  'tax_minor': 0,
  'grand_total_minor': null,
  'notes': null,
  'created_at': '2026-07-18T10:00:00Z',
  'updated_at': '2026-07-18T10:00:00Z',
};
