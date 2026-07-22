import 'package:suretakip/core/database/app_database.dart';
import 'package:suretakip/core/domain/domain_enums.dart';
import 'package:suretakip/features/sessions/domain/entities/session.dart';
import 'package:suretakip/features/sessions/domain/entities/session_time_entry.dart';

/// Drift satırını domain [Session]'a çevirir. Offline seansın finansal alanları
/// (charged/subtotal/grandTotal) tamamlamada hesaplandığından burada boştur.
Session mapLocalSessionToDomain(LocalSessionRow row) => Session(
  id: row.id,
  businessId: row.businessId,
  customerId: row.customerId,
  serviceId: row.serviceId,
  openedByMemberId: row.openedByMemberId,
  closedByMemberId: row.closedByMemberId,
  status: SessionStatus.values.byName(row.status),
  startedAt: row.startedAt,
  endedAt: row.endedAt,
  chargedMinutes: null,
  serviceNameSnapshot: row.serviceNameSnapshot,
  pricePerMinuteMinorSnapshot: row.pricePerMinuteMinorSnapshot,
  roundingIntervalMinutesSnapshot: row.roundingIntervalMinutesSnapshot,
  minimumChargeMinutesSnapshot: row.minimumChargeMinutesSnapshot,
  currencyCodeSnapshot: row.currencyCodeSnapshot,
  serviceSubtotalMinor: null,
  productsSubtotalMinor: null,
  discountMinor: 0,
  taxMinor: 0,
  grandTotalMinor: null,
  notes: row.notes,
  createdAt: row.createdAtLocal,
  updatedAt: row.updatedAtLocal,
);

SessionTimeEntry mapLocalTimeEntryToDomain(LocalSessionTimeEntryRow row) =>
    SessionTimeEntry(
      id: row.id,
      businessId: row.businessId,
      sessionId: row.sessionId,
      entryType: TimeEntryType.values.byName(row.entryType),
      startedAt: row.startedAt,
      endedAt: row.endedAt,
      createdAt: row.createdAtLocal,
    );
