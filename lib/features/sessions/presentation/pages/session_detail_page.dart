import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:suretakip/app/providers/app_providers.dart';
import 'package:suretakip/app/router/app_routes.dart';
import 'package:suretakip/core/domain/domain_enums.dart';
import 'package:suretakip/core/errors/domain_exception.dart';
import 'package:suretakip/core/presentation/widgets/app_back_button.dart';
import 'package:suretakip/core/presentation/widgets/app_error_state.dart';
import 'package:suretakip/features/payments/presentation/widgets/payment_summary_panel.dart';
import 'package:suretakip/features/payments/presentation/widgets/session_payment_sheet.dart';
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
      setState(() {});
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
    final canManagePayments =
        ref
            .watch(businessCapabilitiesProvider)
            .valueOrNull
            ?.canCancelCompletedSession ??
        false;
    // Birincil aksiyon (Tamamla/İptal) yoğun tezgahta kaydırma gerektirmemesi
    // için kalıcı alt barda tutulur; içerik yalnızca özet ve satırları taşır.
    final detailData = detail.valueOrNull;
    final status = detailData?.session.status;
    final isOpen =
        status == SessionStatus.active || status == SessionStatus.paused;
    return Scaffold(
      appBar: AppBar(
        title: const Text('İşlem Detayı'),
        leading: const AppBackButton(
          fallbackRouteName: AppRouteNames.dashboard,
        ),
        // Bir aksiyon sunucuda işlenirken (tamamla/iptal/duraklat) yalnızca
        // düğmeleri kapatmak yetmez; net bir "işleniyor" sinyali gösterilir.
        bottom: action.isLoading
            ? const PreferredSize(
                preferredSize: Size.fromHeight(4),
                child: LinearProgressIndicator(minHeight: 4),
              )
            : null,
      ),
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
            loading: action.isLoading,
            canManagePayments: canManagePayments,
            onTogglePause: () => _togglePause(data.session.status),
            onAddProduct: () => showProductPickerSheet(
              context,
              sessionId: widget.sessionId,
              currencyCode: data.session.currencyCodeSnapshot,
            ),
            onCollect: () =>
                showSessionPaymentSheet(context, sessionId: widget.sessionId),
            onCancel: _confirmCancel,
          ),
        ),
      ),
      bottomNavigationBar: (isOpen && detailData != null)
          ? _SessionCommitBar(
              loading: action.isLoading,
              onComplete: () => _confirmComplete(detailData),
              onCancel: _confirmCancel,
            )
          : null,
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
    final quote = data.quote;
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'İşlem tamamlandı. Kesin tutar eşitlenince tahsilat yapabilirsiniz.',
          ),
        ),
      );
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
      // Sessiz atılma yerine, sonuç dashboard'a dönmeden önce onaylanır.
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('İşlem iptal edildi.')));
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

/// Açık seansta ekranın altına sabitlenen birincil aksiyon barı. Operatör
/// ürün listesini kaydırmadan işlemi tek dokunuşla bitirebilir/iptal edebilir.
class _SessionCommitBar extends StatelessWidget {
  const _SessionCommitBar({
    required this.loading,
    required this.onComplete,
    required this.onCancel,
  });

