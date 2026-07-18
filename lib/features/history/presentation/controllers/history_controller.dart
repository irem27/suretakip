import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:suretakip/app/providers/app_providers.dart';
import 'package:suretakip/core/constants/app_constants.dart';
import 'package:suretakip/core/domain/domain_enums.dart';
import 'package:suretakip/core/utils/business_date_ranges.dart';
import 'package:suretakip/features/customers/domain/entities/customer.dart';
import 'package:suretakip/features/services/domain/entities/service.dart';
import 'package:suretakip/features/sessions/domain/entities/session.dart';
import 'package:suretakip/features/sessions/domain/entities/session_history_filter.dart';

enum HistoryStatusFilter { all, completed, cancelled }

final class HistoryState {
  const HistoryState({
    required this.sessions,
    required this.customers,
    required this.services,
    required this.firstDate,
    required this.lastDate,
    required this.customerId,
    required this.serviceId,
    required this.status,
    required this.serverLocalDate,
  });

  final List<Session> sessions;
  final List<Customer> customers;
  final List<Service> services;
  final DateTime firstDate;
  final DateTime lastDate;
  final String? customerId;
  final String? serviceId;
  final HistoryStatusFilter status;
  final DateTime serverLocalDate;

  String customerName(String? id) {
    if (id == null) return 'Misafir Müşteri';
    for (final customer in customers) {
      if (customer.id == id) return customer.name;
    }
    return 'Bilinmeyen Müşteri';
  }
}

class HistoryController
    extends AutoDisposeFamilyAsyncNotifier<HistoryState, BusinessScope> {
  DateTime? _firstDate;
  DateTime? _lastDate;
  DateTime? _serverLocalDate;
  String? _customerId;
  String? _serviceId;
  var _status = HistoryStatusFilter.all;
  List<Customer>? _customers;
  List<Service>? _services;
  late BusinessScope _scope;

  @override
  Future<HistoryState> build(BusinessScope scope) {
    _scope = scope;
    return _load();
  }

  Future<void> refresh() => _reload();

  Future<void> setDates(DateTime firstDate, DateTime lastDate) async {
    _firstDate = firstDate;
    _lastDate = lastDate;
    await _reload();
  }

  Future<void> setCustomer(String? customerId) async {
    _customerId = customerId;
    await _reload();
  }

  Future<void> setService(String? serviceId) async {
    _serviceId = serviceId;
    await _reload();
  }

  Future<void> setStatus(HistoryStatusFilter status) async {
    _status = status;
    await _reload();
  }

  Future<void> _reload() async {
    state = const AsyncLoading<HistoryState>().copyWithPrevious(state);
    state = await AsyncValue.guard(_load);
  }

  Future<HistoryState> _load() async {
    final businessId = _scope.businessId;
    final business = ref.read(activeBusinessProvider);
    if (businessId == null || business == null || business.id != businessId) {
      final now = DateTime(AppConstants.historyEarliestYear);
      return HistoryState(
        sessions: const [],
        customers: const [],
        services: const [],
        firstDate: now,
        lastDate: now,
        customerId: null,
        serviceId: null,
        status: _status,
        serverLocalDate: now,
      );
    }
    final repository = ref.watch(sessionsRepositoryProvider);
    final serverNow = await repository.serverNow();
    _serverLocalDate ??= BusinessDateRanges.localDate(
      instant: serverNow,
      timezone: business.timezone,
    );
    _firstDate ??= DateTime(_serverLocalDate!.year, _serverLocalDate!.month);
    _lastDate ??= _serverLocalDate;
    final range = BusinessDateRanges.localDates(
      firstDate: _firstDate!,
      lastDate: _lastDate!,
      timezone: business.timezone,
    );
    final optionsFuture = _loadOptions(business.id);
    final sessions = await repository.getSessionHistory(
      businessId: business.id,
      filter: SessionHistoryFilter(
        endedAtOrAfter: range.start,
        endedBefore: range.endExclusive,
        customerId: _customerId,
        serviceId: _serviceId,
        statuses: switch (_status) {
          HistoryStatusFilter.all => const [
            SessionStatus.completed,
            SessionStatus.cancelled,
          ],
          HistoryStatusFilter.completed => const [SessionStatus.completed],
          HistoryStatusFilter.cancelled => const [SessionStatus.cancelled],
        },
      ),
    );
    await optionsFuture;
    return HistoryState(
      sessions: sessions,
      customers: _customers ?? const [],
      services: _services ?? const [],
      firstDate: _firstDate!,
      lastDate: _lastDate!,
      customerId: _customerId,
      serviceId: _serviceId,
      status: _status,
      serverLocalDate: _serverLocalDate!,
    );
  }

  Future<void> _loadOptions(String businessId) async {
    if (_customers != null && _services != null) return;
    final (customers, services) = await (
      ref
          .watch(customersRepositoryProvider)
          .getCustomers(businessId: businessId, includeInactive: true),
      ref
          .watch(servicesRepositoryProvider)
          .getServices(businessId: businessId, includeInactive: true),
    ).wait;
    _customers = customers;
    _services = services;
  }
}

final historyControllerProvider = AsyncNotifierProvider.autoDispose
    .family<HistoryController, HistoryState, BusinessScope>(
      HistoryController.new,
    );
