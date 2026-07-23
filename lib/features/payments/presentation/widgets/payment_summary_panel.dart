import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:suretakip/core/errors/domain_exception.dart';
import 'package:suretakip/core/utils/form_validators.dart';
import 'package:suretakip/core/value_objects/money.dart';
import 'package:suretakip/features/payments/domain/entities/payment.dart';
import 'package:suretakip/features/payments/domain/entities/session_payment_summary.dart';
import 'package:suretakip/features/payments/presentation/controllers/payments_controller.dart';
import 'package:suretakip/features/payments/presentation/utils/payment_presentation_utils.dart';
import 'package:suretakip/features/payments/presentation/widgets/payment_status_badge.dart';
import 'package:suretakip/features/sessions/presentation/utils/session_presentation_utils.dart';

class PaymentSummaryPanel extends ConsumerWidget {
  const PaymentSummaryPanel({
    required this.sessionId,
    required this.canManage,
    required this.onCollect,
    super.key,
  });

  final String sessionId;
  final bool canManage;
  final VoidCallback onCollect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = sessionPaymentControllerProvider(sessionId);
    final state = ref.watch(provider);
    final summary =
        state.valueOrNull ?? ref.read(provider.notifier).currentSummary;
    if (summary == null && state.isLoading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator.adaptive()),
        ),
      );
    }
    if (summary == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Text('Ödeme bilgileri yüklenemedi.'),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => ref.read(provider.notifier).refresh(),
                child: const Text('Tekrar Dene'),
              ),
            ],
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PaymentTotals(summary: summary),
        const SizedBox(height: 12),
        if (summary.remaining.minorUnits > 0)
          FilledButton.icon(
            onPressed: state.isLoading ? null : onCollect,
            icon: const Icon(Icons.add_card_rounded),
            label: const Text('Ödeme Al'),
          ),
        const SizedBox(height: 16),
        Text(
          'Ödeme geçmişi',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        if (summary.payments.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text('Henüz tahsilat veya iade kaydı yok.'),
            ),
          )
        else
          for (final payment in summary.payments)
            _PaymentHistoryCard(
              payment: payment,
              canManage: canManage,
              busy: state.isLoading,
              refundableMinor: _refundableMinor(summary, payment),
              onVoid: () => _void(context, ref, payment),
              onRefund: () => _refund(
                context,
                ref,
                payment,
                _refundableMinor(summary, payment),
              ),
            ),
      ],
    );
  }

  int _refundableMinor(SessionPaymentSummary summary, Payment payment) {
    if (payment.kind != PaymentKind.collection ||
        payment.status != PaymentRecordStatus.completed) {
      return 0;
    }
    final refunded = summary.payments
        .where(
          (entry) =>
              entry.kind == PaymentKind.refund &&
              entry.status == PaymentRecordStatus.completed &&
              entry.originalPaymentId == payment.id,
        )
        .fold<int>(0, (total, entry) => total + entry.amountMinor);
    final remaining = payment.amountMinor - refunded;
    return remaining < 0 ? 0 : remaining;
  }

  Future<void> _void(
    BuildContext context,
    WidgetRef ref,
    Payment payment,
  ) async {
    final reason = await _ReasonDialog.show(
      context,
      title: 'Tahsilatı iptal et',
      actionLabel: 'İptal Et',
    );
    if (reason == null || !context.mounted) return;
    final result = await ref
        .read(sessionPaymentControllerProvider(sessionId).notifier)
        .voidPayment(paymentId: payment.id, reason: reason);
    if (!context.mounted) return;
    _showMutationMessage(
      context,
      result == null ? null : 'Tahsilat iptal edildi.',
      ref.read(sessionPaymentControllerProvider(sessionId)).error,
    );
  }

  Future<void> _refund(
    BuildContext context,
    WidgetRef ref,
    Payment payment,
    int refundableMinor,
  ) async {
    final request = await _RefundDialog.show(
      context,
      currencyCode: payment.currencyCode,
      refundableMinor: refundableMinor,
    );
    if (request == null || !context.mounted) return;
    final result = await ref
        .read(sessionPaymentControllerProvider(sessionId).notifier)
        .refundPayment(
          paymentId: payment.id,
          amount: Money(
            minorUnits: request.amountMinor,
            currencyCode: payment.currencyCode,
          ),
          reason: request.reason,
        );
    if (!context.mounted) return;
    _showMutationMessage(
      context,
      result == null
          ? null
          : (result.replayed
                ? 'Bu iade zaten kaydedilmişti.'
                : 'İade kaydedildi.'),
      ref.read(sessionPaymentControllerProvider(sessionId)).error,
    );
  }

  void _showMutationMessage(
    BuildContext context,
    String? success,
    Object? error,
  ) {
    final message =
        success ??
        (error is DomainException
            ? error.message
            : 'Ödeme işlemi tamamlanamadı.');
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _PaymentTotals extends StatelessWidget {
  const _PaymentTotals({required this.summary});

  final SessionPaymentSummary summary;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: PaymentStatusBadge(status: summary.paymentStatus),
          ),
          const SizedBox(height: 12),
          _AmountRow(label: 'Satış toplamı', money: summary.sessionTotal),
          const Divider(height: 20),
          _AmountRow(label: 'Tahsil edilen', money: summary.collected),
          const Divider(height: 20),
          _AmountRow(label: 'İade edilen', money: summary.refunded),
          const Divider(height: 20),
          _AmountRow(
            label: 'Kalan',
            money: summary.remaining,
            emphasized: true,
          ),
        ],
      ),
    ),
  );
}

