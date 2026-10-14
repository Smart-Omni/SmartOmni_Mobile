import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/platform.dart';
import '../../../core/utils/mock_delay.dart';

/// Số liệu tổng quan cho Merchant.
///
/// ⚠️ Backend chưa có API dashboard/BI -> toàn bộ là dữ liệu mẫu.
/// Khi có API, thay [dashboardSummaryProvider] bằng repository gọi API thật.
class DashboardSummary {
  const DashboardSummary({
    required this.shopName,
    required this.ordersToday,
    required this.pendingOrders,
    required this.toShipOrders,
    required this.revenueToday,
    required this.revenue7Days,
    required this.lowStockSkus,
    required this.revenueByChannel,
    required this.aiAlerts,
  });

  final String shopName;
  final int ordersToday;
  final int pendingOrders;
  final int toShipOrders;
  final double revenueToday;

  /// Doanh thu 7 ngày gần nhất, phần tử cuối là hôm nay.
  final List<double> revenue7Days;
  final int lowStockSkus;
  final Map<Platform, double> revenueByChannel;
  final List<AiAlert> aiAlerts;

  /// Tỉ trọng doanh thu của [platform] trên tổng các kênh (0..1).
  double channelShare(Platform platform) {
    final total = revenueByChannel.values.fold<double>(0, (a, b) => a + b);
    if (total <= 0) return 0;
    return (revenueByChannel[platform] ?? 0) / total;
  }
}

enum AiAlertType { lowStock, priceAnomaly, demandSpike }

class AiAlert {
  const AiAlert({
    required this.type,
    required this.title,
    required this.detail,
  });

  final AiAlertType type;
  final String title;
  final String detail;
}

final dashboardSummaryProvider = FutureProvider.autoDispose<DashboardSummary>((
  ref,
) async {
  await MockDelay.short();
  return const DashboardSummary(
    shopName: 'Shop Demo',
    ordersToday: 12,
    pendingOrders: 3,
    toShipOrders: 1,
    revenueToday: 3870000,
    revenue7Days: [
      2100000,
      2650000,
      1980000,
      3120000,
      2890000,
      3410000,
      3870000,
    ],
    lowStockSkus: 3,
    revenueByChannel: {Platform.shopee: 2450000, Platform.tiktokShop: 1420000},
    aiAlerts: [
      AiAlert(
        type: AiAlertType.lowStock,
        title: 'Áo thun basic Trắng/L sắp hết',
        detail: 'Còn 3 sản phẩm có thể bán, dự kiến hết trong 2 ngày.',
      ),
      AiAlert(
        type: AiAlertType.priceAnomaly,
        title: 'Giá Quần jean Size 31 chênh lệch',
        detail: 'Giá trên TikTok Shop thấp hơn Shopee 18%.',
      ),
      AiAlert(
        type: AiAlertType.demandSpike,
        title: 'Túi tote canvas tăng nhu cầu',
        detail: 'Dự báo bán gấp 2 lần tuần trước.',
      ),
    ],
  );
});
