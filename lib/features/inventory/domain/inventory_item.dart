/// Mức tồn để hiển thị: Hết hàng (có thể bán ≤ 0), Sắp hết (≤ 5), Còn hàng.
enum StockLevel { ok, low, out }

/// Tồn kho của một SKU (entity `inventory`).
class InventoryItem {
  const InventoryItem({
    required this.skuId,
    required this.skuCode,
    required this.productName,
    required this.quantityOnHand,
    this.reservedQuantity = 0,
    this.variantName,
  });

  /// Ngưỡng cảnh báo sắp hết hàng (tạm đặt cứng; sau này lấy từ cấu hình/AI).
  static const lowStockThreshold = 5;

  final int skuId;
  final String skuCode;
  final String productName;
  final String? variantName;
  final int quantityOnHand;
  final int reservedQuantity;

  /// Có thể bán = tồn thực tế - đang giữ chỗ.
  int get available => quantityOnHand - reservedQuantity;

  bool get isOutOfStock => available <= 0;

  bool get isLow => !isOutOfStock && available <= lowStockThreshold;

  StockLevel get level => isOutOfStock
      ? StockLevel.out
      : isLow
      ? StockLevel.low
      : StockLevel.ok;

  InventoryItem copyWith({int? quantityOnHand}) => InventoryItem(
    skuId: skuId,
    skuCode: skuCode,
    productName: productName,
    variantName: variantName,
    quantityOnHand: quantityOnHand ?? this.quantityOnHand,
    reservedQuantity: reservedQuantity,
  );
}

/// Bộ lọc của M-40.
enum InventoryFilter {
  all('Tất cả'),
  attention('Cần chú ý'),
  out('Hết hàng');

  const InventoryFilter(this.label);

  final String label;

  /// "Cần chú ý" gồm cả sắp hết và hết hàng.
  bool matches(InventoryItem item) => switch (this) {
    InventoryFilter.all => true,
    InventoryFilter.attention => item.level != StockLevel.ok,
    InventoryFilter.out => item.level == StockLevel.out,
  };
}

/// Tổng toàn kho cho thẻ StockMeter đầu M-40.
({int onHand, int reserved}) inventoryTotals(Iterable<InventoryItem> items) {
  var onHand = 0;
  var reserved = 0;
  for (final i in items) {
    onHand += i.quantityOnHand;
    reserved += i.reservedQuantity;
  }
  return (onHand: onHand, reserved: reserved);
}

abstract class InventoryRepository {
  /// ⚠️ Backend CHƯA có API xem danh sách tồn kho -> mock.
  Future<List<InventoryItem>> listInventory();

  /// POST /api/inventory/{skuId}/adjust?quantity=
  /// Lưu ý: backend đặt `quantity` thành số tồn MỚI (không phải cộng/trừ).
  Future<void> setStock({required int skuId, required int newQuantity});
}
