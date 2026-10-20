import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/customer_shop_mock_repository.dart';
import '../domain/customer_shop.dart';

/// Backend chưa có API -> luôn dùng mock, kể cả khi USE_MOCK=false.
final customerShopRepositoryProvider = Provider<CustomerShopRepository>(
  (ref) => CustomerShopMockRepository(),
);

/// Các cửa hàng khách đã tham gia.
final myShopsProvider = FutureProvider<List<CustomerShop>>(
  (ref) => ref.watch(customerShopRepositoryProvider).listMyShops(),
);

/// Cửa hàng khách chọn ở C-00; `null` = chưa chọn (dùng cửa hàng đầu tiên).
class SelectedShopNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  void select(int tenantId) => state = tenantId;
}

final selectedShopIdProvider = NotifierProvider<SelectedShopNotifier, int?>(
  SelectedShopNotifier.new,
);

/// Cửa hàng đang xem: cửa hàng đã chọn, hoặc cửa hàng đầu tiên trong danh
/// sách. `null` khi khách chưa tham gia cửa hàng nào. Sản phẩm, điểm,
/// voucher, claim đều đọc theo cửa hàng này.
final currentShopProvider = FutureProvider<CustomerShop?>((ref) async {
  final shops = await ref.watch(myShopsProvider.future);
  final selected = ref.watch(selectedShopIdProvider);
  return shops.where((s) => s.tenantId == selected).firstOrNull ??
      shops.firstOrNull;
});
