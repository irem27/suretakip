import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:suretakip/app/router/app_routes.dart';
import 'package:suretakip/core/domain/domain_enums.dart';
import 'package:suretakip/core/errors/domain_exception.dart';
import 'package:suretakip/core/presentation/widgets/app_error_state.dart';
import 'package:suretakip/features/sessions/presentation/controllers/sessions_controllers.dart';
import 'package:suretakip/features/sessions/presentation/utils/session_presentation_utils.dart';
import 'package:suretakip/features/sessions/presentation/widgets/product_picker_sheet.dart';
import 'package:suretakip/features/sessions/presentation/widgets/session_status_chip.dart';

class SessionDetailPage extends ConsumerStatefulWidget {
  const SessionDetailPage({required this.sessionId, super.key});

  final String sessionId;

  @override
  ConsumerState<SessionDetailPage> createState() => _SessionDetailPageState();
}

class _SessionDetailPageState extends ConsumerState<SessionDetailPage> {
  late final Timer _timer;
  DateTime _visualNow = DateTime.now().toUtc();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      // Yalnızca AKTİF seansta tik at: duraklatılmış/tamamlanmış/iptal
      // durumunda süre donuk olduğundan saniyelik rebuild gereksiz.
      final status = ref
          .read(sessionDetailProvider(widget.sessionId))
          .valueOrNull
          ?.session
          .status;
      if (status != SessionStatus.active) return;
      setState(() => _visualNow = DateTime.now().toUtc());
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(sessionDetailProvider(widget.sessionId));
    final action = ref.watch(sessionActionsControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('İşlem Detayı')),
      body: SafeArea(
        child: detail.when(
          loading: () =>
              const Center(child: CircularProgressIndicator.adaptive()),
          error: (error, _) => AppErrorState(
            error: error,
            fallbackMessage: 'İşlem bilgileri yüklenemedi.',
            onRetry: () =>
                ref.invalidate(sessionDetailProvider(widget.sessionId)),
          ),
          data: (data) => _DetailContent(
            data: data,
            visualNow: _visualNow,
            loading: action.isLoading,
            onTogglePause: () => _togglePause(data.session.status),
            onAddProduct: () => showProductPickerSheet(
              context,
              sessionId: widget.sessionId,
              currencyCode: data.session.currencyCodeSnapshot,
            ),
            onComplete: () => _confirmComplete(data),
            onCancel: _confirmCancel,
          ),
        ),
      ),
    );
  }

  Future<void> _togglePause(SessionStatus status) async {
    final controller = ref.read(sessionActionsControllerProvider.notifier);
    final success = status == SessionStatus.active
        ? await controller.pause(widget.sessionId)
        : await controller.resume(widget.sessionId);
    if (!mounted || success) return;
    _showActionError('İşlem durumu değiştirilemedi.');
  }

  Future<void> _confirmComplete(SessionDetailState data) async {
    final quote = data.quoteAt(_visualNow);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('İşlemi tamamla'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ücretlendirilen süre: ${quote.chargedMinutes} dakika'),
            const SizedBox(height: 8),
            Text(
              'Canlı önizleme: ${formatSessionMoney(quote.grandTotal.minorUnits, quote.grandTotal.currencyCode)}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Kesin süre ve tutar sunucu tarafından atomik olarak hesaplanır.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Onayla ve Tamamla'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final success = await ref
        .read(sessionActionsControllerProvider.notifier)
        .complete(sessionId: widget.sessionId);
    if (!mounted) return;
    if (success) {
      context.goNamed(AppRouteNames.dashboard);
    } else {
      _showActionError('İşlem tamamlanamadı.');
    }
  }

  Future<void> _confirmCancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('İşlemi iptal et'),
        content: const Text(
          'Eklenen stoklu ürünler atomik olarak stoğa iade edilecek. Devam edilsin mi?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('İptal Et'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final success = await ref
        .read(sessionActionsControllerProvider.notifier)
        .cancel(widget.sessionId);
    if (!mounted) return;
    if (success) {
      context.goNamed(AppRouteNames.dashboard);
    } else {
      _showActionError('İşlem iptal edilemedi.');
    }
  }

  void _showActionError(String fallback) {
    final error = ref.read(sessionActionsControllerProvider).error;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error is DomainException ? error.message : fallback),
      ),
    );
  }
}

class _DetailContent extends StatelessWidget {
  const _DetailContent({
    required this.data,
    required this.visualNow,
    required this.loading,
    required this.onTogglePause,
    required this.onAddProduct,
    required this.onComplete,
    required this.onCancel,
  });

