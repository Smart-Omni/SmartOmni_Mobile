import '../../../core/network/api_response.dart';
import 'order.dart';

abstract class OrdersRepository {
  /// GET /api/orders?page=&size=  (Spring Pageable, page bắt đầu từ 0)
  Future<PageResult<Order>> fetchOrders({int page = 0, int size = 20});

  /// GET /api/v1/orders/{id}: chi tiết kèm sản phẩm (`items`).
  Future<Order> getOrder(int orderId);

  /// PATCH /api/orders/{id}/status?status=
  Future<Order> updateStatus(int orderId, OrderStatus status);

  /// POST /api/returns  { orderId, reason }
  Future<void> createReturn({required int orderId, required String reason});
}
