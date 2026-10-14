import '../../../core/models/platform.dart';
import '../../../core/network/api_response.dart';

/// Sản phẩm (entity `products`). Mỗi sản phẩm có nhiều SKU (biến thể).
class Product {
  const Product({
    required this.id,
    required this.name,
    this.description,
    this.active = true,
    this.skus = const [],
    this.marketplaceUrls = const {},
  });

  final int id;
  final String name;
  final String? description;

  /// Backend: status ACTIVE | HIDDEN
  final bool active;
  final List<Sku> skus;

  /// URL sản phẩm trên từng sàn (bảng `product_marketplace_links`).
  final Map<Platform, String> marketplaceUrls;

  /// Giá thấp nhất trong các SKU, để hiển thị "Từ 159.000 ₫".
  double? get minPrice => skus.isEmpty
      ? null
      : skus.map((s) => s.basePrice).reduce((a, b) => a < b ? a : b);

  factory Product.fromJson(JsonMap json, {List<Sku> skus = const []}) =>
      Product(
        id: Json.asInt(json['id']) ?? 0,
        name: json['name'] as String? ?? '',
        description: json['description'] as String?,
        active: (json['status'] as String?)?.toUpperCase() != 'HIDDEN',
        skus: skus,
      );

  Product copyWith({List<Sku>? skus}) => Product(
    id: id,
    name: name,
    description: description,
    active: active,
    skus: skus ?? this.skus,
    marketplaceUrls: marketplaceUrls,
  );
}

/// SKU / biến thể (entity `product_skus`).
class Sku {
  const Sku({
    required this.id,
    required this.skuCode,
    required this.basePrice,
    this.variantName,
  });

  final int id;
  final String skuCode;
  final String? variantName;
  final double basePrice;

  factory Sku.fromJson(JsonMap json) => Sku(
    id: Json.asInt(json['id']) ?? 0,
    skuCode: json['skuCode'] as String? ?? '',
    variantName: json['variantName'] as String?,
    basePrice: Json.asDouble(json['basePrice']) ?? 0,
  );
}

/// Dữ liệu tạo sản phẩm - khớp `CreateProductRequest` của backend.
class CreateProductInput {
  const CreateProductInput({
    required this.name,
    this.description,
    required this.skus,
  });

  final String name;
  final String? description;
  final List<CreateSkuInput> skus;

  JsonMap toJson() => {
    'name': name,
    if (description != null) 'description': description,
    'skus': [for (final s in skus) s.toJson()],
  };
}

class CreateSkuInput {
  const CreateSkuInput({
    required this.skuCode,
    required this.basePrice,
    this.variantName,
  });

  final String skuCode;
  final String? variantName;
  final double basePrice;

  JsonMap toJson() => {
    'skuCode': skuCode,
    if (variantName != null) 'variantName': variantName,
    'basePrice': basePrice,
  };
}

/// Mẫu mã SKU của sản phẩm để hiện trên hàng danh sách:
/// ["AT-BASIC-TRANG-M", "AT-BASIC-DEN-M"] -> "AT-BASIC-*". Một SKU thì giữ nguyên.
String skuCodePattern(List<String> codes) {
  if (codes.isEmpty) return '';
  if (codes.length == 1) return codes.first;
  final parts = [for (final c in codes) c.split('-')];
  final common = <String>[];
  for (var i = 0; i < parts.first.length; i++) {
    final seg = parts.first[i];
    if (parts.any((p) => p.length <= i || p[i] != seg)) break;
    common.add(seg);
  }
  return common.isEmpty ? '*' : '${common.join('-')}-*';
}
