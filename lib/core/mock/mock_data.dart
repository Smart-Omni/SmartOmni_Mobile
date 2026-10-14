import '../../features/orders/domain/order.dart';
import '../models/platform.dart';

/// Dữ liệu mẫu dùng chung cho các repository mock.
///
/// Khi backend bổ sung API, chỉ cần viết repository remote tương ứng;
/// màn hình không phải sửa.
class MockData {
  const MockData._();

  static final DateTime _now = DateTime.now();

  static DateTime daysAgo(int days, {int hours = 0}) =>
      _now.subtract(Duration(days: days, hours: hours));

  // ---------------------------------------------------------------- Sản phẩm
  /// (productId, tên, mô tả, [ (skuId, skuCode, biến thể, giá) ], urlShopee, urlTiktok)
  static const products =
      <
        (
          int,
          String,
          String,
          List<(int, String, String, double)>,
          String?,
          String?,
        )
      >[
        (
          1,
          'Áo thun cotton basic',
          'Áo thun 100% cotton, form regular, nhiều màu.',
          [
            (101, 'AT-BASIC-TRANG-M', 'Trắng / M', 159000),
            (102, 'AT-BASIC-TRANG-L', 'Trắng / L', 159000),
            (103, 'AT-BASIC-DEN-M', 'Đen / M', 169000),
          ],
          'https://shopee.vn',
          'https://www.tiktok.com/shop',
        ),
        (
          2,
          'Quần jean slim fit',
          'Jean co giãn nhẹ, wash xanh nhạt.',
          [
            (201, 'QJ-SLIM-29', 'Size 29', 389000),
            (202, 'QJ-SLIM-30', 'Size 30', 389000),
            (203, 'QJ-SLIM-31', 'Size 31', 399000),
          ],
          'https://shopee.vn',
          null,
        ),
        (
          3,
          'Túi tote canvas',
          'Túi vải canvas dày, có ngăn trong.',
          [(301, 'TT-CANVAS-BE', 'Màu be', 129000)],
          null,
          'https://www.tiktok.com/shop',
        ),
        (
          4,
          'Mũ lưỡi trai thêu logo',
          'Mũ kaki, khóa kim loại điều chỉnh.',
          [
            (401, 'ML-THEU-DEN', 'Đen', 99000),
            (402, 'ML-THEU-KEM', 'Kem', 99000),
          ],
          'https://shopee.vn',
          'https://www.tiktok.com/shop',
        ),
        (
          5,
          'Khăn bandana họa tiết',
          'Khăn cotton vuông 55 cm, ngừng bán theo mùa.',
          [(501, 'KB-HOATIET-DO', 'Đỏ', 59000)],
          'https://shopee.vn',
          null,
        ),
      ];

  /// Sản phẩm đang ẩn (status HIDDEN).
  static const hiddenProductIds = {5};

  /// skuId -> (tồn thực tế, đang giữ chỗ)
  static final inventory = <int, (int, int)>{
    101: (42, 3),
    102: (4, 1),
    103: (0, 0),
    201: (18, 2),
    202: (25, 0),
    203: (3, 0),
    301: (60, 5),
    401: (12, 0),
    402: (2, 0),
    501: (7, 0),
  };

  // ---------------------------------------------------------------- Đơn hàng
  static final List<Order> orders = [
    Order(
      id: 1001,
      platform: Platform.shopee,
      platformOrderId: '241014ABCD12',
      status: OrderStatus.pending,
      totalAmount: 318000,
      customerName: 'Nguyễn Văn A',
      customerPhone: '090****123',
      shippingAddress: 'Q.1, TP.HCM',
      source: OrderSource.webhook,
      createdAt: daysAgo(0, hours: 1),
      items: const [
        OrderItem(
          skuCode: 'AT-BASIC-TRANG-M',
          name: 'Áo thun cotton basic - Trắng / M',
          quantity: 2,
          unitPrice: 159000,
        ),
      ],
    ),
    Order(
      id: 1006,
      platform: Platform.tiktokShop,
      platformOrderId: '5779223344556677',
      status: OrderStatus.pending,
      totalAmount: 457000,
      customerName: 'Võ Thị F',
      customerPhone: '093****789',
      shippingAddress: 'Hải Châu, Đà Nẵng',
      source: OrderSource.webhook,
      createdAt: daysAgo(0, hours: 2),
      items: const [
        OrderItem(
          skuCode: 'TT-CANVAS-KEM',
          name: 'Túi tote canvas - Kem',
          quantity: 1,
          unitPrice: 139000,
        ),
        OrderItem(
          skuCode: 'AT-BASIC-DEN-L',
          name: 'Áo thun cotton basic - Đen / L',
          quantity: 2,
          unitPrice: 159000,
        ),
      ],
    ),
    Order(
      id: 1007,
      platform: Platform.shopee,
      platformOrderId: '241014IJKL56',
      status: OrderStatus.pending,
      totalAmount: 389000,
      customerName: 'Đặng G',
      customerPhone: '097****321',
      shippingAddress: 'Ninh Kiều, Cần Thơ',
      source: OrderSource.polling,
      createdAt: daysAgo(0, hours: 3),
      items: const [
        OrderItem(
          skuCode: 'QJ-SLIM-31',
          name: 'Quần jean slim fit - Size 31',
          quantity: 1,
          unitPrice: 389000,
        ),
      ],
    ),
    Order(
      id: 1002,
      platform: Platform.tiktokShop,
      platformOrderId: '5779112233445566',
      status: OrderStatus.toShip,
      totalAmount: 389000,
      customerName: 'Trần Thị B',
      customerPhone: '091****456',
      shippingAddress: 'Cầu Giấy, Hà Nội',
      source: OrderSource.webhook,
      createdAt: daysAgo(0, hours: 5),
      items: const [
        OrderItem(
          skuCode: 'QJ-SLIM-29',
          name: 'Quần jean slim fit - Size 29',
          quantity: 1,
          unitPrice: 389000,
        ),
      ],
    ),
    Order(
      id: 1003,
      platform: Platform.shopee,
      platformOrderId: '241010EFGH34',
      status: OrderStatus.delivering,
      totalAmount: 228000,
      customerName: 'Lê C',
      source: OrderSource.polling,
      createdAt: daysAgo(3),
    ),
    Order(
      id: 1004,
      platform: Platform.shopee,
      platformOrderId: '240920SHOP01',
      status: OrderStatus.completed,
      totalAmount: 548000,
      customerName: 'Phạm D',
      source: OrderSource.webhook,
      createdAt: daysAgo(24),
    ),
    Order(
      id: 1005,
      platform: Platform.tiktokShop,
      platformOrderId: '5779000011112222',
      status: OrderStatus.cancelled,
      totalAmount: 129000,
      customerName: 'Hoàng E',
      source: OrderSource.webhook,
      createdAt: daysAgo(6),
    ),
  ];

  // ------------------------------------------------- Đơn để khách claim điểm
  /// Đơn trên sàn mà khách có thể nhập mã để claim.
  /// (mã đơn, sàn, tiền hàng thực trả - không gồm ship/thuế, thời điểm hoàn tất)
  static final claimableOrders = <(String, Platform, double, DateTime?)>[
    ('240920SHOP01', Platform.shopee, 520000, daysAgo(20)),
    ('5779000099998888', Platform.tiktokShop, 1250000, daysAgo(30)),
    ('241008SHOP02', Platform.shopee, 300000, daysAgo(5)), // chưa đủ 15 ngày
    ('241012SHOP03', Platform.shopee, 450000, null), // chưa hoàn tất
  ];
}
