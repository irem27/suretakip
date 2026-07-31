import 'package:flutter_test/flutter_test.dart';
import 'package:suretakip/core/errors/domain_exception.dart';
import 'package:suretakip/features/sessions/data/datasources/sessions_remote_data_source.dart';
import 'package:suretakip/features/sessions/data/repositories/sessions_repository_impl.dart';
import 'package:suretakip/features/sessions/domain/entities/session_history_filter.dart';

/// [SessionsRepositoryImpl]'ın ilk test dosyasında kapsanmayan yollarını
/// (toplu getiriciler, zaman/kalem gruplama, geçersiz enum değerleri, RPC
/// dönüş değeri eşlemesi) kilitler.
void main() {
  test('getSessionsByIds boş liste verildiğinde bile veri kaynağını çağırır '
      '(erken çıkış uygulanmaz)', () async {
    final dataSource = _FakeSessionsDataSource();
    final repository = SessionsRepositoryImpl(dataSource);

    final result = await repository.getSessionsByIds(
      businessId: 'business-1',
      sessionIds: const [],
    );

    expect(result.single.id, 'session-1');
  });

  test(
    'getTimeEntriesForSessions kayıtları sessionId bazında gruplar',
    () async {
      final dataSource = _FakeSessionsDataSource()
        ..timeEntryRows = [
          _timeEntryRow(sessionId: 'session-1'),
          _timeEntryRow(sessionId: 'session-1'),
          _timeEntryRow(sessionId: 'session-2'),
        ];
      final repository = SessionsRepositoryImpl(dataSource);

      final grouped = await repository.getTimeEntriesForSessions([
        'session-1',
        'session-2',
      ]);

      expect(grouped['session-1'], hasLength(2));
      expect(grouped['session-2'], hasLength(1));
    },
  );

  test('getTimeEntriesForSessions boş sessionIds için veri kaynağına sormadan '
      'boş harita döner', () async {
    final repository = SessionsRepositoryImpl(_FakeSessionsDataSource());

    final grouped = await repository.getTimeEntriesForSessions(const []);

    expect(grouped, isEmpty);
  });

  test('getItemsForSessions kayıtları sessionId bazında gruplar', () async {
    final dataSource = _FakeSessionsDataSource()
      ..itemRows = [
        _itemRow(sessionId: 'session-1'),
        _itemRow(sessionId: 'session-2'),
      ];
    final repository = SessionsRepositoryImpl(dataSource);

    final grouped = await repository.getItemsForSessions([
      'session-1',
      'session-2',
    ]);

    expect(grouped.keys, containsAll(['session-1', 'session-2']));
  });

  test('bilinmeyen işlem durumu ham FormatException yerine UnknownException '
      'olarak dışa sızar (guard sarmalaması)', () async {
    final dataSource = _FakeSessionsDataSource()
      ..sessionRowOverride = (Map<String, dynamic>.from(_sessionRow)
        ..['status'] = 'unknown_status');
    final repository = SessionsRepositoryImpl(dataSource);

    await expectLater(
      repository.getSessions(businessId: 'business-1'),
      throwsA(isA<UnknownException>()),
    );
  });

  test('bilinmeyen zaman türü ham FormatException yerine UnknownException '
      'olarak dışa sızar (guard sarmalaması)', () async {
    final dataSource = _FakeSessionsDataSource()
      ..timeEntryRows = [
        Map<String, dynamic>.from(_timeEntryRow(sessionId: 'session-1'))
          ..['entry_type'] = 'unknown_type',
      ];
    final repository = SessionsRepositoryImpl(dataSource);

    await expectLater(
      repository.getSessionTimeEntries('session-1'),
      throwsA(isA<UnknownException>()),
    );
  });

  test('addProductToSession sonucu String olarak döner', () async {
    final repository = SessionsRepositoryImpl(_FakeSessionsDataSource());

    final result = await repository.addProductToSession(
      sessionId: 'session-1',
      productId: 'product-1',
      quantity: 2,
    );

    expect(result, 'session-1');
  });

  test('completeSession sonucu String olarak döner', () async {
    final repository = SessionsRepositoryImpl(_FakeSessionsDataSource());

    final result = await repository.completeSession(sessionId: 'session-1');

    expect(result, 'session-1');
  });

  test('cancelSession sonucu String olarak döner', () async {
    final repository = SessionsRepositoryImpl(_FakeSessionsDataSource());

    final result = await repository.cancelSession(sessionId: 'session-1');

    expect(result, 'session-1');
  });

  test('pauseSession ve resumeSession veri kaynağına iletilir', () async {
    final repository = SessionsRepositoryImpl(_FakeSessionsDataSource());

    expect(await repository.pauseSession(sessionId: 'session-1'), 'session-1');
    expect(await repository.resumeSession(sessionId: 'session-1'), 'session-1');
  });

  test('getSessionHistory filtreyle çağrılır ve satırları eşler', () async {
    final repository = SessionsRepositoryImpl(_FakeSessionsDataSource());

    final result = await repository.getSessionHistory(
      businessId: 'business-1',
      filter: const SessionHistoryFilter(statuses: []),
    );

    expect(result.single.id, 'session-1');
  });

  test('getOpenSessions açık seansları eşler', () async {
    final repository = SessionsRepositoryImpl(_FakeSessionsDataSource());

    final result = await repository.getOpenSessions(businessId: 'business-1');

    expect(result.single.status.name, 'active');
  });
}

