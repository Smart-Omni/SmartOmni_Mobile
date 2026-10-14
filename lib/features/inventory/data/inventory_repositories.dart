import 'package:dio/dio.dart';

import '../../../core/mock/mock_data.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/mock_delay.dart';
import '../domain/inventory_item.dart';

class InventoryRemoteRepository implements InventoryRepository {
  InventoryRemoteRepository(this._dio, this._fallback);

  final Dio _dio;
  final InventoryRepository _fallback;

  @override
  Future<List<InventoryItem>> listInventory() => _fallback.listInventory();

  @override
  Future<void> setStock({required int skuId, required int newQuantity}) async {
    try {
      await _dio.post<Object?>(
        '/api/inventory/$skuId/adjust',
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
  Future<List<InventoryItem>> listInventory() async {
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
