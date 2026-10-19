import 'package:dio/dio.dart';

import '../../../core/mock/mock_data.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/api_response.dart';
import '../../../core/utils/mock_delay.dart';
import '../domain/order.dart';
import '../domain/orders_repository.dart';

/// Gọi API thật của Order Service.
class OrdersRemoteRepository implements OrdersRepository {
  OrdersRemoteRepository(this._dio);

  final Dio _dio;

  @override
  Future<PageResult<Order>> fetchOrders({int page = 0, int size = 20}) async {
    try {
      final res = await _dio.get<Object?>(
        '/api/orders',
        queryParameters: {'page': page, 'size': size, 'sort': 'createdAt,desc'},
      );
      return unwrapResponse<PageResult<Order>>(
        res.data,
        (data) => PageResult.fromJson(data, Order.fromJson),
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  @override
  Future<Order> updateStatus(int orderId, OrderStatus status) async {
    try {
      final res = await _dio.patch<Object?>(
        '/api/orders/$orderId/status',
        queryParameters: {'status': status.backendValue},
      );
      return unwrapResponse<Order>(
        res.data,
        (data) => Order.fromJson(data! as JsonMap),
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  @override
  Future<void> createReturn({
    required int orderId,
    required String reason,
  }) async {
    try {
      await _dio.post<Object?>(
        '/api/returns',
        data: {'orderId': orderId, 'reason': reason},
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

/// Dữ liệu giả, lưu trong bộ nhớ (mất khi tắt app).
class OrdersMockRepository implements OrdersRepository {
  OrdersMockRepository({DateTime Function()? clock})
    : _orders = MockData.ordersAt((clock ?? DateTime.now)());

  final List<Order> _orders;

  @override
  Future<PageResult<Order>> fetchOrders({int page = 0, int size = 20}) async {
    await MockDelay.short();
    final start = page * size;
    final items = _orders.skip(start).take(size).toList();
    return PageResult(
      items: items,
      page: page,
      size: size,
      totalElements: _orders.length,
      totalPages: (_orders.length / size).ceil(),
    );
  }

  @override
  Future<Order> updateStatus(int orderId, OrderStatus status) async {
    await MockDelay.short();
    final index = _orders.indexWhere((o) => o.id == orderId);
    if (index < 0) {
      throw const ApiException(
        type: ApiErrorType.notFound,
        message: 'Đơn hàng không tồn tại',
      );
    }
    final updated = _orders[index].copyWith(status: status);
    _orders[index] = updated;
    return updated;
  }

  @override
  Future<void> createReturn({required int orderId, required String reason}) =>
      MockDelay.short();
}