  final bool loading;
  final VoidCallback onComplete;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: loading ? null : onComplete,
                  icon: loading
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_circle_outline_rounded),
                  label: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(loading ? 'İşleniyor…' : 'İşlemi Tamamla'),
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: loading ? null : onCancel,
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('İşlemi İptal Et'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailContent extends StatelessWidget {
  const _DetailContent({
    required this.data,
    required this.loading,
    required this.canManagePayments,
    required this.onTogglePause,
    required this.onAddProduct,
    required this.onCollect,
    required this.onCancel,
  });

  final SessionDetailState data;
  final bool loading;
  final bool canManagePayments;
  final VoidCallback onTogglePause;
  final VoidCallback onAddProduct;
  final VoidCallback onCollect;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final session = data.session;
    final isActive = session.status == SessionStatus.active;
    final isPaused = session.status == SessionStatus.paused;
    final isOpen = isActive || isPaused;
    final isCompleted = session.status == SessionStatus.completed;
    final isCancelled = session.status == SessionStatus.cancelled;
    final hasFinalTotals = session.grandTotalMinor != null;
    // Açık seansta CANLI önizleme; tamamlanmışta DB'nin kesin tutarları.
    final quote = isOpen ? data.quote : null;
    // Kesinleşmemiş, iptal de edilmemiş durumlar (ör. draft) yanlışlıkla
    // "İptal edildi" göstermemeli.
    final durationText = session.chargedMinutes != null
        ? '${session.chargedMinutes} dakika'
        : isCancelled
        ? 'İptal edildi'
        : isCompleted
        ? 'Tamamlandı'
        : 'Taslak işlem';
    final durationSubtitle = session.chargedMinutes != null
        ? 'Kesinleşen ücretlendirme'
        : isCancelled
        ? 'Bu işlem iptal edildi'
        : isCompleted
        ? 'Kesin tutar eşitleme bekliyor'
        : 'Henüz başlatılmadı';
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
                    style: theme.textTheme.headlineSmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    session.serviceNameSnapshot,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Başlangıç: '
                    '${DateFormat('dd.MM.yyyy HH:mm').format(session.startedAt.toLocal())}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            SessionStatusChip(status: session.status),
          ],
        ),
        const SizedBox(height: 24),
        // Aktif seansın görsel önceliği: yükseltilmiş kart (Level-2) + navy sayı.
        Card(
          elevation: isOpen ? 4 : 0,
          shadowColor: theme.colorScheme.primary.withValues(alpha: 0.25),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Text(
                  isActive
                      ? 'AKTİF SÜRE'
                      : isPaused
                      ? 'DURAKLATILDI'
                      : (isCompleted ? 'ÜCRETLENDİRİLEN SÜRE' : 'İŞLEM DURUMU'),
                  style: theme.textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                if (isOpen)
                  Semantics(
                    // Yalnızca aktif seansta canlı bölge; duraklatılmışta sayı
                    // donuktur ve navy "canlı" otoritesini talep etmemeli.
                    liveRegion: isActive,
                    label:
                        '${isActive ? 'Aktif süre' : 'Duraklatıldı'} '
                        '${formatSessionDuration(quote!.activeDuration)}',
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        formatSessionDuration(quote.activeDuration),
                        style: theme.textTheme.displayMedium?.copyWith(
                          color: isActive
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w800,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  )
                else if (session.chargedMinutes != null)
                  Semantics(
                    label: 'Ücretlendirilen süre $durationText',
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        durationText,
                        style: theme.textTheme.displaySmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w800,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  )
                else
                  // Sayısal olmayan terminal/nötr durum: bir cümleyi kahraman
                  // rakam yuvasına basmak yerine ikon + başlık.
                  Semantics(
                    label: durationText,
                    child: Column(
                      children: [
                        Icon(
                          isCancelled
                              ? Icons.cancel_outlined
                              : Icons.hourglass_empty_rounded,
                          size: 40,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          durationText,
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                if (isOpen) ...[
                  Text('${quote!.chargedMinutes} dakika ücret önizlemesi'),
                  const SizedBox(height: 4),
                  Text(
                    isActive
                        ? 'Süre sunucu saatinden hesaplanır; kesin tutar tamamlamada oluşur.'
                        : 'Duraklatıldı — süre işlemiyor. Devam Et ile sürdürün.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  // Canlı sayaç tek bir araç olarak okunsun: genel toplam
                  // ayrı bir karta değil, yükseltilmiş hero kartın içine.
                  const Divider(height: 24),
                  _PriceRow(
                    label: 'Genel Toplam',
                    value: formatSessionMoney(
                      quote.grandTotal.minorUnits,
                      session.currencyCodeSnapshot,
                    ),
                    emphasized: true,
                  ),
                ] else
                  Text(durationSubtitle),
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
            showGrandTotal: false,
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
        if (isCompleted && hasFinalTotals) ...[
          const SizedBox(height: 20),
          Text(
            'Ödeme',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          PaymentSummaryPanel(
            sessionId: session.id,
            canManage: canManagePayments,
            onCollect: onCollect,
          ),
        ],
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
            Text('Eklenen Ürünler', style: theme.textTheme.titleLarge),
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
                  style: const TextStyle(
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
        if (session.notes != null) ...[
          const SizedBox(height: 16),
          Text('Not', style: theme.textTheme.titleMedium),
          const SizedBox(height: 6),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(session.notes!),
            ),
          ),
        ],
        if (isCompleted) ...[
          const SizedBox(height: 24),
          TextButton.icon(
            onPressed: loading ? null : onCancel,
            icon: const Icon(Icons.cancel_outlined),
            label: const Text('Tamamlanan İşlemi İptal Et'),
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
            ),
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
    this.showGrandTotal = true,
  });

  final int serviceMinor;
  final int productsMinor;
  final int discountMinor;
  final int taxMinor;
  final int grandMinor;
  final String currency;

  /// Açık seansta genel toplam yükseltilmiş hero kartında gösterilir; burada
  /// yalnızca kalem dökümü kalır (tek sayaç kuralı, çift toplam olmaz).
  final bool showGrandTotal;

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
            if (showGrandTotal) ...[
              const Divider(height: 24),
              _PriceRow(
                label: 'Genel Toplam',
                value: formatSessionMoney(grandMinor, currency),
                emphasized: true,
              ),
            ],
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Sabit sütun + sağa hizalı tabular değer: satırlar arasında dikey
    // rakam karşılaştırması korunur (Right-Align + Tabular-Figures kuralı).
    final valueStyle =
        (emphasized
                ? theme.textTheme.titleLarge?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w800,
                  )
                : theme.textTheme.titleMedium)
            ?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
    return MergeSemantics(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: Text(label)),
          const SizedBox(width: 12),
          // Büyük yazı ölçeğinde uzun tutar satırı taşmasın.
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(value, textAlign: TextAlign.end, style: valueStyle),
            ),
          ),
        ],
      ),
    );
  }
}
