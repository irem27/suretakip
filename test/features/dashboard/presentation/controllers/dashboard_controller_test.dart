import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suretakip/app/providers/app_providers.dart';
import 'package:suretakip/core/database/app_database.dart';
import 'package:suretakip/core/errors/domain_exception.dart';
import 'package:suretakip/core/value_objects/money.dart';
import 'package:suretakip/features/businesses/domain/entities/business.dart';
import 'package:suretakip/features/dashboard/domain/entities/dashboard_metrics.dart';
import 'package:suretakip/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:suretakip/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:suretakip/features/sessions/data/local/sessions_local_data_source.dart';

void main() {
  test('controller uzak metriği beklemeden yerel işlemleri özetler', () async {
    final db = AppDatabase.forExecutor(NativeDatabase.memory());
    addTearDown(db.close);
    await SessionsLocalDataSource(db).startSession(
      StartSessionLocally(
        sessionId: 'local-session',
        timeEntryId: 'entry-1',
        businessId: 'business-1',
        serviceId: 'service-1',
        openedByMemberId: 'member-1',
        serviceName: 'Bilardo',
        pricePerMinuteMinor: 200,
        roundingIntervalMinutes: 5,
        minimumChargeMinutes: 10,
        currencyCode: 'TRY',
        startedAt: DateTime.utc(2026, 7, 23),
        startedOffline: true,
      ),
    );
    final repository = _FakeDashboardRepository()
      ..completer = Completer<DashboardMetrics>();
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        activeBusinessProvider.overrideWithValue(_business()),
        dashboardRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    final metrics = await container
        .read(dashboardControllerProvider(_businessScope).future)
        .timeout(const Duration(milliseconds: 100));

    expect(metrics, isNotNull);
    expect(metrics!.activeSessionCount, 1);
    expect(metrics.todayRevenue, Money.zero('TRY'));
    repository.completer!.complete(_remoteMetrics());
    await Future<void>.delayed(Duration.zero);
  });

  test('sunucu yenilemesi çevrimdışı başarısız olunca hata yüzeye çıkar; '
      'önceki yerel değer korunur', () async {
    final db = AppDatabase.forExecutor(NativeDatabase.memory());
    addTearDown(db.close);
    await SessionsLocalDataSource(db).startSession(
      StartSessionLocally(
        sessionId: 'local-session',
        timeEntryId: 'entry-1',
        businessId: 'business-1',
        serviceId: 'service-1',
        openedByMemberId: 'member-1',
        serviceName: 'Bilardo',
        pricePerMinuteMinor: 200,
        roundingIntervalMinutes: 5,
        minimumChargeMinutes: 10,
        currencyCode: 'TRY',
        startedAt: DateTime.utc(2026, 7, 23),
        startedOffline: true,
      ),
    );
    final repository = _FakeDashboardRepository()
      ..networkError = const NetworkException(NetworkException.offlineMessage);
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        activeBusinessProvider.overrideWithValue(_business()),
        dashboardRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    // autoDispose provider'ı canlı tut ki arka plan yenilemesi (ve onun
    // ürettiği hata state'i) dispose ile iptal olmasın.
    final sub = container.listen(
      dashboardControllerProvider(_businessScope),
      (_, _) {},
    );
    addTearDown(sub.close);

    // İlk yerel özet ₺0 gelirle döner; ardından arka plan yenilemesi
    // (listenSelf ile tetiklenir) çevrimdışı hatasıyla başarısız olur.
    await container
        .read(dashboardControllerProvider(_businessScope).future)
        .timeout(const Duration(milliseconds: 100));
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final state = container.read(dashboardControllerProvider(_businessScope));
    expect(
      state.hasError,
      isTrue,
      reason: 'Çevrimdışı yenileme başarısızlığı yüzeye çıkmalı.',
    );
    // Önceki yerel değer korunur (copyWithPrevious) ki UI çökmesin.
    expect(state.valueOrNull?.activeSessionCount, 1);
  });

  test('aktif işletme yoksa repository çağrılmaz', () async {
    final repository = _FakeDashboardRepository();
    final container = ProviderContainer(
      overrides: [
        activeBusinessProvider.overrideWithValue(null),
        dashboardRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    final metrics = await container.read(
      dashboardControllerProvider(_emptyScope).future,
    );

    expect(metrics, isNull);
    expect(repository.businessId, isNull);
  });
}

const BusinessScope _businessScope = (businessId: 'business-1', generation: 0);
const BusinessScope _emptyScope = (businessId: null, generation: 0);

class _FakeDashboardRepository implements DashboardRepository {
  String? businessId;
  Completer<DashboardMetrics>? completer;
  NetworkException? networkError;

  @override
  Future<DashboardMetrics> getMetrics({required String businessId}) async {
    this.businessId = businessId;
    if (networkError != null) throw networkError!;
    return completer?.future ?? _remoteMetrics();
  }
}

DashboardMetrics _remoteMetrics() => DashboardMetrics(
  activeSessionCount: 2,
  todayCompletedCount: 3,
  todayRevenue: Money(minorUnits: 12500, currencyCode: 'TRY'),
);

Business _business() => Business(
  id: 'business-1',
  name: 'Test',
  currencyCode: 'TRY',
  timezone: 'Europe/Istanbul',
  isActive: true,
  archivedAt: null,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);
