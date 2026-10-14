import 'package:flutter/widgets.dart';

import '../../../core/design/design.dart';
import '../../../core/utils/formatters.dart';
import '../domain/order.dart';
import '../domain/order_rules.dart';

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

extension OrderItemUi on OrderItem {
  /// Tên mẫu "Áo thun cotton basic - Trắng / M" -> ("Áo thun cotton basic", "Trắng / M").
  (String, String?) get nameAndVariant {
    final i = name.lastIndexOf(' - ');
    return i < 0 ? (name, null) : (name.substring(0, i), name.substring(i + 3));
  }
}

extension ProgressStepUi on OrderProgressStep {
  SoStepState get soState => switch (state) {
    ProgressState.done => SoStepState.done,
    ProgressState.current => SoStepState.current,
    ProgressState.upcoming => SoStepState.upcoming,
  };

  SoTimelineStep toTimeline(Order order) => SoTimelineStep(
    title: status.label,
    state: soState,
    subtitle: switch (status) {
      OrderStatus.pending => Formatters.dateTime(order.createdAt),
      OrderStatus.toShip => 'Nhân viên chuẩn bị hàng',
      _ => 'Sàn tự cập nhật',
    },
  );
}

/// Tiêu đề nhóm ngày: "Hôm nay", "Hôm qua", hoặc "12/10/2026".
String dayGroupLabel(DateTime? day, {DateTime? now}) {
  if (day == null) return 'Không rõ ngày';
  final n = now ?? DateTime.now();
  final today = DateTime(n.year, n.month, n.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Hôm nay';
  if (diff == 1) return 'Hôm qua';
  return Formatters.date(day);
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
