import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_controller.dart';
import '../data/customer_shop_mock_repository.dart';
import '../domain/customer_shop.dart';

/// Backend chưa có API -> luôn dùng mock, kể cả khi USE_MOCK=false.
/// Tạo lại theo từng phiên đăng nhập (đăng xuất rồi vào lại, kể cả cùng tài
/// khoản, là phiên mới), để danh sách cửa hàng và mọi provider đọc theo nó
/// không mang sang tài khoản khác trên cùng máy.
final customerShopRepositoryProvider = Provider<CustomerShopRepository>((ref) {
  ref.watch(currentSessionProvider);
  return CustomerShopMockRepository();
});

/// Các cửa hàng khách đã tham gia.
final myShopsProvider = FutureProvider<List<CustomerShop>>(
  (ref) => ref.watch(customerShopRepositoryProvider).listMyShops(),
);

/// Cửa hàng khách chọn ở C-00; `null` = chưa chọn (dùng cửa hàng đầu tiên).
class SelectedShopNotifier extends Notifier<int?> {
  @override
  int? build() {
    // Phiên đăng nhập mới thì bỏ lựa chọn cũ.
    ref.watch(currentSessionProvider);
    return null;
  }

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
