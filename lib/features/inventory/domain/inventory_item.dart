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

  InventoryItem copyWith({int? quantityOnHand}) => InventoryItem(
    skuId: skuId,
    skuCode: skuCode,
    productName: productName,
    variantName: variantName,
    quantityOnHand: quantityOnHand ?? this.quantityOnHand,
    reservedQuantity: reservedQuantity,
  );
}

abstract class InventoryRepository {
  /// ⚠️ Backend CHƯA có API xem danh sách tồn kho -> mock.
  Future<List<InventoryItem>> listInventory();

  /// POST /api/inventory/{skuId}/adjust?quantity=
  /// Lưu ý: backend đặt `quantity` thành số tồn MỚI (không phải cộng/trừ).
  Future<void> setStock({required int skuId, required int newQuantity});
}
