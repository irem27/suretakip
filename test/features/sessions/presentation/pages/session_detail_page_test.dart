import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suretakip/core/domain/domain_enums.dart';
import 'package:suretakip/core/errors/domain_exception.dart';
import 'package:suretakip/features/sessions/domain/entities/session.dart';
import 'package:suretakip/features/sessions/domain/entities/session_time_entry.dart';
import 'package:suretakip/features/sessions/presentation/controllers/sessions_controllers.dart';
import 'package:suretakip/features/sessions/presentation/pages/session_detail_page.dart';

import '../../../../helpers/fake_monotonic_clock.dart';

void main() {
  testWidgets('ağ hatası bağlantı mesajı, ikonu ve yeniden denemeyi gösterir', (
    tester,
  ) async {
    const message = 'Çevrimdışı moddasınız.';
    var loadCount = 0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionDetailProvider('session-1').overrideWith((ref) async {
            loadCount++;
            throw const NetworkException(message);
          }),
        ],
        child: const MaterialApp(
          home: SessionDetailPage(sessionId: 'session-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(message), findsOneWidget);
    expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);
    expect(find.byIcon(Icons.error_outline_rounded), findsNothing);
    final retryButton = find.widgetWithText(OutlinedButton, 'Yenile');
    expect(retryButton, findsOneWidget);

    await tester.tap(retryButton);
    await tester.pumpAndSettle();

    expect(loadCount, 2);
    expect(find.text(message), findsOneWidget);
  });

  testWidgets('diğer yükleme hatası ayrı ikonla yeniden deneme sunar', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionDetailProvider('session-1').overrideWith(
            (ref) async => throw const UnknownException('Ham hata'),
          ),
        ],
        child: const MaterialApp(
          home: SessionDetailPage(sessionId: 'session-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('İşlem bilgileri yüklenemedi.'), findsOneWidget);
    expect(find.text('Ham hata'), findsNothing);
    expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Tekrar Dene'), findsOneWidget);
  });

  testWidgets(
    'tamamlanan işlem DB kesin tutarlarını gösterir, önizleme değil',
    (tester) async {
      await _pump(tester, _completedState());
      await tester.pumpAndSettle();

      expect(find.text('ÜCRETLENDİRİLEN SÜRE'), findsOneWidget);
      expect(find.text('30 dakika'), findsOneWidget);
      expect(find.text('Kesinleşen ücretlendirme'), findsOneWidget);
      // Kesinleşmiş finansal kayıt için canlı önizleme gösterilmemeli.
      expect(find.textContaining('ücret önizlemesi'), findsNothing);
      expect(find.text('AKTİF SÜRE'), findsNothing);
      expect(find.text('Genel Toplam'), findsOneWidget);
    },
  );

  testWidgets('offline tamamlanan işlem eşitleme bekliyor olarak gösterilir', (
    tester,
  ) async {
    await _pump(tester, _completedWithoutTotalsState());
    await tester.pumpAndSettle();

    expect(find.text('Tamamlandı'), findsWidgets);
    expect(find.text('Kesin tutar eşitleme bekliyor'), findsOneWidget);
    expect(find.text('Taslak işlem'), findsNothing);
    expect(find.text('Genel Toplam'), findsNothing);
    expect(find.text('Ödeme'), findsNothing);
    expect(find.text('Tahsil Et'), findsNothing);
  });

  testWidgets('açıkken iptal edilen işlemde fiyat kartı gösterilmez', (
    tester,
  ) async {
    // Hiç tamamlanmadan iptal edilen seansta kesin tutar yoktur;
    // client'ta yeniden hesaplanmış bir tutar da gösterilmemelidir.
    await _pump(tester, _cancelledWithoutTotalsState());
    await tester.pumpAndSettle();

    // Durum rozeti de aynı metni taşıyor; asıl iddia fiyat kartının yokluğu.
    expect(find.text('İptal edildi'), findsWidgets);
    expect(find.text('Genel Toplam'), findsNothing);
  });

  testWidgets('taslak işlem iptal edildi yerine taslak durumunu gösterir', (
    tester,
  ) async {
    // draft: henüz başlatılmamış seans; yanlışlıkla "İptal edildi"
    // gösterilmemeli (regresyon: SessionStatus.draft ele alınmıyordu).
    await _pump(tester, _draftState());
    await tester.pumpAndSettle();

    expect(find.text('Taslak işlem'), findsOneWidget);
    expect(find.text('Henüz başlatılmadı'), findsOneWidget);
    expect(find.text('İptal edildi'), findsNothing);
  });

  testWidgets('tamamlanıp iptal edilen işlem kesin tutarlarını korur', (
    tester,
  ) async {
    await _pump(tester, _completedState(status: SessionStatus.cancelled));
    await tester.pumpAndSettle();

    expect(find.text('Genel Toplam'), findsOneWidget);
  });

  testWidgets('açık işlemde tamamlama modalı onay ister', (tester) async {
    await _pump(tester, _activeState());
    // Aktif seansta saniyelik sayaç var; pumpAndSettle kullanılamaz.
    await tester.pump();

    expect(find.text('AKTİF SÜRE'), findsOneWidget);
    expect(find.textContaining('ücret önizlemesi'), findsOneWidget);

    await tester.tap(find.text('İşlemi Tamamla'));
    await tester.pump();

    expect(find.text('İşlemi tamamla'), findsOneWidget);
    expect(find.text('Onayla ve Tamamla'), findsOneWidget);
    expect(find.text('Vazgeç'), findsOneWidget);
    expect(
      find.textContaining('Kesin süre ve tutar sunucu tarafından'),
      findsOneWidget,
    );

    // Sayacı durdurmak için ağacı sök (bekleyen timer kalmasın).
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('tamamlama başarısı çevrimiçi tahsilatı otomatik açmaz', (
    tester,
  ) async {
    final actions = _CompletingSessionActionsController();
    tester.view.physicalSize = const Size(1200, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionDetailProvider(
            'session-1',
          ).overrideWith((ref) => _activeState()),
          sessionActionsControllerProvider.overrideWith(() => actions),
        ],
        child: const MaterialApp(
          home: SessionDetailPage(sessionId: 'session-1'),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('İşlemi Tamamla'));
    await tester.pump();
    await tester.tap(find.text('Onayla ve Tamamla'));
    await tester.pumpAndSettle();

    expect(actions.completeCalls, 1);
    expect(find.text('Tahsilat'), findsNothing);
    expect(find.byTooltip('Ödeme yapmadan kapat'), findsNothing);
    expect(
      find.text(
        'İşlem tamamlandı. Kesin tutar eşitlenince tahsilat yapabilirsiniz.',
      ),
      findsOneWidget,
    );
  });
}

Future<void> _pump(WidgetTester tester, SessionDetailState state) async {
  // Sayfa uzun bir ListView; varsayılan 800x600 görünümde alttaki aksiyonlar
  // lazy build edilmediği için görünüm yükseltilir.
  tester.view.physicalSize = const Size(1200, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        // Senkron dönüş: ilk karede AsyncData olur, loading karesi beklemeyiz.
        sessionDetailProvider('session-1').overrideWith((ref) => state),
      ],
      child: const MaterialApp(home: SessionDetailPage(sessionId: 'session-1')),
    ),
  );
}

