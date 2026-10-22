import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../../../core/utils/clock.dart';
import '../../../core/utils/pdf_tools.dart';
import '../data/orders_repositories.dart';
import '../data/shipping_label_mock_repository.dart';
import '../domain/order.dart';
import '../domain/orders_repository.dart';
import '../domain/shipping_label_repository.dart';

final ordersRepositoryProvider = Provider<OrdersRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  return config.useMock
      ? OrdersMockRepository(clock: ref.watch(clockProvider))
      : OrdersRemoteRepository(ref.watch(dioProvider));
});

/// Trang đầu danh sách đơn. Kéo để làm mới = `ref.invalidate(ordersPageProvider)`.
/// TODO(pagination): tải thêm trang khi cuộn cuối danh sách.
final ordersPageProvider = FutureProvider.autoDispose<PageResult<Order>>(
  (ref) => ref.watch(ordersRepositoryProvider).fetchOrders(),
);

/// Chỉ có Mock: backend chưa có API tem vận đơn.
final shippingLabelRepositoryProvider = Provider<ShippingLabelRepository>(
  (ref) => const ShippingLabelMockRepository(),
);

/// Tem vận đơn của một đơn (M-22): file PDF + ảnh từng trang để xem trước.
final shippingLabelProvider = FutureProvider.autoDispose
    .family<ShippingLabel, int>((ref, orderId) async {
      final pdf = await ref
          .watch(shippingLabelRepositoryProvider)
          .fetchLabel(orderId);
      final pages = await ref.watch(pdfToolsProvider).rasterize(pdf);
      return ShippingLabel(pdf: pdf, pages: pages);
    });

class ShippingLabel {
  const ShippingLabel({required this.pdf, required this.pages});

  final Uint8List pdf;
  final List<PdfPageImage> pages;
}
