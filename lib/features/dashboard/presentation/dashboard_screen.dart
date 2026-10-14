import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/user_role.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/dashboard_data.dart';

/// Trang Tổng quan của Merchant.
/// - Tenant Admin: thấy doanh thu, doanh thu theo kênh (BI).
/// - Staff: thấy việc cần làm (đơn chờ xử lý, SKU sắp hết, cảnh báo AI).
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(currentRoleProvider);
    final isAdmin = role == UserRole.tenantAdmin;

    return Scaffold(
      appBar: AppBar(
        title: Text(isAdmin ? 'Tổng quan cửa hàng' : 'Việc hôm nay'),
      ),
      body: Column(
        children: [
          const MockDataBanner(),
          Expanded(
            child: AsyncValueView(
              value: ref.watch(dashboardSummaryProvider),
              onRetry: () => ref.invalidate(dashboardSummaryProvider),
              data: (s) => RefreshIndicator(
                onRefresh: () => ref.refresh(dashboardSummaryProvider.future),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _Kpi(label: 'Đơn hôm nay', value: '${s.ordersToday}'),
                        _Kpi(label: 'Chờ xử lý', value: '${s.pendingOrders}'),
                        _Kpi(label: 'SKU sắp hết', value: '${s.lowStockSkus}'),
                        if (isAdmin)
                          _Kpi(
                            label: 'Doanh thu hôm nay',
                            value: Formatters.vnd(s.revenueToday),
                          ),
                      ],
                    ),
                    if (isAdmin) ...[
                      const SizedBox(height: 24),
                      Text(
                        'Doanh thu theo kênh',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      for (final e in s.revenueByChannel.entries)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(e.key.label),
                          trailing: Text(Formatters.vnd(e.value)),
                        ),
                    ],
                    const SizedBox(height: 24),
                    Text(
                      'Cảnh báo AI',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    for (final a in s.aiAlerts)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(switch (a.type) {
                          AiAlertType.lowStock => Icons.warning_amber,
                          AiAlertType.priceAnomaly =>
                            Icons.price_change_outlined,
                          AiAlertType.demandSpike => Icons.trending_up,
                        }),
                        title: Text(a.title),
                        subtitle: Text(a.detail),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final width = (MediaQuery.sizeOf(context).width - 44) / 2;
    return SizedBox(
      width: width,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 4),
              Text(value, style: Theme.of(context).textTheme.titleLarge),
            ],
          ),
        ),
      ),
    );
  }
}
