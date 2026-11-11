import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/config/api_availability.dart';
import '../../../app/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../products/domain/product.dart';
import '../../products/presentation/products_providers.dart';
import '../data/inventory_repositories.dart';
import '../domain/inventory_item.dart';

final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  return ref.watch(inventoryUseRemoteProvider)
      ? InventoryRemoteRepository(ref.watch(dioProvider))
      : InventoryMockRepository();
});

/// `false`: M-40 là dữ liệu mẫu, màn hiện `SoMockBanner`.
final inventoryUseRemoteProvider = Provider<bool>(
  (ref) => ref.watch(appConfigProvider).usesRemote(ApiFeature.inventory),
);

/// Tồn từng SKU. BE thật: dùng chung danh sách sản phẩm của M-30 (không tải
/// lại) để ghép mã SKU, tên sản phẩm.
final inventoryListProvider = FutureProvider.autoDispose<List<InventoryItem>>((
  ref,
) async {
  final products = ref.watch(inventoryUseRemoteProvider)
      ? await ref.watch(productsListProvider.future)
      : const <Product>[];
  return ref.watch(inventoryRepositoryProvider).listInventory(products);
});

/// Tải lại tồn kho cùng danh sách sản phẩm nó ghép vào. Sản phẩm lỗi thì tồn
/// kho lỗi theo; chỉ tải lại tồn kho sẽ nhận lại đúng lỗi cũ (app không tự
/// thử lại).
void reloadInventory(WidgetRef ref) => ref
  ..invalidate(productsListProvider)
  ..invalidate(inventoryListProvider);
