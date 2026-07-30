import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:suretakip/app/providers/app_providers.dart';
import 'package:suretakip/app/providers/sync_providers.dart';
import 'package:suretakip/core/constants/app_constants.dart';
import 'package:suretakip/core/domain/domain_enums.dart';
import 'package:suretakip/core/errors/domain_exception.dart';
import 'package:suretakip/core/utils/business_date_ranges.dart';
import 'package:suretakip/features/customers/data/local/local_customer_mappers.dart';
import 'package:suretakip/features/customers/domain/entities/customer.dart';
import 'package:suretakip/features/payments/domain/entities/payment.dart';
import 'package:suretakip/features/payments/presentation/controllers/payments_controller.dart';
import 'package:suretakip/features/services/domain/entities/service.dart';
import 'package:suretakip/features/sessions/data/local/local_session_mappers.dart';
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
    required this.paymentStatuses,
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
  final Map<String, SessionPaymentStatus> paymentStatuses;

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
  var _datesUserSelected = false;
  String? _customerId;
  String? _serviceId;
  var _status = HistoryStatusFilter.all;
  List<Customer>? _customers;
  List<Service>? _services;
  Map<String, SessionPaymentStatus> _paymentStatuses = const {};
  late BusinessScope _scope;
  Future<void>? _refreshInFlight;
  var _isDisposed = false;
  var _didScheduleInitialRefresh = false;
  var _filterVersion = 0;
  var _refreshPending = false;
  var _surfaceRefreshErrors = false;

  @override
  Future<HistoryState> build(BusinessScope scope) {
    _scope = scope;
    ref.onDispose(() => _isDisposed = true);
    listenSelf((_, next) {
      if (!_didScheduleInitialRefresh && next.hasValue) {
        _didScheduleInitialRefresh = true;
        _scheduleServerRefresh();
      }
    });
    return _loadLocal();
  }

  Future<void> refresh() => _refreshFromServer(surfaceErrors: true);

  Future<void> setDates(DateTime firstDate, DateTime lastDate) async {
    _firstDate = firstDate;
    _lastDate = lastDate;
    _datesUserSelected = true;
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
    // Aktif/uçan sunucu yenilemesi artık güncel olmayan bir filtreye ait;
    // versiyonu ilerlet ki sonucu uygularken tespit edip atabilelim.
    _filterVersion++;
    state = const AsyncLoading<HistoryState>().copyWithPrevious(state);
    state = await AsyncValue.guard(_loadLocal);
    _scheduleServerRefresh();
  }

  Future<HistoryState> _loadLocal() async {
    final businessId = _scope.businessId;
    final business = ref.read(activeBusinessProvider);
    if (businessId == null || business == null || business.id != businessId) {
      return _emptyState();
    }
    _serverLocalDate ??= BusinessDateRanges.localDate(
      instant: DateTime.now().toUtc(),
      timezone: business.timezone,
    );
    _initializeDates();
    final range = _selectedRange(business.timezone);
    final (rows, customerRows, services) = await (
      ref.read(sessionsLocalDataSourceProvider).getSessions(businessId),
      ref
          .read(customersLocalDataSourceProvider)
          .getCustomers(businessId: businessId, includeInactive: true),
      ref
          .read(servicesLocalDataSourceProvider)
          .getServices(businessId: businessId, includeInactive: true),
    ).wait;
    final statuses = _selectedStatuses();
    final sessions = rows
        .map(mapLocalSessionToDomain)
        .where(
          (session) =>
              statuses.contains(session.status) &&
              session.endedAt != null &&
              range.contains(session.endedAt!) &&
              (_customerId == null || session.customerId == _customerId) &&
              (_serviceId == null || session.serviceId == _serviceId),
        )
        .toList(growable: false);
    final visibleIds = sessions.map((session) => session.id).toSet();
    return HistoryState(
      sessions: sessions,
      customers: customerRows
          .map(mapLocalCustomerToDomain)
          .toList(growable: false),
      services: services,
      firstDate: _firstDate!,
      lastDate: _lastDate!,
      customerId: _customerId,
      serviceId: _serviceId,
      status: _status,
      serverLocalDate: _serverLocalDate!,
      paymentStatuses: {
        for (final entry in _paymentStatuses.entries)
          if (visibleIds.contains(entry.key)) entry.key: entry.value,
      },
    );
  }

  void _scheduleServerRefresh() {
    unawaited(_refreshFromServer());
  }

  Future<void> _refreshFromServer({bool surfaceErrors = false}) {
    if (surfaceErrors) _surfaceRefreshErrors = true;
    final inFlight = _refreshInFlight;
    if (inFlight != null) {
      // Filtre değişmiş olabilir; mevcut istek bitince güncel filtreyle
      // yeniden dene (eski sonucun yeni state'i ezmesini _runServerRefresh
      // içindeki filtre-versiyon kontrolü zaten engeller).
      _refreshPending = true;
      return inFlight;
    }
    final future = _runServerRefresh();
    _refreshInFlight = future.whenComplete(() {
      _refreshInFlight = null;
      _surfaceRefreshErrors = false;
      if (_refreshPending) {
        _refreshPending = false;
        _scheduleServerRefresh();
      }
    });
    return _refreshInFlight!;
  }

  Future<void> _runServerRefresh() async {
    if (_isDisposed) return;
    final requestedFilterVersion = _filterVersion;
    try {
      final remote = await _loadRemote();
      if (_isDisposed) return;
      if (requestedFilterVersion != _filterVersion) {
        // Bu istek uçarken filtre değişti; sonuç artık geçerli değil.
        // Uygulama yerine güncel filtre için yeniden yenileme tetiklenir.
        _refreshPending = true;
        return;
      }
      state = AsyncData(remote);
    } catch (error, stack) {
      // Ağ/sunucu yenilemesi yerel geçmişi varsayılan olarak hata ekranına
      // çevirmemeli, ancak kullanıcı elle yenile'ye bastığında ağ-dışı
      // (ör. kimlik doğrulama/5xx) hatalar sessizce yutulmamalı.
      if (_isDisposed) return;
      ref
          .read(appLoggerProvider)
          .warn(error, stackTrace: stack, context: 'HistoryBackgroundRefresh');
      if (_surfaceRefreshErrors && !_isNetworkFailure(error)) {
        state = AsyncError<HistoryState>(error, stack).copyWithPrevious(state);
        rethrow;
      }
    }
  }

  bool _isNetworkFailure(Object error) =>
      error is NetworkException ||
      error is SocketException ||
      error is TimeoutException ||
      error is HandshakeException;

  Future<HistoryState> _loadRemote() async {
    final businessId = _scope.businessId;
    final business = ref.read(activeBusinessProvider);
    if (businessId == null || business == null || business.id != businessId) {
      return _emptyState();
    }
    final repository = ref.read(sessionsRepositoryProvider);
    final paymentsRepository = ref.read(paymentsRepositoryProvider);
    final serverNow = await repository.serverNow();
    _serverLocalDate = BusinessDateRanges.localDate(
      instant: serverNow,
      timezone: business.timezone,
    );
    if (_datesUserSelected) {
      _initializeDates();
    } else {
      _firstDate = DateTime(_serverLocalDate!.year, _serverLocalDate!.month);
      _lastDate = _serverLocalDate;
    }
    final range = _selectedRange(business.timezone);
    final optionsFuture = _loadOptions(business.id);
    final sessions = await repository.getSessionHistory(
      businessId: business.id,
      filter: SessionHistoryFilter(
        endedAtOrAfter: range.start,
        endedBefore: range.endExclusive,
        customerId: _customerId,
        serviceId: _serviceId,
        statuses: _selectedStatuses(),
      ),
    );
    final completedSessionIds = sessions
        .where((session) => session.status == SessionStatus.completed)
        .map((session) => session.id)
        .toList(growable: false);
    final paymentSummaries = await paymentsRepository.getSessionsPaymentStatus(
      completedSessionIds,
    );
    _paymentStatuses = {
      for (final summary in paymentSummaries)
        summary.sessionId: summary.paymentStatus,
    };
    await optionsFuture;
    await ref
        .read(sessionsLocalDataSourceProvider)
        .reconcileServerSessions(
          sessions: sessions,
          timeEntriesBySession: const {},
        );
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
      paymentStatuses: _paymentStatuses,
    );
  }

  void _initializeDates() {
    _firstDate ??= DateTime(_serverLocalDate!.year, _serverLocalDate!.month);
    _lastDate ??= _serverLocalDate;
  }

  UtcDateRange _selectedRange(String timezone) => BusinessDateRanges.localDates(
    firstDate: _firstDate!,
    lastDate: _lastDate!,
    timezone: timezone,
  );

  List<SessionStatus> _selectedStatuses() => switch (_status) {
    HistoryStatusFilter.all => const [
      SessionStatus.completed,
      SessionStatus.cancelled,
    ],
    HistoryStatusFilter.completed => const [SessionStatus.completed],
    HistoryStatusFilter.cancelled => const [SessionStatus.cancelled],
  };

  HistoryState _emptyState() {
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
      paymentStatuses: const {},
    );
  }

  Future<void> _loadOptions(String businessId) async {
    if (_customers != null && _services != null) return;
    final (customers, services) = await (
      ref
          .read(customersRepositoryProvider)
          .getCustomers(businessId: businessId, includeInactive: true),
      ref
          .read(servicesRepositoryProvider)
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
