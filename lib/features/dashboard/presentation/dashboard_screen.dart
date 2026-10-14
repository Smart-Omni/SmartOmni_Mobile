import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/router/routes.dart';
import '../../../core/auth/user_role.dart';
import '../../../core/design/design.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../orders/domain/order.dart';
import '../../orders/presentation/order_ui.dart';
import '../../orders/presentation/orders_providers.dart';
import '../data/dashboard_data.dart';
import 'dashboard_charts.dart';

/// M-10 Tổng quan của Merchant.
/// - Staff ("Việc hôm nay"): việc cần làm, **không** thấy doanh thu.
/// - Tenant Admin ("Tổng quan cửa hàng"): thêm doanh thu hôm nay, theo kênh, 7 ngày.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(currentRoleProvider);
    final isAdmin = role == UserRole.tenantAdmin;
    final summaryAsync = ref.watch(dashboardSummaryProvider);
    final shopName = summaryAsync.value?.shopName;

    Future<void> refresh() async {
      ref
        ..invalidate(ordersPageProvider)
        ..invalidate(dashboardSummaryProvider);
      await ref.read(dashboardSummaryProvider.future);
    }

    return Scaffold(
      appBar: SoAppBar.root(
        title: isAdmin ? 'Tổng quan cửa hàng' : 'Việc hôm nay',
        subtitle: [?shopName, ?role?.label].join(' · '),
      ),
      body: Column(
        children: [
          const SoMockBanner(
            message: 'Số liệu tổng quan và cảnh báo AI là dữ liệu mẫu.',
          ),
          Expanded(
            child: switch (summaryAsync) {
              AsyncData(:final value) => RefreshIndicator(
                onRefresh: refresh,
                child: _DashboardBody(summary: value, isAdmin: isAdmin),
              ),
              AsyncError(:final error) => ListView(
                children: [
                  SoEmptyState.error(
                    title: 'Không tải được tổng quan',
                    message: AsyncValueView.errorMessage(error),
                    onAction: () => ref.invalidate(dashboardSummaryProvider),
                  ),
                ],
              ),
              _ => const _DashboardSkeleton(),
            },
          ),
        ],
      ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({required this.summary, required this.isAdmin});

  final DashboardSummary summary;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    final s = summary;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        SoSpace.screen,
        SoSpace.s16,
        SoSpace.screen,
        SoSpace.s32,
      ),
      children: [
        _TileGrid(
          tiles: [
            SoStatTile(
              key: const Key('tile_orders_today'),
              label: 'Đơn hôm nay',
              value: '${s.ordersToday}',
              onTap: () => context.go(Routes.merchantOrders),
            ),
            SoStatTile(
              key: const Key('tile_pending'),
              label: 'Chờ xử lý',
              value: '${s.pendingOrders}',
              note: s.pendingOrders > 0 ? 'Cần chuẩn bị hàng' : 'Đã xử lý hết',
              attention: s.pendingOrders > 0,
              onTap: () => context.go(Routes.merchantOrders),
            ),
            if (isAdmin)
              SoStatTile(
                key: const Key('tile_revenue_today'),
                label: 'Doanh thu hôm nay',
                value: Formatters.compactVnd(s.revenueToday),
              )
            else
              SoStatTile(
                key: const Key('tile_to_ship'),
                label: 'Chờ giao',
                value: '${s.toShipOrders}',
                onTap: () => context.go(Routes.merchantOrders),
              ),
            SoStatTile(
              key: const Key('tile_low_stock'),
              label: 'SKU sắp hết',
              value: '${s.lowStockSkus}',
              note: s.lowStockSkus > 0 ? 'Xem ở Tồn kho' : null,
              attention: s.lowStockSkus > 0,
              onTap: () => context.go(Routes.merchantInventory),
            ),
          ],
        ),
        if (isAdmin) ...[
          const _GroupHeader(title: 'Doanh thu theo kênh'),
          RevenueByChannelCard(summary: s),
          const _GroupHeader(title: 'Doanh thu 7 ngày'),
          Revenue7DaysCard(values: s.revenue7Days, today: DateTime.now()),
        ] else ...[
          _GroupHeader(
            title: 'Đơn cần xử lý',
            actionLabel: 'Xem tất cả',
            actionKey: const Key('pending_see_all'),
            onAction: () => context.go(Routes.merchantOrders),
          ),
          const _PendingOrders(),
        ],
        const _GroupHeader(title: 'Cảnh báo AI'),
        _AiAlerts(alerts: s.aiAlerts),
      ],
    );
  }
}

