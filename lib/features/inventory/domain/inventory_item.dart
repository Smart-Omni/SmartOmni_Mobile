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
    this.availableQuantity,
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

  /// Số có thể bán BE tính sẵn (`InventoryItemDto.availableQuantity`).
  /// `null` (mock) thì tự tính.
  final int? availableQuantity;

  /// Có thể bán = tồn thực tế - đang giữ chỗ.
  int get available => availableQuantity ?? quantityOnHand - reservedQuantity;

  bool get isOutOfStock => available <= 0;

  bool get isLow => !isOutOfStock && available <= lowStockThreshold;

  StockLevel get level => isOutOfStock
      ? StockLevel.out
      : isLow
      ? StockLevel.low
      : StockLevel.ok;

  /// Đổi tồn thì bỏ [availableQuantity] của BE (đã cũ), tự tính lại.
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
  /// Tồn từng SKU. Remote: `GET /api/v1/inventory`, ghép tên biến thể từ
  /// [products]. Mock: bỏ qua [products].
  Future<List<InventoryItem>> listInventory(List<Product> products);

  /// POST /api/v1/inventory/{skuId}/adjust?quantity=
  /// Lưu ý: backend đặt `quantity` thành số tồn MỚI (không phải cộng/trừ).
  Future<void> setStock({required int skuId, required int newQuantity});
}

/// Một dòng `InventoryItemDto` của BE (camelCase). BE trả đủ SKU của
/// tenant (SKU chưa đặt tồn: tồn 0), sắp theo `skuId`.
class InventoryRow {
  const InventoryRow({
    required this.skuId,
    required this.quantityOnHand,
    required this.reservedQuantity,
    this.skuCode,
    this.productName,
    this.availableQuantity,
  });

  factory InventoryRow.fromJson(JsonMap json) => InventoryRow(
    skuId: Json.asInt(json['skuId']) ?? 0,
    skuCode: json['skuCode'] as String?,
    productName: json['productName'] as String?,
    quantityOnHand: Json.asInt(json['quantityOnHand']) ?? 0,
    reservedQuantity: Json.asInt(json['reservedQuantity']) ?? 0,
    availableQuantity: Json.asInt(json['availableQuantity']),
  );

  final int skuId;
  final String? skuCode;
  final String? productName;
  final int quantityOnHand;
  final int reservedQuantity;

  /// BE tính sẵn: `max(0, tồn − giữ chỗ)`.
  final int? availableQuantity;
}

/// Dòng tồn của BE thành [InventoryItem], giữ thứ tự BE. Mã SKU, tên sản
/// phẩm, số có thể bán đọc thẳng từ BE; tên biến thể (BE không trả) lấy từ
/// [products] nếu tìm thấy SKU. Thiếu cả hai thì tên là `SKU #<id>`.
List<InventoryItem> buildInventoryItems(
  List<InventoryRow> rows,
  List<Product> products,
) {
  final skus = {
    for (final p in products)
      for (final s in p.skus) s.id: (product: p, sku: s),
  };
  return [
    for (final r in rows)
      InventoryItem(
        skuId: r.skuId,
        skuCode: r.skuCode ?? skus[r.skuId]?.sku.skuCode ?? '',
        productName:
            r.productName ?? skus[r.skuId]?.product.name ?? 'SKU #${r.skuId}',
        variantName: skus[r.skuId]?.sku.variantName,
        quantityOnHand: r.quantityOnHand,
        reservedQuantity: r.reservedQuantity,
        availableQuantity: r.availableQuantity,
      ),
  ];
}