  final SessionDetailState data;
  final DateTime visualNow;
  final bool loading;
  final VoidCallback onTogglePause;
  final VoidCallback onAddProduct;
  final VoidCallback onComplete;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final session = data.session;
    final isOpen =
        session.status == SessionStatus.active ||
        session.status == SessionStatus.paused;
    final isCompleted = session.status == SessionStatus.completed;
    final hasFinalTotals = session.grandTotalMinor != null;
    // Açık seansta CANLI önizleme; tamamlanmışta DB'nin kesin tutarları.
    final quote = isOpen ? data.quoteAt(visualNow) : null;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 160),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.customerName ?? 'Misafir Müşteri',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(session.serviceNameSnapshot),
                ],
              ),
            ),
            SessionStatusChip(status: session.status),
          ],
        ),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Text(
                  isOpen
                      ? 'AKTİF SÜRE'
                      : (isCompleted ? 'ÜCRETLENDİRİLEN SÜRE' : 'İŞLEM DURUMU'),
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                if (isOpen)
                  Semantics(
                    liveRegion: true,
                    label:
                        'Aktif süre ${formatSessionDuration(quote!.activeDuration)}',
                    child: Text(
                      formatSessionDuration(quote.activeDuration),
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  )
                else
                  Text(
                    session.chargedMinutes != null
                        ? '${session.chargedMinutes} dakika'
                        : 'İptal edildi',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                const SizedBox(height: 8),
                Text(
                  isOpen
                      ? '${quote!.chargedMinutes} dakika ücret önizlemesi'
                      : (session.chargedMinutes != null
                            ? 'Kesinleşen ücretlendirme'
                            : 'Bu işlem iptal edildi'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (isOpen)
          _PriceCard(
            serviceMinor: quote!.serviceTotal.minorUnits,
            productsMinor: quote.productsTotal.minorUnits,
            discountMinor: session.discountMinor,
            taxMinor: session.taxMinor,
            grandMinor: quote.grandTotal.minorUnits,
            currency: session.currencyCodeSnapshot,
          )
        else if (hasFinalTotals)
          _PriceCard(
            serviceMinor: session.serviceSubtotalMinor ?? 0,
            productsMinor: session.productsSubtotalMinor ?? 0,
            discountMinor: session.discountMinor,
            taxMinor: session.taxMinor,
            grandMinor: session.grandTotalMinor ?? 0,
            currency: session.currencyCodeSnapshot,
          ),
        const SizedBox(height: 16),
        if (isOpen)
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: loading ? null : onTogglePause,
                icon: Icon(
                  session.status == SessionStatus.active
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                ),
                label: Text(
                  session.status == SessionStatus.active
                      ? 'Duraklat'
                      : 'Devam Et',
                ),
              ),
              OutlinedButton.icon(
                onPressed: loading ? null : onAddProduct,
                icon: const Icon(Icons.add_shopping_cart_rounded),
                label: const Text('Ürün Ekle'),
              ),
            ],
          ),
        const SizedBox(height: 24),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 4,
          children: [
            Text(
              'Eklenen Ürünler',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text('${data.items.length} satır'),
          ],
        ),
        const SizedBox(height: 8),
        if (data.items.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Bu işleme henüz ürün eklenmedi. Açık işlemlerde Ürün Ekle düğmesini kullanabilirsiniz.',
              ),
            ),
          )
        else
          for (final item in data.items)
            Card(
              child: ListTile(
                title: Text(item.productNameSnapshot),
                subtitle: Text('${item.quantity} adet'),
                trailing: Text(
                  formatSessionMoney(
                    item.lineTotalMinor,
                    item.currencyCodeSnapshot,
                  ),
                ),
              ),
            ),
        if (session.notes != null) ...[
          const SizedBox(height: 16),
          Text('Not', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(session.notes!),
        ],
        if (isOpen) ...[
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: loading ? null : onComplete,
            icon: const Icon(Icons.check_circle_outline_rounded),
            label: const Padding(
              padding: EdgeInsets.symmetric(vertical: 15),
              child: Text('İşlemi Tamamla'),
            ),
          ),
          TextButton.icon(
            onPressed: loading ? null : onCancel,
            icon: const Icon(Icons.cancel_outlined),
            label: const Text('İşlemi İptal Et'),
          ),
        ] else if (session.status == SessionStatus.completed) ...[
          const SizedBox(height: 24),
          TextButton.icon(
            onPressed: loading ? null : onCancel,
            icon: const Icon(Icons.cancel_outlined),
            label: const Text('Tamamlanan İşlemi İptal Et'),
          ),
        ],
      ],
    );
  }
}

class _PriceCard extends StatelessWidget {
  const _PriceCard({
    required this.serviceMinor,
    required this.productsMinor,
    required this.discountMinor,
    required this.taxMinor,
    required this.grandMinor,
    required this.currency,
  });

  final int serviceMinor;
  final int productsMinor;
  final int discountMinor;
  final int taxMinor;
  final int grandMinor;
  final String currency;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _PriceRow(
              label: 'Hizmet Bedeli',
              value: formatSessionMoney(serviceMinor, currency),
            ),
            const SizedBox(height: 10),
            _PriceRow(
              label: 'Ürünler',
              value: formatSessionMoney(productsMinor, currency),
            ),
            if (discountMinor > 0) ...[
              const SizedBox(height: 10),
              _PriceRow(
                label: 'İndirim',
                value: '-${formatSessionMoney(discountMinor, currency)}',
              ),
            ],
            if (taxMinor > 0) ...[
              const SizedBox(height: 10),
              _PriceRow(
                label: 'Vergi',
                value: formatSessionMoney(taxMinor, currency),
              ),
            ],
            const Divider(height: 24),
            _PriceRow(
              label: 'Genel Toplam',
              value: formatSessionMoney(grandMinor, currency),
              emphasized: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.spaceBetween,
    spacing: 12,
    runSpacing: 4,
    children: [
      Text(label),
      Text(
        value,
        style: emphasized
            ? Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)
            : Theme.of(context).textTheme.titleMedium,
      ),
    ],
  );
}
