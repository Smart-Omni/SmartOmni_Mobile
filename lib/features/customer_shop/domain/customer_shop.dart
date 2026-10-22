import '../../loyalty/domain/loyalty_rules.dart';

/// Cửa hàng khách đã tham gia (C-00). Một tài khoản khách dùng được ở nhiều
/// cửa hàng; điểm và hạng tính riêng theo từng cửa hàng.
class CustomerShop {
  const CustomerShop({
    required this.tenantId,
    required this.code,
    required this.name,
    required this.points,
    this.logoUrl,
  });

  final int tenantId;

  /// Mã cửa hàng khách nhập để tham gia, vd. "SHOPDEMO".
  final String code;
  final String name;
  final String? logoUrl;

  /// Điểm tích lũy của khách tại cửa hàng này.
  final int points;

  LoyaltyTier get tier => LoyaltyRules.tierFor(points);
}

/// Thông tin cửa hàng khi xem trước theo mã (trước khi tham gia).
class ShopPreview {
  const ShopPreview({
    required this.tenantId,
    required this.code,
    required this.name,
    this.logoUrl,
  });

  final int tenantId;
  final String code;
  final String name;
  final String? logoUrl;
}

/// Chuẩn hóa mã cửa hàng khách nhập: bỏ dấu cách, viết hoa.
String normalizeShopCode(String input) =>
    input.replaceAll(RegExp(r'\s'), '').toUpperCase();

/// Khách đã tham gia cửa hàng có mã [code] chưa.
bool hasJoined(Iterable<CustomerShop> shops, String code) {
  final c = normalizeShopCode(code);
  return shops.any((s) => s.code == c);
}

/// ⚠️ Backend CHƯA có các API này (docs/API_CONTRACT.md mục 3) -> mock.
abstract class CustomerShopRepository {
  /// GET /api/customer/shops
  Future<List<CustomerShop>> listMyShops();

  /// GET /api/storefront/shops/{shopCode}. Không có thì ném `ApiException`
  /// loại `notFound`.
  Future<ShopPreview> previewShop(String code);

  /// POST /api/customer/shops { shopCode }. Đã tham gia thì ném
  /// `ApiException` loại `validation`.
  Future<CustomerShop> joinShop(String code);
}
