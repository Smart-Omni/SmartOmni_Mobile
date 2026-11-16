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
  returned('RETURNED', 'Trả hàng'),

  /// Sàn tạm giữ đơn (TikTok `IN_CANCEL`/`ON_HOLD`, đang xử lý trả hàng).
  /// Sàn tự chuyển tiếp sang Chờ giao hoặc Đã hủy, người bán không thao tác.
  onHold('ON_HOLD', 'Tạm giữ');

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

/// Đơn hàng: entity `Order` ở danh sách, `OrderDetailDto` (kèm `items`) ở
/// `GET /api/v1/orders/{id}`. Cả hai camelCase.
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
    this.trackingNumber,
    this.slaDeadline,
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

  /// Có trong entity BE, chưa hiện ở M-21 (DESIGN.md chưa có chỗ).
  final String? trackingNumber;
  final DateTime? slaDeadline;

  /// Sản phẩm của đơn. Danh sách đơn của BE không kèm (rỗng); có ở
  /// `GET /api/v1/orders/{id}` và ở mock.
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
    trackingNumber: json['trackingNumber'] as String?,
    slaDeadline: Json.asDate(json['slaDeadline']),
    items: [
      for (final i in (json['items'] as List<dynamic>? ?? const []))
        OrderItem.fromJson(i as JsonMap),
    ],
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
    trackingNumber: trackingNumber,
    slaDeadline: slaDeadline,
    items: items,
  );
}

/// Một dòng sản phẩm của đơn (`OrderItemDto`).
class OrderItem {
  const OrderItem({
    required this.skuCode,
    required this.name,
    required this.quantity,
    required this.unitPrice,
    this.skuId,
    this.subtotal,
    this.imageUrl,
  });

  /// BE `3eb89ec` khai báo `skuCode`, `productName` nhưng chưa điền (luôn
  /// null): khi đó mã rỗng và tên là `SKU #<skuId>`.
  factory OrderItem.fromJson(JsonMap json) {
    final skuId = Json.asInt(json['skuId']);
    final name = (json['productName'] as String?)?.trim();
    return OrderItem(
      skuId: skuId,
      skuCode: (json['skuCode'] as String?)?.trim() ?? '',
      name: name == null || name.isEmpty
          ? (skuId == null ? 'Sản phẩm' : 'SKU #$skuId')
          : name,
      quantity: Json.asInt(json['quantity']) ?? 0,
      unitPrice: Json.asDouble(json['unitPrice']) ?? 0,
      subtotal: Json.asDouble(json['subtotal']),
      imageUrl: json['imageUrl'] as String?,
    );
  }

  final int? skuId;

  /// Mã SKU; rỗng khi BE không trả.
  final String skuCode;
  final String name;
  final int quantity;
  final double unitPrice;

  /// Thành tiền BE tính (`unitPrice × quantity`).
  final double? subtotal;
  final String? imageUrl;
}
