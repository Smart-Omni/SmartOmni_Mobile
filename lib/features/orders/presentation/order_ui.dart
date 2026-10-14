import 'package:flutter/widgets.dart';

import '../../../core/design/design.dart';
import '../../../core/utils/formatters.dart';
import '../domain/order.dart';

/// Ánh xạ trạng thái đơn -> tông nhãn (docs/DESIGN.md mục 6).
extension OrderStatusUi on OrderStatus {
  SoStatus get soStatus => switch (this) {
    OrderStatus.pending => SoStatus.warning,
    OrderStatus.toShip => SoStatus.kraft,
    OrderStatus.shipped || OrderStatus.delivering => SoStatus.info,
    OrderStatus.completed => SoStatus.success,
    OrderStatus.cancelled => SoStatus.neutral,
    OrderStatus.returned => SoStatus.danger,
  };
}

extension OrderUi on Order {
  /// "Áo thun… và 1 sản phẩm khác". Backend chưa trả sản phẩm trong đơn
  /// qua API, khi đó hiện dòng "Chưa có thông tin sản phẩm".
  String get productSummary {
    if (items.isEmpty) return 'Chưa có thông tin sản phẩm';
    final first = items.first.name;
    return items.length == 1
        ? first
        : '$first và ${items.length - 1} sản phẩm khác';
  }

  /// "Nguyễn Văn A · 09:41"
  String get rowMeta => [
    ?customerName,
    if (createdAt != null) Formatters.time(createdAt),
  ].join(' · ');
}

/// [SoOrderRow] dựng từ [Order].
class OrderRow extends StatelessWidget {
  const OrderRow({super.key, required this.order, this.onTap});

  final Order order;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final meta = order.rowMeta;
    return SoOrderRow(
      platform: order.platform,
      orderCode: order.platformOrderId,
      amount: order.totalAmount,
      productSummary: order.productSummary,
      statusLabel: order.status.label,
      status: order.status.soStatus,
      meta: meta.isEmpty ? null : meta,
      onTap: onTap,
    );
  }
}