SessionDetailState _completedState({
  SessionStatus status = SessionStatus.completed,
}) => SessionDetailState(
  session: _session(
    status: status,
    chargedMinutes: 30,
    serviceSubtotalMinor: 7500,
    productsSubtotalMinor: 3000,
    grandTotalMinor: 10500,
    endedAt: DateTime.utc(2026, 7, 17, 12, 30),
  ),
  customerName: 'Ali',
  items: const [],
  timeEntries: [
    SessionTimeEntry(
      id: 'entry-1',
      businessId: 'business-1',
      sessionId: 'session-1',
      entryType: TimeEntryType.active,
      startedAt: DateTime.utc(2026, 7, 17, 12),
      endedAt: DateTime.utc(2026, 7, 17, 12, 30),
      createdAt: DateTime.utc(2026, 7, 17, 12),
    ),
  ],
  serverAnchor: DateTime.utc(2026, 7, 17, 13),
  clock: FakeMonotonicClock(),
  clockAnchor: Duration.zero,
);

SessionDetailState _cancelledWithoutTotalsState() => SessionDetailState(
  session: _session(status: SessionStatus.cancelled),
  customerName: 'Ali',
  items: const [],
  timeEntries: [
    SessionTimeEntry(
      id: 'entry-1',
      businessId: 'business-1',
      sessionId: 'session-1',
      entryType: TimeEntryType.active,
      startedAt: DateTime.utc(2026, 7, 17, 12),
      endedAt: DateTime.utc(2026, 7, 17, 12, 20),
      createdAt: DateTime.utc(2026, 7, 17, 12),
    ),
  ],
  serverAnchor: DateTime.utc(2026, 7, 17, 13),
  clock: FakeMonotonicClock(),
  clockAnchor: Duration.zero,
);