class _FakeSessionsDataSource implements SessionsRemoteDataSource {
  Map<String, dynamic>? sessionRowOverride;
  List<Map<String, dynamic>> timeEntryRows = [];
  List<Map<String, dynamic>> itemRows = [];

  Map<String, dynamic> get _row => sessionRowOverride ?? _sessionRow;

  @override
  Future<List<Map<String, dynamic>>> getSessions({
    required String businessId,
    String? customerId,
  }) async => [_row];

  @override
  Future<List<Map<String, dynamic>>> getOpenSessions(String businessId) async =>
      [_row];

  @override
  Future<List<Map<String, dynamic>>> getSessionsByIds(
    String businessId,
    List<String> sessionIds,
  ) async => [_row];

  @override
  Future<Map<String, dynamic>> getSession(String sessionId) async => _row;

  @override
  Future<List<Map<String, dynamic>>> getSessionHistory({
    required String businessId,
    required SessionHistoryFilter filter,
  }) async => [_row];

  @override
  Future<List<Map<String, dynamic>>> getSessionItems(String sessionId) async =>
      itemRows;

  @override
  Future<List<Map<String, dynamic>>> getSessionTimeEntries(
    String sessionId,
  ) async => timeEntryRows;

  @override
  Future<List<Map<String, dynamic>>> getItemsForSessions(
    List<String> sessionIds,
  ) async {
    if (sessionIds.isEmpty) {
      throw StateError('Boş liste ile veri kaynağı çağrılmamalı');
    }
    return itemRows;
  }

  @override
  Future<List<Map<String, dynamic>>> getTimeEntriesForSessions(
    List<String> sessionIds,
  ) async {
    if (sessionIds.isEmpty) {
      throw StateError('Boş liste ile veri kaynağı çağrılmamalı');
    }
    return timeEntryRows;
  }

  @override
  Future<dynamic> startSession({
    required String businessId,
    required String serviceId,
    String? customerId,
    String? notes,
  }) async => 'session-1';

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

Map<String, dynamic> _timeEntryRow({required String sessionId}) => {
  'id': 'entry-${DateTime.now().microsecondsSinceEpoch}',
  'business_id': 'business-1',
  'session_id': sessionId,
  'entry_type': 'active',
  'started_at': '2026-07-18T10:00:00Z',
  'ended_at': null,
  'created_at': '2026-07-18T10:00:00Z',
};

Map<String, dynamic> _itemRow({required String sessionId}) => {
  'id': 'item-${DateTime.now().microsecondsSinceEpoch}',
  'business_id': 'business-1',
  'session_id': sessionId,
  'product_id': 'product-1',
  'product_name_snapshot': 'Kola',
  'sku_snapshot': null,
  'unit_price_minor_snapshot': 3000,
  'currency_code_snapshot': 'TRY',
  'quantity': 1,
  'discount_minor': 0,
  'tax_minor': 0,
  'line_total_minor': 3000,
  'created_at': '2026-07-18T10:00:00Z',
  'updated_at': '2026-07-18T10:00:00Z',
};

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
