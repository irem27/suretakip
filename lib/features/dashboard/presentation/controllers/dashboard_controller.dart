import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:suretakip/app/providers/app_providers.dart';
import 'package:suretakip/app/providers/sync_providers.dart';
import 'package:suretakip/core/domain/domain_enums.dart';
import 'package:suretakip/core/errors/domain_exception.dart';
import 'package:suretakip/core/utils/business_date_ranges.dart';
import 'package:suretakip/core/value_objects/money.dart';
import 'package:suretakip/features/dashboard/domain/entities/dashboard_metrics.dart';

class DashboardController
    extends AutoDisposeFamilyAsyncNotifier<DashboardMetrics?, BusinessScope> {
  var _isDisposed = false;
  var _didScheduleInitialRefresh = false;

  @override
  Future<DashboardMetrics?> build(BusinessScope scope) async {
    ref.onDispose(() => _isDisposed = true);
    listenSelf((_, next) {
      final businessId = scope.businessId;
      if (!_didScheduleInitialRefresh && next.hasValue && businessId != null) {
        _didScheduleInitialRefresh = true;
        unawaited(_refreshFromServer(businessId));
      }
    });
    final businessId = scope.businessId;
    final business = ref.read(activeBusinessProvider);
    if (businessId == null || business == null || business.id != businessId) {
      return null;
    }

    final rows = await ref
        .watch(sessionsLocalDataSourceProvider)
        .getSessions(businessId);
    final today = BusinessDateRanges.day(
      serverNow: DateTime.now().toUtc(),
      timezone: business.timezone,
    );
    final completedToday = rows.where(
      (row) =>
          row.status == SessionStatus.completed.name &&
          row.endedAt != null &&
          today.contains(row.endedAt!),
    );
    final localMetrics = DashboardMetrics(
      activeSessionCount: rows
          .where(
            (row) =>
                row.status == SessionStatus.active.name ||
                row.status == SessionStatus.paused.name,
          )
          .length,
      todayCompletedCount: completedToday.length,
      // Yerel şemada kesin finans toplamı bulunmayan eski kayıtlar için
      // uydurma gelir göstermeyiz. Sunucu yenilemesi gelince gerçek tutar
      // sessizce state'e uygulanır.
      todayRevenue: Money.zero(business.currencyCode),
    );

    return localMetrics;
  }

  Future<void> refresh() async {
    final businessId = arg.businessId;
    if (businessId == null) return;
    await _refreshFromServer(businessId);
  }

  Future<void> _refreshFromServer(String businessId) async {
    try {
      final metrics = await ref
          .read(dashboardRepositoryProvider)
          .getMetrics(businessId: businessId);
      if (!_isDisposed && arg.businessId == businessId) {
        state = AsyncData(metrics);
      }
    } on NetworkException catch (error, stack) {
      if (_isDisposed) return;
      ref
          .read(appLoggerProvider)
          .warn(
            error,
            stackTrace: stack,
            context: 'DashboardBackgroundRefresh',
          );
    } catch (error, stack) {
      if (!_isDisposed && arg.businessId == businessId) {
        state = AsyncError(error, stack);
      }
    }
  }
}

final dashboardControllerProvider = AsyncNotifierProvider.autoDispose
    .family<DashboardController, DashboardMetrics?, BusinessScope>(
      DashboardController.new,
    );