SessionDetailState _completedWithoutTotalsState() => SessionDetailState(
  session: _session(
    status: SessionStatus.completed,
    endedAt: DateTime.utc(2026, 7, 17, 12, 20),
  ),
  customerName: 'Ali',
  items: const [],
  timeEntries: [
    SessionTimeEntry(
      id: 'entry-1',
      businessId: 'business-1',
      sessionId: 'session-1',
      entryType: TimeEntryType.active,
      startedAt: DateTime.utc(2026, 7, 17, 12),
      endedAt: DateTime.utc(2026, 7, 17, 12, 20),
      createdAt: DateTime.utc(2026, 7, 17, 12),
    ),
  ],
  serverAnchor: DateTime.utc(2026, 7, 17, 13),
  clock: FakeMonotonicClock(),
  clockAnchor: Duration.zero,
);

SessionDetailState _draftState() => SessionDetailState(
  session: _session(status: SessionStatus.draft),
  customerName: 'Ali',
  items: const [],
  timeEntries: const [],
  serverAnchor: DateTime.utc(2026, 7, 17, 12),
  clock: FakeMonotonicClock(),
  clockAnchor: Duration.zero,
);

SessionDetailState _activeState() => SessionDetailState(
  session: _session(status: SessionStatus.active),
  customerName: null,
  items: const [],
  timeEntries: [
    SessionTimeEntry(
      id: 'entry-1',
      businessId: 'business-1',
      sessionId: 'session-1',
      entryType: TimeEntryType.active,
      startedAt: DateTime.utc(2026, 7, 17, 12),
      endedAt: null,
      createdAt: DateTime.utc(2026, 7, 17, 12),
    ),
  ],
  serverAnchor: DateTime.utc(2026, 7, 17, 12, 10),
  clock: FakeMonotonicClock(),
  clockAnchor: Duration.zero,
);

Session _session({
  required SessionStatus status,
  int? chargedMinutes,
  int? serviceSubtotalMinor,
  int? productsSubtotalMinor,
  int? grandTotalMinor,
  DateTime? endedAt,
}) => Session(
  id: 'session-1',
  businessId: 'business-1',
  customerId: null,
  serviceId: 'service-1',
  openedByMemberId: 'member-1',
  closedByMemberId: null,
  status: status,
  startedAt: DateTime.utc(2026, 7, 17, 12),
  endedAt: endedAt,
  chargedMinutes: chargedMinutes,
  serviceNameSnapshot: 'Koltuk',
  pricePerMinuteMinorSnapshot: 250,
  roundingIntervalMinutesSnapshot: 15,
  minimumChargeMinutesSnapshot: 10,
  currencyCodeSnapshot: 'TRY',
  serviceSubtotalMinor: serviceSubtotalMinor,
  productsSubtotalMinor: productsSubtotalMinor,
  discountMinor: 0,
  taxMinor: 0,
  grandTotalMinor: grandTotalMinor,
  notes: null,
  createdAt: DateTime.utc(2026, 7, 17, 12),
  updatedAt: DateTime.utc(2026, 7, 17, 12),
);

class _CompletingSessionActionsController extends SessionActionsController {
  var completeCalls = 0;

  @override
  Future<void> build() async {}

  @override
  Future<bool> complete({
    required String sessionId,
    int discountMinor = 0,
    int taxMinor = 0,
  }) async {
    completeCalls++;
    return true;
  }
}
