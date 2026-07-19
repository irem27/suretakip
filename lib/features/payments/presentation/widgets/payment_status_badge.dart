import 'package:flutter/material.dart';
import 'package:suretakip/features/payments/domain/entities/payment.dart';

class PaymentStatusBadge extends StatelessWidget {
  const PaymentStatusBadge({required this.status, super.key});

  final SessionPaymentStatus status;

  String get label => switch (status) {
    SessionPaymentStatus.unpaid => 'Ödenmedi',
    SessionPaymentStatus.partiallyPaid => 'Kısmi ödendi',
    SessionPaymentStatus.paid => 'Ödendi',
  };

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (background, foreground, icon) = switch (status) {
      SessionPaymentStatus.unpaid => (
        colors.errorContainer,
        colors.onErrorContainer,
        Icons.money_off_rounded,
      ),
      SessionPaymentStatus.partiallyPaid => (
        colors.tertiaryContainer,
        colors.onTertiaryContainer,
        Icons.timelapse_rounded,
      ),
      SessionPaymentStatus.paid => (
        colors.primaryContainer,
        colors.onPrimaryContainer,
        Icons.check_circle_rounded,
      ),
    };
    return Semantics(
      label: 'Ödeme durumu: $label',
      child: Chip(
        avatar: Icon(icon, size: 18, color: foreground),
        label: Text(label),
        backgroundColor: background,
        labelStyle: TextStyle(color: foreground, fontWeight: FontWeight.w700),
        side: BorderSide.none,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
