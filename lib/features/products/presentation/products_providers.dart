import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../data/products_repositories.dart';
import '../domain/product.dart';
import '../domain/products_repository.dart';

final productsRepositoryProvider = Provider<ProductsRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  final mock = ProductsMockRepository();
  return config.useMock
      ? mock
      : ProductsRemoteRepository(ref.watch(dioProvider), mock);
});

final productsListProvider = FutureProvider.autoDispose<List<Product>>(
  (ref) => ref.watch(productsRepositoryProvider).listProducts(),
);

final productDetailProvider = FutureProvider.autoDispose.family<Product, int>(
  (ref, id) => ref.watch(productsRepositoryProvider).getProduct(id),
);
