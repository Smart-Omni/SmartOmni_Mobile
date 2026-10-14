import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../data/orders_repositories.dart';
import '../domain/order.dart';
import '../domain/orders_repository.dart';

final ordersRepositoryProvider = Provider<OrdersRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  return config.useMock
      ? OrdersMockRepository()
      : OrdersRemoteRepository(ref.watch(dioProvider));
});

/// Trang đầu danh sách đơn. Kéo để làm mới = `ref.invalidate(ordersPageProvider)`.
/// TODO(pagination): tải thêm trang khi cuộn cuối danh sách.
final ordersPageProvider = FutureProvider.autoDispose<PageResult<Order>>(
  (ref) => ref.watch(ordersRepositoryProvider).fetchOrders(),
);
