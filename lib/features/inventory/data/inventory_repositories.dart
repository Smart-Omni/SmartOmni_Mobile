import 'package:dio/dio.dart';

import '../../../core/mock/mock_data.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/api_paths.dart';
import '../../../core/network/api_response.dart';
import '../../../core/utils/mock_delay.dart';
import '../../products/domain/product.dart';
import '../domain/inventory_item.dart';

/// Inventory Service. BE trả thẳng entity `Inventory` (chỉ `skuId` và số
/// lượng); mã SKU, tên sản phẩm ghép từ danh sách sản phẩm.
class InventoryRemoteRepository implements InventoryRepository {
  InventoryRemoteRepository(this._dio);

  final Dio _dio;

  @override
  Future<List<InventoryItem>> listInventory(List<Product> products) async {
    try {
      // shortcut: chỉ tải trang đầu 500 dòng tồn.
      final res = await _dio.get<Object?>(
        ApiPaths.inventoryList,
        queryParameters: {'page': 0, 'size': 500, 'sort': 'skuId,asc'},
      );
      final rows = unwrapResponse<List<InventoryRow>>(
        res.data,
        (data) => PageResult.fromJson(data, InventoryRow.fromJson).items,
      );
      return buildInventoryItems(rows, products);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  @override
  Future<void> setStock({required int skuId, required int newQuantity}) async {
    try {
      await _dio.post<Object?>(
        ApiPaths.inventoryAdjust(skuId),
        queryParameters: {'quantity': newQuantity},
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

class InventoryMockRepository implements InventoryRepository {
  InventoryMockRepository() : _items = _seed();

  final List<InventoryItem> _items;

  static List<InventoryItem> _seed() => [
    for (final (_, name, _, skus, _, _) in MockData.products)
      for (final (skuId, code, variant, _) in skus)
        InventoryItem(
          skuId: skuId,
          skuCode: code,
          productName: name,
          variantName: variant,
          quantityOnHand: MockData.inventory[skuId]?.$1 ?? 0,
          reservedQuantity: MockData.inventory[skuId]?.$2 ?? 0,
        ),
  ];

  @override
  Future<List<InventoryItem>> listInventory(List<Product> products) async {
    await MockDelay.short();
    return List.unmodifiable(_items);
  }

  @override
  Future<void> setStock({required int skuId, required int newQuantity}) async {
    await MockDelay.short();
    final i = _items.indexWhere((e) => e.skuId == skuId);
    if (i >= 0) _items[i] = _items[i].copyWith(quantityOnHand: newQuantity);
  }
}
