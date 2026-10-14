import '../../../core/utils/text_fold.dart';
import 'order.dart';

/// Vị trí của một bước trong tiến trình đơn.
enum ProgressState { done, current, upcoming }

/// Ai cập nhật bước này: nhân viên (trong app) hay sàn (đồng bộ về).
enum ProgressSource { staff, platform }

class OrderProgressStep {
  const OrderProgressStep(this.status, this.state, this.source);

  final OrderStatus status;
  final ProgressState state;
  final ProgressSource source;
}

/// Tiến trình hiển thị ở M-21 cho đơn đang ở trạng thái [current].
///
/// Luồng thường: Chờ xử lý → Chờ giao → Đã giao cho ĐVVC → Đang giao → Hoàn tất.
/// Chỉ bước "Chờ giao" do nhân viên chuyển (`manualTransitions`); các bước sau
/// do sàn tự cập nhật. Đơn hủy / trả hàng thay bước cuối bằng trạng thái đó.
List<OrderProgressStep> orderProgress(OrderStatus current) {
  const flow = [
    OrderStatus.pending,
    OrderStatus.toShip,
    OrderStatus.shipped,
    OrderStatus.delivering,
    OrderStatus.completed,
  ];

  ProgressSource sourceOf(OrderStatus s) =>
      s == OrderStatus.pending || s == OrderStatus.toShip
      ? ProgressSource.staff
      : ProgressSource.platform;

  List<OrderProgressStep> endedAt(List<OrderStatus> before, OrderStatus end) =>
      [
        for (final s in before)
          OrderProgressStep(s, ProgressState.done, sourceOf(s)),
        OrderProgressStep(end, ProgressState.current, ProgressSource.platform),
      ];

  return switch (current) {
    // Không biết đơn bị hủy ở bước nào: chỉ chắc chắn đã từng "Chờ xử lý".
    OrderStatus.cancelled => endedAt([OrderStatus.pending], current),
    // Trả hàng chỉ xảy ra sau khi đơn đã giao (xem USER_FLOWS.md).
    OrderStatus.returned => endedAt(flow.sublist(0, 4), current),
    _ => [
      for (final (i, s) in flow.indexed)
        OrderProgressStep(
          s,
          i < flow.indexOf(current)
              ? ProgressState.done
              : i == flow.indexOf(current)
              ? ProgressState.current
              : ProgressState.upcoming,
          sourceOf(s),
        ),
    ],
  };
}

/// Lý do chọn sẵn trong sheet "Ghi nhận hoàn/trả".
enum ReturnReason {
  refusedDelivery('Khách từ chối nhận'),
  customerRequest('Khách yêu cầu trả'),
  damaged('Hàng lỗi/hư hỏng'),
  wrongItem('Giao sai hàng');

  const ReturnReason(this.label);

  final String label;

  /// Chuỗi gửi lên `POST /api/returns`: `"<lý do>: <ghi chú>"`.
  String compose(String note) => '$label: ${note.trim()}';
}

/// Đơn có thể ghi nhận hoàn/trả không. Đơn đã hủy hoặc đã là "Trả hàng" thì không.
bool canRecordReturn(OrderStatus status) =>
    status != OrderStatus.cancelled && status != OrderStatus.returned;

/// Lọc đơn theo từ khóa: mã đơn hoặc tên khách, không phân biệt dấu/hoa thường.
bool orderMatches(Order order, String query) {
  final q = foldVietnamese(query.trim());
  if (q.isEmpty) return true;
  return foldVietnamese(order.platformOrderId).contains(q) ||
      foldVietnamese(order.customerName ?? '').contains(q);
}

/// Số đơn theo từng trạng thái (cho số đếm trên chip lọc).
Map<OrderStatus, int> countByStatus(Iterable<Order> orders) {
  final counts = {for (final s in OrderStatus.values) s: 0};
  for (final o in orders) {
    counts[o.status] = counts[o.status]! + 1;
  }
  return counts;
}

/// Nhóm đơn theo ngày tạo (mới nhất trước), giữ thứ tự mới -> cũ trong nhóm.
/// Đơn không có ngày tạo nằm ở nhóm cuối với khóa `null`.
List<(DateTime?, List<Order>)> groupOrdersByDay(Iterable<Order> orders) {
  final sorted = [...orders]
    ..sort((a, b) {
      if (a.createdAt == null) return b.createdAt == null ? 0 : 1;
      if (b.createdAt == null) return -1;
      return b.createdAt!.compareTo(a.createdAt!);
    });
  final groups = <(DateTime?, List<Order>)>[];
  for (final o in sorted) {
    final c = o.createdAt?.toLocal();
    final day = c == null ? null : DateTime(c.year, c.month, c.day);
    if (groups.isEmpty || groups.last.$1 != day) {
      groups.add((day, [o]));
    } else {
      groups.last.$2.add(o);
    }
  }
  return groups;
}
