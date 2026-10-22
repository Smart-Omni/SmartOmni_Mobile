import '../../inventory/domain/inventory_item.dart';
import 'product.dart';

/// Mức tồn của cả sản phẩm, gộp từ các SKU:
/// - mọi SKU hết hàng -> Hết hàng
/// - có SKU sắp hết hoặc hết -> Sắp hết
/// - không có dữ liệu tồn -> `null` (không hiện nhãn).
StockLevel? productStockLevel(Product product, Iterable<InventoryItem> stock) {
  final ids = {for (final s in product.skus) s.id};
  final levels = [
    for (final item in stock)
      if (ids.contains(item.skuId)) item.level,
  ];
  if (levels.isEmpty) return null;
  if (levels.every((l) => l == StockLevel.out)) return StockLevel.out;
  if (levels.any((l) => l != StockLevel.ok)) return StockLevel.low;
  return StockLevel.ok;
}
