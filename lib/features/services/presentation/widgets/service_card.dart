import 'package:flutter/material.dart';
import 'package:suretakip/features/services/domain/entities/service.dart';
import 'package:suretakip/features/services/presentation/utils/service_presentation_utils.dart';
import 'package:suretakip/features/services/presentation/widgets/service_status_chip.dart';

class ServiceCard extends StatelessWidget {
  const ServiceCard({
    required this.service,
    required this.onTap,
    required this.onStatusChanged,
    required this.isUpdating,
    super.key,
  });

  final Service service;
  final VoidCallback onTap;
  final ValueChanged<bool> onStatusChanged;
  final bool isUpdating;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Opacity(
      opacity: service.isActive ? 1 : 0.68,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.design_services_outlined,
                        color: colors.primary,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        service.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: ServiceStatusChip(isActive: service.isActive),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.055),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      Text(
                        'Ücret',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        formatMoneyPerMinute(
                          service.pricePerMinuteMinor,
                          service.currencyCode,
                        ),
                        textAlign: TextAlign.end,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: colors.primary,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    Text(
                      'Minimum süre',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    Text('${service.minimumChargeMinutes} dk.'),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _RoundingBadge(minutes: service.roundingIntervalMinutes),
                    Text(
                      service.isActive ? 'Aktif' : 'Pasif',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    // MergeSemantics şart: onsuz etiket ayrı bir düğümde kalır
                    // ve Switch'in kendi düğümü ADSIZ olur; ekran okuyucu
                    // yalnızca "anahtar" der, hangi hizmet olduğunu söylemez.
                    MergeSemantics(
                      child: Semantics(
                        label: '${service.name} aktif durumu',
                        toggled: service.isActive,
                        child: Switch.adaptive(
                          value: service.isActive,
                          onChanged: isUpdating ? null : onStatusChanged,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundingBadge extends StatelessWidget {
  const _RoundingBadge({required this.minutes});

  final int minutes;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.arrow_upward_rounded, size: 16),
        const SizedBox(width: 4),
        Text('$minutes dk. yukarı yuvarla'),
      ],
    ),
  );
}
