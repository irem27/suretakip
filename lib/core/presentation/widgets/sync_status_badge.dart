import 'package:flutter/material.dart';
import 'package:suretakip/core/sync/models/sync_enums.dart';

/// Bir kaydın senkronizasyon durumunu kullanıcı diliyle gösteren küçük rozet
/// (Bölüm 25 sade durum tablosu).
class SyncStatusBadge extends StatelessWidget {
  const SyncStatusBadge({required this.status, super.key});

  final SyncStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (String label, Color fg, Color bg, IconData icon) = switch (status) {
      SyncStatus.synced => (
        'Senkronize edildi',
        colors.primary,
        colors.primaryContainer,
        Icons.cloud_done_outlined,
      ),
      SyncStatus.conflicted => (
        'Çakışma',
        colors.onErrorContainer,
        colors.errorContainer,
        Icons.error_outline,
      ),
      SyncStatus.rejected => (
        'Aktarılamadı',
        colors.onErrorContainer,
        colors.errorContainer,
        Icons.sync_problem_outlined,
      ),
      SyncStatus.localOnly ||
      SyncStatus.pending ||
      SyncStatus.processing ||
      SyncStatus.retrying => (
        'Bu cihaza kaydedildi',
        colors.onTertiaryContainer,
        colors.tertiaryContainer,
        Icons.cloud_upload_outlined,
      ),
    };

    return Semantics(
      label: 'Senkronizasyon durumu: $label',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: fg),
            const SizedBox(width: 4),
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: fg),
            ),
          ],
        ),
      ),
    );
  }
}
