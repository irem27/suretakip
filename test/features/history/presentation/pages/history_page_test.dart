import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suretakip/app/providers/app_providers.dart';
import 'package:suretakip/features/businesses/domain/entities/business.dart';
import 'package:suretakip/features/customers/domain/entities/customer.dart';
import 'package:suretakip/features/customers/domain/repositories/customers_repository.dart';
import 'package:suretakip/features/history/presentation/pages/history_page.dart';
import 'package:suretakip/features/services/domain/entities/service.dart';
import 'package:suretakip/features/services/domain/repositories/services_repository.dart';
import 'package:suretakip/features/sessions/domain/entities/session.dart';
import 'package:suretakip/features/sessions/domain/entities/session_history_filter.dart';
import 'package:suretakip/features/sessions/domain/repositories/sessions_repository.dart';

void main() {
  testWidgets('boş geçmiş kullanıcıyı filtreleri değiştirmeye yönlendirir', (
    tester,
  ) async {
    // Test sırasından bağımsız olarak standart widget-test görünümüyle başla.
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeBusinessProvider.overrideWithValue(_business()),
          sessionsRepositoryProvider.overrideWithValue(
            _FakeSessionsRepository(),
          ),
          customersRepositoryProvider.overrideWithValue(
            _FakeCustomersRepository(),
          ),
          servicesRepositoryProvider.overrideWithValue(
            _FakeServicesRepository(),
          ),
        ],
        child: const MaterialApp(home: HistoryPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Tarih aralığını veya filtreleri değiştirerek'),
      findsOneWidget,
    );
    expect(find.byTooltip('Geçmişi yenile'), findsOneWidget);
  });
}

class _FakeSessionsRepository implements SessionsRepository {
  @override
  Future<DateTime> serverNow() async => DateTime.utc(2026, 7, 18, 10);

  @override
  Future<List<Session>> getSessionHistory({
    required String businessId,
    required SessionHistoryFilter filter,
  }) async => [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeCustomersRepository implements CustomersRepository {
  @override
  Future<List<Customer>> getCustomers({
    required String businessId,
    bool includeInactive = false,
  }) async => [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeServicesRepository implements ServicesRepository {
  @override
  Future<List<Service>> getServices({
    required String businessId,
    bool includeInactive = false,
  }) async => [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

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
