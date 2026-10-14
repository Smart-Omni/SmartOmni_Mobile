import '../../../core/models/platform.dart';
import '../../../core/network/api_response.dart';

/// Trạng thái đơn. Khớp `Order.OrderStatus` của backend.
enum OrderStatus {
  pending('PENDING', 'Chờ xử lý'),
  toShip('TO_SHIP', 'Chờ giao'),
  shipped('SHIPPED', 'Đã giao cho ĐVVC'),
  delivering('DELIVERING', 'Đang giao'),
  completed('COMPLETED', 'Hoàn tất'),
  cancelled('CANCELLED', 'Đã hủy'),
  returned('RETURNED', 'Trả hàng');

  const OrderStatus(this.backendValue, this.label);

  final String backendValue;
  final String label;

  static OrderStatus fromBackend(String? value) =>
      OrderStatus.values.firstWhere(
        (s) => s.backendValue == value?.toUpperCase(),
        orElse: () => OrderStatus.pending,
      );

  /// Quy tắc nghiệp vụ: trạng thái HOÀN TẤT / TRẢ HÀNG / HỦY / VẬN CHUYỂN
  /// lấy từ sàn. Staff/Tenant Admin chỉ được chuyển thủ công các bước xử lý nội bộ.
  ///
  /// Hiện chỉ cho phép: PENDING -> TO_SHIP ("Chuẩn bị hàng").
  List<OrderStatus> get manualTransitions => switch (this) {
    OrderStatus.pending => const [OrderStatus.toShip],
    _ => const [],
  };
}

enum OrderSource { webhook, polling, manual }

/// Đơn hàng (entity `orders` của backend).
class Order {
  const Order({
    required this.id,
    required this.platform,
    required this.platformOrderId,
    required this.status,
    required this.totalAmount,
    this.customerName,
    this.customerPhone,
    this.shippingAddress,
    this.source,
    this.createdAt,
    this.items = const [],
  });

  final int id;
  final Platform platform;

  /// Mã đơn trên sàn (dùng khi khách claim điểm).
  final String platformOrderId;
  final OrderStatus status;
  final double totalAmount;
  final String? customerName;
  final String? customerPhone;
  final String? shippingAddress;
  final OrderSource? source;
  final DateTime? createdAt;

  /// Backend chưa trả danh sách sản phẩm trong đơn qua API -> hiện chỉ có ở mock.
  final List<OrderItem> items;

  factory Order.fromJson(JsonMap json) => Order(
    id: Json.asInt(json['id']) ?? 0,
    platform: Platform.fromBackend(json['platform'] as String?),
    platformOrderId: Json.asString(json['platformOrderId']) ?? '',
    status: OrderStatus.fromBackend(json['status'] as String?),
    totalAmount: Json.asDouble(json['totalAmount']) ?? 0,
    customerName: json['customerName'] as String?,
    customerPhone: json['customerPhone'] as String?,
    shippingAddress: json['shippingAddress'] as String?,
    source: switch ((json['source'] as String?)?.toUpperCase()) {
      'WEBHOOK' => OrderSource.webhook,
      'POLLING' => OrderSource.polling,
      'MANUAL' => OrderSource.manual,
      _ => null,
    },
    createdAt: Json.asDate(json['createdAt']),
  );

  Order copyWith({OrderStatus? status}) => Order(
    id: id,
    platform: platform,
    platformOrderId: platformOrderId,
    status: status ?? this.status,
    totalAmount: totalAmount,
    customerName: customerName,
    customerPhone: customerPhone,
    shippingAddress: shippingAddress,
    source: source,
    createdAt: createdAt,
    items: items,
  );
}

class OrderItem {
  const OrderItem({
    required this.skuCode,
    required this.name,
    required this.quantity,
    required this.unitPrice,
  });

  final String skuCode;
  final String name;
  final int quantity;
  final double unitPrice;
}
