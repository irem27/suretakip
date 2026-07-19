import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:suretakip/app/providers/app_providers.dart';
import 'package:suretakip/app/router/app_routes.dart';
import 'package:suretakip/core/presentation/widgets/app_back_button.dart';
import 'package:suretakip/core/presentation/widgets/app_bottom_nav_bar.dart';
import 'package:suretakip/core/presentation/widgets/app_error_state.dart';
import 'package:suretakip/core/value_objects/money.dart';
import 'package:suretakip/features/reports/domain/entities/report_models.dart';
import 'package:suretakip/features/reports/presentation/controllers/reports_controller.dart';
import 'package:suretakip/features/sessions/presentation/utils/session_presentation_utils.dart';

class ReportsPage extends ConsumerWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scope = ref.watch(activeBusinessScopeProvider);
    final reportsProvider = reportsControllerProvider(scope);
    final reports = ref.watch(reportsProvider);
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(
          fallbackRouteName: AppRouteNames.dashboard,
        ),
        title: const Text('Raporlar'),
        actions: [
          IconButton(
            onPressed: () => ref.read(reportsProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Raporları yenile',
          ),
        ],
      ),
      bottomNavigationBar: const AppBottomNavBar(current: AppSection.reports),
      body: SafeArea(
        child: reports.when(
          loading: () =>
              const Center(child: CircularProgressIndicator.adaptive()),
          error: (error, _) => AppErrorState(
            error: error,
            fallbackMessage: 'Raporlar yüklenemedi.',
            onRetry: () => ref.read(reportsProvider.notifier).refresh(),
          ),
          data: (report) => report == null
              ? const _NoBusinessReport()
              : RefreshIndicator.adaptive(
                  onRefresh: () => ref.read(reportsProvider.notifier).refresh(),
                  child: _ReportContent(report: report),
                ),
        ),
      ),
    );
  }
}

class _ReportContent extends StatelessWidget {
  const _ReportContent({required this.report});

  final ReportOverview report;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Text(
        'Satış ve tahsilat özeti',
        style: Theme.of(
          context,
        ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 4),
      Text(
        'Kesinleşen satış müşteriye yazılan toplamı, net tahsilat ise gerçekten alınan parayı gösterir. İkisi aynı olmak zorunda değildir.',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: 16),
      LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 760 ? 3 : 1;
          final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: width,
                child: _RevenueCard(label: 'Bugün', summary: report.today),
              ),
              SizedBox(
                width: width,
                child: _RevenueCard(label: 'Bu hafta', summary: report.week),
              ),
              SizedBox(
                width: width,
                child: _RevenueCard(label: 'Bu ay', summary: report.month),
              ),
            ],
          );
        },
      ),
      const SizedBox(height: 20),
      _RevenueSplitCard(report: report),
      const SizedBox(height: 12),
      _CollectionBreakdownCard(collection: report.month.collection),
      const SizedBox(height: 20),
      _RankingCard(
        title: 'En çok kullanılan hizmetler',
        emptyMessage:
            'Bu ay tamamlanan hizmet yok. İşlemler tamamlandığında sıralama burada görünecek.',
        rankings: report.topServices,
        countSuffix: 'işlem',
      ),
      const SizedBox(height: 12),
      _RankingCard(
        title: 'En çok satılan ürünler',
        emptyMessage:
            'Bu ay ürün satışı yok. İşlemlere ürün eklendiğinde sıralama burada görünecek.',
        rankings: report.topProducts,
        countSuffix: 'adet',
      ),
      const SizedBox(height: 12),
      _RankingCard(
        title: 'En çok harcayan müşteriler',
        emptyMessage:
            'Bu ay kayıtlı müşteri harcaması yok. Kayıtlı müşteri işlemleri burada görünecek.',
        rankings: report.topCustomers,
        countSuffix: 'işlem',
      ),
      if (report.excludedCurrencySessionCount > 0) ...[
        const SizedBox(height: 12),
        Text(
          '${report.excludedCurrencySessionCount} işlem farklı para biriminde '
          'olduğu için toplamlara dahil edilmedi.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
      if (report.isTruncated) ...[
        const SizedBox(height: 8),
        Text(
          'Rapor veri sınırına ulaştı; çok yoğun dönemlerde sunucu raporu '
          'etkinleştirilene kadar sonuçlar kısmi olabilir.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.error,
          ),
        ),
      ],
    ],
  );
}

