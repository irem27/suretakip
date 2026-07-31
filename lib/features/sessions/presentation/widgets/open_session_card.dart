import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:suretakip/app/router/app_routes.dart';
import 'package:suretakip/core/utils/business_date_ranges.dart';
import 'package:suretakip/features/sessions/domain/entities/session.dart';
import 'package:suretakip/features/sessions/presentation/widgets/session_status_chip.dart';

/// Açık bir işlemi özetleyen kart. Ana Sayfa ve İşlemler sekmesi aynı kartı
/// kullanır; müşteri adı çağıran taraftan gelir çünkü [Session] yalnızca
/// `customerId` tutar ve ad tek sorguda toplu çözülür (kart başına sorgu yok).
class OpenSessionCard extends StatelessWidget {
  const OpenSessionCard({
    required this.session,
    required this.customerName,
    required this.businessTimezone,
    super.key,
  });

  final Session session;

  /// Kayıtlı müşteri yoksa null; bu durumda misafir etiketi gösterilir.
  final String? customerName;

  final String businessTimezone;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: ListTile(
      minTileHeight: 76,
      leading: const Icon(Icons.timer_outlined),
      title: Text(customerName ?? 'Misafir müşteri'),
      subtitle: Text(
        'Başlangıç: ${formatBusinessDateTime(session.startedAt, businessTimezone)}',
      ),
      trailing: SessionStatusChip(status: session.status),
      onTap: () => context.pushNamed(
        AppRouteNames.sessionDetail,
        pathParameters: {'sessionId': session.id},
      ),
    ),
  );
}

/// İşletme saat dilimine göre `gg.aa.yyyy ss:dd` biçimi.
String formatBusinessDateTime(DateTime instant, String timezone) {
  final date = BusinessDateRanges.localDateTime(
    instant: instant,
    timezone: timezone,
  );
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$day.$month.${date.year} $hour:$minute';
}