class _AmountRow extends StatelessWidget {
  const _AmountRow({
    required this.label,
    required this.money,
    this.emphasized = false,
  });

  final String label;
  final Money money;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Tüm para değerleri tek dil: tabular figürler + vurgulu "Kalan" navy
    // (Numbers-Are-Navy + Tabular-Figures kuralı, _PriceRow ile aynı).
    final valueStyle = emphasized
        ? theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w800,
            fontFeatures: const [FontFeature.tabularFigures()],
          )
        : theme.textTheme.titleMedium?.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          );
    return MergeSemantics(
      child: Row(
        children: [
          Expanded(child: Text(label)),
          const SizedBox(width: 12),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                formatSessionMoney(money.minorUnits, money.currencyCode),
                style: valueStyle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentHistoryCard extends StatelessWidget {
  const _PaymentHistoryCard({
    required this.payment,
    required this.canManage,
    required this.busy,
    required this.refundableMinor,
    required this.onVoid,
    required this.onRefund,
  });

  final Payment payment;
  final bool canManage;
  final bool busy;
  final int refundableMinor;
  final VoidCallback onVoid;
  final VoidCallback onRefund;

  @override
  Widget build(BuildContext context) {
    final isRefund = payment.kind == PaymentKind.refund;
    final isVoided = payment.status == PaymentRecordStatus.voided;
    final canAct = canManage && !busy && !isRefund && !isVoided;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(isRefund ? Icons.undo_rounded : Icons.payments_rounded),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isRefund
                            ? 'İade · ${paymentMethodLabel(payment.method)}'
                            : paymentMethodLabel(payment.method),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${DateFormat('dd.MM.yyyy HH:mm').format(payment.receivedAt.toLocal())} · ${payment.receivedByMe ? 'Sen' : 'Ekip üyesi'}',
                      ),
                    ],
                  ),
                ),
                Text(
                  '${isRefund ? '−' : ''}${formatSessionMoney(payment.amountMinor, payment.currencyCode)}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            if (isVoided) ...[
              const SizedBox(height: 8),
              Text(
                'İptal edildi${payment.voidReason == null ? '' : ': ${payment.voidReason}'}',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            if (canAct) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  TextButton.icon(
                    key: ValueKey('void-payment-${payment.id}'),
                    onPressed: onVoid,
                    icon: const Icon(Icons.block_rounded),
                    label: const Text('İptal et'),
                  ),
                  if (refundableMinor > 0)
                    TextButton.icon(
                      key: ValueKey('refund-payment-${payment.id}'),
                      onPressed: onRefund,
                      icon: const Icon(Icons.undo_rounded),
                      label: const Text('İade et'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog({required this.title, required this.actionLabel});

  final String title;
  final String actionLabel;

  static Future<String?> show(
    BuildContext context, {
    required String title,
    required String actionLabel,
  }) => showDialog<String>(
    context: context,
    builder: (_) => _ReasonDialog(title: title, actionLabel: actionLabel),
  );

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final _key = GlobalKey<FormState>();
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: Form(
      key: _key,
      child: TextFormField(
        controller: _controller,
        autofocus: true,
        maxLines: 3,
        decoration: const InputDecoration(labelText: 'Gerekçe'),
        validator: (value) =>
            (value?.trim().isEmpty ?? true) ? 'Gerekçe zorunlu.' : null,
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Vazgeç'),
      ),
      FilledButton(
        onPressed: () {
          if (!(_key.currentState?.validate() ?? false)) return;
          Navigator.pop(context, _controller.text.trim());
        },
        child: Text(widget.actionLabel),
      ),
    ],
  );
}

typedef _RefundRequest = ({int amountMinor, String reason});

class _RefundDialog extends StatefulWidget {
  const _RefundDialog({
    required this.currencyCode,
    required this.refundableMinor,
  });

  final String currencyCode;
  final int refundableMinor;

  static Future<_RefundRequest?> show(
    BuildContext context, {
    required String currencyCode,
    required int refundableMinor,
  }) => showDialog<_RefundRequest>(
    context: context,
    builder: (_) => _RefundDialog(
      currencyCode: currencyCode,
      refundableMinor: refundableMinor,
    ),
  );

  @override
  State<_RefundDialog> createState() => _RefundDialogState();
}

class _RefundDialogState extends State<_RefundDialog> {
  final _key = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  final _reasonController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: minorUnitsToPaymentInput(widget.refundableMinor),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Tahsilatı iade et'),
    content: Form(
      key: _key,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'İade tutarı',
              suffixText: widget.currencyCode,
            ),
            validator: (value) {
              final basic = FormValidators.positiveMoney(value, 'iade tutarı');
              if (basic != null) return basic;
              if (FormValidators.moneyToMinor(value!) >
                  widget.refundableMinor) {
                return 'Tutar iade edilebilir bakiyeyi aşamaz.';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _reasonController,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Gerekçe'),
            validator: (value) =>
                (value?.trim().isEmpty ?? true) ? 'Gerekçe zorunlu.' : null,
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Vazgeç'),
      ),
      FilledButton(
        onPressed: () {
          if (!(_key.currentState?.validate() ?? false)) return;
          Navigator.pop(context, (
            amountMinor: FormValidators.moneyToMinor(_amountController.text),
            reason: _reasonController.text.trim(),
          ));
        },
        child: const Text('İade Et'),
      ),
    ],
  );
}