class _RevenueCard extends StatelessWidget {
  const _RevenueCard({required this.label, required this.summary});

  final String label;
  final RevenuePeriodSummary summary;

  @override
  Widget build(BuildContext context) {
    final amount = formatSessionMoney(
      summary.finalizedSales.minorUnits,
      summary.finalizedSales.currencyCode,
    );
    final collected = formatSessionMoney(
      summary.collection.netCollected.minorUnits,
      summary.collection.netCollected.currencyCode,
    );
    return Semantics(
      container: true,
      label:
          '$label: kesinleşen satış $amount, net tahsilat $collected, ${summary.completedCount} tamamlanan işlem.',
      excludeSemantics: true,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      label,
                      softWrap: true,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.trending_up_rounded,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Kesinleşen satış',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 4),
              Text(
                amount,
                softWrap: true,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Net tahsilat',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 4),
              Text(
                collected,
                softWrap: true,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              Text(
                '${summary.completedCount} tamamlanan işlem',
                softWrap: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RevenueSplitCard extends StatelessWidget {
  const _RevenueSplitCard({required this.report});

  final ReportOverview report;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bu ay kesinleşen satış dağılımı',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          _AmountRow(label: 'Hizmet geliri', money: report.monthServiceRevenue),
          const Divider(height: 24),
          _AmountRow(label: 'Ürün geliri', money: report.monthProductRevenue),
        ],
      ),
    ),
  );
}

class _CollectionBreakdownCard extends StatelessWidget {
  const _CollectionBreakdownCard({required this.collection});

  final CollectionPeriodSummary collection;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bu ay tahsilat dağılımı',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          const Text('İadeler net tahsilattan düşülür.'),
          const SizedBox(height: 16),
          _AmountRow(label: 'Nakit', money: collection.cashCollected),
          const Divider(height: 20),
          _AmountRow(label: 'Kart', money: collection.cardCollected),
          const Divider(height: 20),
          _AmountRow(
            label: 'Havale / EFT',
            money: collection.bankTransferCollected,
          ),
          const Divider(height: 20),
          _AmountRow(label: 'Diğer', money: collection.otherCollected),
          const Divider(height: 20),
          _AmountRow(label: 'İadeler', money: collection.refunded),
          const Divider(height: 20),
          _AmountRow(
            label: 'Tahsil edilmemiş bakiye',
            money: collection.outstanding,
          ),
        ],
      ),
    ),
  );
}

class _AmountRow extends StatelessWidget {
  const _AmountRow({required this.label, required this.money});

  final String label;
  final Money money;

  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.spaceBetween,
    spacing: 12,
    runSpacing: 4,
    children: [
      Text(label),
      Text(
        formatSessionMoney(money.minorUnits, money.currencyCode),
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
    ],
  );
}

class _RankingCard extends StatelessWidget {
  const _RankingCard({
    required this.title,
    required this.emptyMessage,
    required this.rankings,
    required this.countSuffix,
  });

  final String title;
  final String emptyMessage;
  final List<NamedMoneyRanking> rankings;
  final String countSuffix;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          if (rankings.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(emptyMessage),
            )
          else
            for (var index = 0; index < rankings.length; index++)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(child: Text('${index + 1}')),
                title: Text(rankings[index].name),
                subtitle: Text(
                  '${rankings[index].count} $countSuffix · '
                  '${formatSessionMoney(rankings[index].amount.minorUnits, rankings[index].amount.currencyCode)}',
                ),
              ),
        ],
      ),
    ),
  );
}

class _NoBusinessReport extends StatelessWidget {
  const _NoBusinessReport();

  @override
  Widget build(BuildContext context) =>
      const Center(child: Text('Raporlanacak aktif işletme bulunamadı.'));
}
