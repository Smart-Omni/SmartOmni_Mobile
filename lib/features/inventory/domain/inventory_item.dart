import '../../../core/network/api_response.dart';
import '../../products/domain/product.dart';

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

  /// Mã để hiện: SKU không khớp sản phẩm nào (mã rỗng) thì `SKU #<id>`.
  String get displayCode => skuCode.isEmpty ? 'SKU #$skuId' : skuCode;

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
  /// Tồn từng SKU. Remote: `GET /api/v1/inventory` ghép với [products]
  /// (lấy mã SKU, tên sản phẩm). Mock: bỏ qua [products].
  Future<List<InventoryItem>> listInventory(List<Product> products);

  /// POST /api/v1/inventory/{skuId}/adjust?quantity=
  /// Lưu ý: backend đặt `quantity` thành số tồn MỚI (không phải cộng/trừ).
  Future<void> setStock({required int skuId, required int newQuantity});
}

/// Một dòng entity `Inventory` của BE (camelCase).
class InventoryRow {
  const InventoryRow({
    required this.skuId,
    required this.quantityOnHand,
    required this.reservedQuantity,
  });

  factory InventoryRow.fromJson(JsonMap json) => InventoryRow(
    skuId: Json.asInt(json['skuId']) ?? 0,
    quantityOnHand: Json.asInt(json['quantityOnHand']) ?? 0,
    reservedQuantity: Json.asInt(json['reservedQuantity']) ?? 0,
  );

  final int skuId;
  final int quantityOnHand;
  final int reservedQuantity;
}

/// Ghép dòng tồn của BE với SKU của [products] (theo thứ tự sản phẩm):
/// - SKU chưa có dòng tồn (BE chỉ tạo dòng khi đặt tồn lần đầu) vẫn hiện với
///   tồn 0 / giữ 0, để đặt tồn được ngay.
/// - Dòng tồn không khớp SKU nào: tên `SKU #<id>`, không có mã SKU.
List<InventoryItem> buildInventoryItems(
  List<InventoryRow> rows,
  List<Product> products,
) {
  final bySku = {for (final r in rows) r.skuId: r};
  final known = <int>{};
  return [
    for (final p in products)
      for (final sku in p.skus)
        if (known.add(sku.id))
          InventoryItem(
            skuId: sku.id,
            skuCode: sku.skuCode,
            productName: p.name,
            variantName: sku.variantName,
            quantityOnHand: bySku[sku.id]?.quantityOnHand ?? 0,
            reservedQuantity: bySku[sku.id]?.reservedQuantity ?? 0,
          ),
    for (final r in rows)
      if (!known.contains(r.skuId))
        InventoryItem(
          skuId: r.skuId,
          skuCode: '',
          productName: 'SKU #${r.skuId}',
          quantityOnHand: r.quantityOnHand,
          reservedQuantity: r.reservedQuantity,
        ),
  ];
}
