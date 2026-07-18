import 'package:flutter/material.dart';
import 'package:suretakip/core/domain/domain_enums.dart';
import 'package:suretakip/features/sessions/presentation/utils/session_presentation_utils.dart';

class SessionStatusChip extends StatelessWidget {
  const SessionStatusChip({required this.status, super.key});

  final SessionStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (background, foreground) = switch (status) {
      SessionStatus.active => (
        colors.primaryContainer,
        colors.onPrimaryContainer,
      ),
      SessionStatus.paused => (
        colors.tertiaryContainer,
        colors.onTertiaryContainer,
      ),
      SessionStatus.completed => (
        colors.secondaryContainer,
        colors.onSecondaryContainer,
      ),
      SessionStatus.cancelled => (
        colors.errorContainer,
        colors.onErrorContainer,
      ),
      SessionStatus.draft => (
        colors.surfaceContainerHighest,
        colors.onSurfaceVariant,
      ),
    };
    return Semantics(
      label: 'İşlem durumu: ${sessionStatusLabel(status)}',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text(
            sessionStatusLabel(status),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
