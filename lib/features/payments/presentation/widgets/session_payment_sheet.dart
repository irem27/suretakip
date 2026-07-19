import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:suretakip/core/errors/domain_exception.dart';
import 'package:suretakip/core/utils/form_validators.dart';
import 'package:suretakip/core/value_objects/money.dart';
import 'package:suretakip/features/payments/domain/entities/payment.dart';
import 'package:suretakip/features/payments/domain/entities/session_payment_summary.dart';
import 'package:suretakip/features/payments/presentation/controllers/payments_controller.dart';
import 'package:suretakip/features/payments/presentation/utils/payment_presentation_utils.dart';
import 'package:suretakip/features/payments/presentation/widgets/payment_status_badge.dart';
import 'package:suretakip/features/sessions/presentation/utils/session_presentation_utils.dart';

Future<void> showSessionPaymentSheet(
  BuildContext context, {
  required String sessionId,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) => SessionPaymentSheet(sessionId: sessionId),
);

class SessionPaymentSheet extends ConsumerStatefulWidget {
  const SessionPaymentSheet({required this.sessionId, super.key});

  final String sessionId;

  @override
  ConsumerState<SessionPaymentSheet> createState() =>
      _SessionPaymentSheetState();
}

class _SessionPaymentSheetState extends ConsumerState<SessionPaymentSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  var _method = PaymentMethod.cash;
  var _submitting = false;
  var _retryPending = false;
  PaymentMethod? _retryMethod;
  int? _retryAmount;
  int? _lastRemaining;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = sessionPaymentControllerProvider(widget.sessionId);
    final paymentState = ref.watch(provider);
    final summary =
        paymentState.valueOrNull ?? ref.read(provider.notifier).currentSummary;
    if (summary != null &&
        summary.remaining.minorUnits != _lastRemaining &&
        !_submitting) {
      _lastRemaining = summary.remaining.minorUnits;
      _amountController.text = minorUnitsToPaymentInput(_lastRemaining!);
    }
    return FractionallySizedBox(
      heightFactor: 0.92,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Tahsilat',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _submitting ? null : () => Navigator.pop(context),
                  tooltip: 'Ödeme yapmadan kapat',
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          Expanded(
            child: switch (summary) {
              null when paymentState.isLoading => const Center(
                child: CircularProgressIndicator.adaptive(),
              ),
              null => _LoadError(
                onRetry: () => ref.read(provider.notifier).refresh(),
              ),
              final data => ListView(
                padding: EdgeInsets.fromLTRB(
                  20,
                  8,
                  20,
                  MediaQuery.viewInsetsOf(context).bottom + 24,
                ),
                children: [
                  _SummaryCard(summary: data),
                  if (paymentState.hasError) ...[
                    const SizedBox(height: 12),
                    _InlineError(error: paymentState.error),
                  ],
                  const SizedBox(height: 16),
                  if (data.remaining.minorUnits > 0)
                    _buildPaymentForm(data)
                  else
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Row(
                          children: [
                            Icon(Icons.verified_rounded),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text('Bu işlemin bakiyesi ödendi.'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _submitting
                        ? null
                        : () => Navigator.pop(context),
                    child: const Text('Şimdi ödeme almadan kapat'),
                  ),
                ],
              ),
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentForm(SessionPaymentSummary summary) => Form(
    key: _formKey,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Ödeme yöntemi',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<PaymentMethod>(
              initialValue: _method,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.payments_outlined),
              ),
              items: [
                for (final method in PaymentMethod.values)
                  DropdownMenuItem(
                    value: method,
                    child: Text(paymentMethodLabel(method)),
                  ),
              ],
              onChanged: _submitting
                  ? null
                  : (value) => setState(() {
                      _method = value ?? _method;
                      _retryPending = false;
                    }),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountController,
              enabled: !_submitting,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Tahsil edilecek tutar',
                suffixText: summary.currencyCode,
                helperText:
                    'Kısmi ödeme için kalan bakiyeden düşük girebilirsiniz.',
              ),
              validator: (value) {
                final basic = FormValidators.positiveMoney(value, 'tutar');
                if (basic != null) return basic;
                final amount = FormValidators.moneyToMinor(value!);
                if (amount > summary.remaining.minorUnits) {
                  return 'Tutar kalan bakiyeyi aşamaz.';
                }
                return null;
              },
              onChanged: (_) => _retryPending = false,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              key: const Key('payment-submit-button'),
              onPressed: _submitting ? null : () => _submit(summary),
              icon: _submitting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_card_rounded),
              label: Text(_submitting ? 'Kaydediliyor…' : 'Tahsilatı Kaydet'),
            ),
          ],
        ),
      ),
    ),
  );

  Future<void> _submit(SessionPaymentSummary summary) async {
    if (_submitting || !(_formKey.currentState?.validate() ?? false)) return;
    final amountMinor = FormValidators.moneyToMinor(_amountController.text);
    setState(() => _submitting = true);
    final controller = ref.read(
      sessionPaymentControllerProvider(widget.sessionId).notifier,
    );
    final isRetry =
        _retryPending && _retryMethod == _method && _retryAmount == amountMinor;
    final result = isRetry
        ? await controller.retryPayment()
        : await controller.recordPayment(
            method: _method,
            amount: Money(
              minorUnits: amountMinor,
              currencyCode: summary.currencyCode,
            ),
          );
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _retryPending = result == null;
      _retryMethod = _method;
      _retryAmount = amountMinor;
    });
    if (result == null) return;
    _retryPending = false;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.replayed
              ? 'Bu tahsilat zaten kaydedilmişti.'
              : 'Tahsilat kaydedildi.',
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary});

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
          _SheetAmountRow(label: 'Genel toplam', money: summary.sessionTotal),
          const Divider(height: 20),
          _SheetAmountRow(label: 'Tahsil edilen', money: summary.collected),
          const Divider(height: 20),
          _SheetAmountRow(label: 'İade edilen', money: summary.refunded),
          const Divider(height: 20),
          _SheetAmountRow(
            label: 'Kalan',
            money: summary.remaining,
            emphasized: true,
          ),
        ],
      ),
    ),
  );
}

class _SheetAmountRow extends StatelessWidget {
  const _SheetAmountRow({
    required this.label,
    required this.money,
    this.emphasized = false,
  });

  final String label;
  final Money money;
  final bool emphasized;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Text(label)),
      Text(
        formatSessionMoney(money.minorUnits, money.currencyCode),
        style: emphasized
            ? Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)
            : null,
      ),
    ],
  );
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.errorContainer,
    borderRadius: BorderRadius.circular(12),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Text(
        error is DomainException
            ? (error! as DomainException).message
            : 'Tahsilat kaydedilemedi. Aynı işlemi tekrar deneyebilirsiniz.',
      ),
    ),
  );
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Ödeme bilgileri yüklenemedi.'),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: onRetry, child: const Text('Tekrar Dene')),
      ],
    ),
  );
}
