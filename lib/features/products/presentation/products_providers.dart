import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/config/api_availability.dart';
import '../../../app/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../inventory/presentation/inventory_providers.dart';
import '../data/products_repositories.dart';
import '../domain/product.dart';
import '../domain/products_repository.dart';

final productsRepositoryProvider = Provider<ProductsRepository>((ref) {
  return ref.watch(productsUseRemoteProvider)
      ? ProductsRemoteRepository(ref.watch(dioProvider))
      : ProductsMockRepository();
});

/// `false`: M-30/31/32 là dữ liệu mẫu, màn hiện `SoMockBanner`.
final productsUseRemoteProvider = Provider<bool>(
  (ref) => ref.watch(appConfigProvider).usesRemote(ApiFeature.products),
);

/// Nhãn hết / sắp hết ở M-30, M-31. Sản phẩm thật mà tồn kho còn mẫu thì
/// `skuId` không khớp nhau: ẩn nhãn để không hiện số tồn sai.
final showStockLabelsProvider = Provider<bool>(
  (ref) =>
      !ref.watch(productsUseRemoteProvider) ||
      ref.watch(inventoryUseRemoteProvider),
);

final productsListProvider = FutureProvider.autoDispose<List<Product>>(
  (ref) => ref.watch(productsRepositoryProvider).listProducts(),
);

final productDetailProvider = FutureProvider.autoDispose.family<Product, int>(
  (ref, id) => ref.watch(productsRepositoryProvider).getProduct(id),
);
