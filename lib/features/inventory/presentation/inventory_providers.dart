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
