import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suretakip/core/domain/domain_enums.dart';
import 'package:suretakip/core/errors/domain_exception.dart';
import 'package:suretakip/features/sessions/domain/entities/session.dart';
import 'package:suretakip/features/sessions/domain/entities/session_item.dart';
import 'package:suretakip/features/sessions/domain/entities/session_time_entry.dart';
import 'package:suretakip/features/sessions/presentation/controllers/active_sessions_controller.dart';
import 'package:suretakip/features/sessions/presentation/widgets/active_sessions_sheet.dart';

import '../../../../helpers/fake_monotonic_clock.dart';

void main() {
  testWidgets('aktif işlem müşteri adı, süre ve tutarla listelenir', (
    tester,
  ) async {
    // 30 dakikadır açık, dakikası 2,00 ₺ olan bir seans.
    final clock = FakeMonotonicClock();
    final summary = _summary(
      clock: clock,
      startedAt: DateTime.utc(2026, 7, 19, 10),
      serverAnchor: DateTime.utc(2026, 7, 19, 10, 30),
      customerName: 'Ayşe Yılmaz',
    );

    await _pumpSheet(tester, [summary]);

    expect(find.text('Ayşe Yılmaz'), findsOneWidget);
    expect(find.text('Masa Tenisi'), findsOneWidget);
    expect(find.text('00:30:00'), findsOneWidget);
    // 30 dakika × 2,00 ₺ = 60,00 ₺
    expect(find.text('₺60,00'), findsOneWidget);
    expect(find.text('Aktif'), findsOneWidget);
  });

  testWidgets('sayaç saniye başı ilerler ve tutarı günceller', (tester) async {
    final clock = FakeMonotonicClock();
    final summary = _summary(
      clock: clock,
      startedAt: DateTime.utc(2026, 7, 19, 10),
      serverAnchor: DateTime.utc(2026, 7, 19, 10, 30),
    );

    await _pumpSheet(tester, [summary]);
    expect(find.text('00:30:00'), findsOneWidget);

    // Monotonic saat ilerler; sayaç cihaz duvar saatine değil buna bakar.
    clock.advance(const Duration(minutes: 1));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('00:31:00'), findsOneWidget);
    // 31 dakika × 2,00 ₺ = 62,00 ₺
    expect(find.text('₺62,00'), findsOneWidget);
  });

  testWidgets('kayıtlı müşterisi olmayan seans misafir olarak gösterilir', (
    tester,
  ) async {
    final summary = _summary(
      clock: FakeMonotonicClock(),
      startedAt: DateTime.utc(2026, 7, 19, 10),
      serverAnchor: DateTime.utc(2026, 7, 19, 10, 5),
      customerName: null,
    );

    await _pumpSheet(tester, [summary]);

    expect(find.text('Misafir müşteri'), findsOneWidget);
  });

  testWidgets('eklenen ürünler adet ve tutarıyla özetlenir', (tester) async {
    final summary = _summary(
      clock: FakeMonotonicClock(),
      startedAt: DateTime.utc(2026, 7, 19, 10),
      serverAnchor: DateTime.utc(2026, 7, 19, 10, 10),
      items: [_item(lineTotalMinor: 4500)],
    );

    await _pumpSheet(tester, [summary]);

    expect(find.textContaining('1 ürün eklendi'), findsOneWidget);
    expect(find.textContaining('₺45,00'), findsOneWidget);
  });

  testWidgets('açık işlem yoksa boş durum ve başlatma aksiyonu görünür', (
    tester,
  ) async {
    await _pumpSheet(tester, const []);

    expect(find.text('Şu anda devam eden işlem yok.'), findsOneWidget);
    expect(
      find.widgetWithText(FilledButton, 'Yeni İşlem Başlat'),
      findsOneWidget,
    );
  });

  testWidgets('yükleme hatası Türkçe mesaj ve Tekrar Dene sunar', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeSessionSummariesProvider.overrideWith(
            (ref) async => throw const NetworkException(
              'İnternet bağlantısı yok gibi görünüyor.',
            ),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: ActiveSessionsSheet()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('İnternet bağlantısı yok gibi görünüyor.'),
      findsOneWidget,
    );
    expect(find.widgetWithText(OutlinedButton, 'Tekrar Dene'), findsOneWidget);
  });
}

Future<void> _pumpSheet(
  WidgetTester tester,
  List<ActiveSessionSummary> summaries,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        activeSessionSummariesProvider.overrideWith((ref) async => summaries),
      ],
      child: const MaterialApp(home: Scaffold(body: ActiveSessionsSheet())),
    ),
  );
  await tester.pumpAndSettle();
}

ActiveSessionSummary _summary({
  required FakeMonotonicClock clock,
  required DateTime startedAt,
  required DateTime serverAnchor,
  String? customerName = 'Ayşe Yılmaz',
  List<SessionItem> items = const [],
}) => ActiveSessionSummary(
  session: _session(startedAt: startedAt),
  customerName: customerName,
  timeEntries: [_timeEntry(startedAt: startedAt)],
  items: items,
  serverAnchor: serverAnchor,
  clock: clock,
  clockAnchor: clock.elapsed,
);

Session _session({required DateTime startedAt}) => Session(
  id: 'session-1',
  businessId: 'business-1',
  customerId: 'customer-1',
  serviceId: 'service-1',
  openedByMemberId: 'member-1',
  closedByMemberId: null,
  status: SessionStatus.active,
  startedAt: startedAt,
  endedAt: null,
  chargedMinutes: null,
  serviceNameSnapshot: 'Masa Tenisi',
  pricePerMinuteMinorSnapshot: 200,
  roundingIntervalMinutesSnapshot: 1,
  minimumChargeMinutesSnapshot: 0,
  currencyCodeSnapshot: 'TRY',
  serviceSubtotalMinor: null,
  productsSubtotalMinor: null,
  discountMinor: 0,
  taxMinor: 0,
  grandTotalMinor: null,
  notes: null,
  createdAt: startedAt,
  updatedAt: startedAt,
);

SessionTimeEntry _timeEntry({required DateTime startedAt}) => SessionTimeEntry(
  id: 'entry-1',
  businessId: 'business-1',
  sessionId: 'session-1',
  entryType: TimeEntryType.active,
  startedAt: startedAt,
  endedAt: null,
  createdAt: startedAt,
);

SessionItem _item({required int lineTotalMinor}) => SessionItem(
  id: 'item-1',
  businessId: 'business-1',
  sessionId: 'session-1',
  productId: 'product-1',
  productNameSnapshot: 'Su',
  skuSnapshot: null,
  unitPriceMinorSnapshot: lineTotalMinor,
  currencyCodeSnapshot: 'TRY',
  quantity: 1,
  discountMinor: 0,
  taxMinor: 0,
  lineTotalMinor: lineTotalMinor,
  createdAt: DateTime.utc(2026, 7, 19, 10),
  updatedAt: DateTime.utc(2026, 7, 19, 10),
);