/// Lưới 2 cột các ô chỉ số. Hai ô cùng hàng cao bằng nhau.
class _TileGrid extends StatelessWidget {
  const _TileGrid({required this.tiles});

  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < tiles.length; i += 2) ...[
          if (i > 0) const SizedBox(height: SoSpace.cardGap),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: tiles[i]),
                const SizedBox(width: SoSpace.cardGap),
                Expanded(
                  child: i + 1 < tiles.length
                      ? tiles[i + 1]
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({
    required this.title,
    this.actionLabel,
    this.actionKey,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final Key? actionKey;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: SoSpace.group, bottom: SoSpace.s8),
      child: SizedBox(
        height: SoSize.controlSmall,
        child: Row(
          children: [
            Expanded(
              child: Text(title.toUpperCase(), style: context.soText.overline),
            ),
            if (actionLabel != null)
              TextButton(
                key: actionKey,
                onPressed: onAction,
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, SoSize.controlSmall),
                  padding: const EdgeInsets.symmetric(horizontal: SoSpace.s8),
                ),
                child: Text(actionLabel!),
              ),
          ],
        ),
      ),
    );
  }
}

/// 3 đơn Chờ xử lý mới nhất. Lấy từ API đơn hàng (đã có), không phải mock.
class _PendingOrders extends ConsumerWidget {
  const _PendingOrders();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (ref.watch(ordersPageProvider)) {
      AsyncData(:final value) => () {
        final pending =
            value.items.where((o) => o.status == OrderStatus.pending).toList()
              ..sort(
                (a, b) => (b.createdAt ?? DateTime(0)).compareTo(
                  a.createdAt ?? DateTime(0),
                ),
              );
        if (pending.isEmpty) {
          return const SoListGroup(
            children: [
              Padding(
                padding: SoSpace.card,
                child: Text('Không có đơn nào đang chờ xử lý.'),
              ),
            ],
          );
        }
        return SoListGroup(
          children: [
            for (final order in pending.take(3))
              OrderRow(
                key: Key('pending_order_${order.id}'),
                order: order,
                onTap: () =>
                    context.push(Routes.merchantOrderDetail, extra: order),
              ),
          ],
        );
      }(),
      AsyncError(:final error) => SoListGroup(
        children: [
          SoEmptyState.error(
            title: 'Không tải được đơn hàng',
            message: AsyncValueView.errorMessage(error),
            onAction: () => ref.invalidate(ordersPageProvider),
          ),
        ],
      ),
      _ => const SoListGroup(children: [SoSkeletonList(count: 3)]),
    };
  }
}

class _AiAlerts extends StatelessWidget {
  const _AiAlerts({required this.alerts});

  final List<AiAlert> alerts;

  @override
  Widget build(BuildContext context) {
    final c = context.soColors;
    if (alerts.isEmpty) {
      return const SoListGroup(
        children: [
          Padding(padding: SoSpace.card, child: Text('Chưa có cảnh báo nào.')),
        ],
      );
    }
    return SoListGroup(
      children: [
        for (final a in alerts)
          InkWell(
            onTap: () => context.push(Routes.merchantAi),
            child: Padding(
              padding: SoSpace.card,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(switch (a.type) {
                    AiAlertType.lowStock => LucideIcons.package,
                    AiAlertType.priceAnomaly => LucideIcons.tag,
                    AiAlertType.demandSpike => LucideIcons.trendingUp,
                  }, color: c.ink2),
                  const SizedBox(width: SoSpace.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                a.title,
                                style: context.soText.bodyStrong,
                              ),
                            ),
                            const SizedBox(width: SoSpace.s8),
                            const Padding(
                              padding: EdgeInsets.only(top: 2),
                              child: SoAiLabel(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          a.detail,
                          style: context.textTheme.bodyMedium?.copyWith(
                            color: c.ink2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Khung chờ cùng hình nội dung: 4 ô chỉ số + một nhóm danh sách.
class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) {
    Widget tile() => Container(
      height: 96,
      padding: SoSpace.card,
      decoration: BoxDecoration(
        color: context.soColors.surface,
        borderRadius: SoRadius.mdAll,
        border: Border.all(color: context.soColors.line),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SoSkeleton(width: 80, height: 12),
          SizedBox(height: SoSpace.s12),
          SoSkeleton(width: 48, height: 28),
        ],
      ),
    );
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(SoSpace.screen),
      children: [
        _TileGrid(tiles: [tile(), tile(), tile(), tile()]),
        const SizedBox(height: SoSpace.group + SoSize.controlSmall + 8),
        const SoListGroup(children: [SoSkeletonList(count: 3)]),
      ],
    );
  }
}
