import '../../../core/network/api_exception.dart';
import '../../../core/utils/mock_delay.dart';
import '../domain/customer_shop.dart';

/// Mock: khách demo đã tham gia 2 cửa hàng; còn 1 mã ("BEPXINH") để thử
/// tham gia thêm.
class CustomerShopMockRepository implements CustomerShopRepository {
  final List<CustomerShop> _joined = [
    const CustomerShop(
      tenantId: 1,
      code: 'SHOPDEMO',
      name: 'Shop Demo',
      points: 620,
    ),
    const CustomerShop(
      tenantId: 2,
      code: 'HOAMOC',
      name: 'Hoa Mộc Cosmetics',
      points: 120,
    ),
  ];

  /// Mọi cửa hàng có trên hệ thống (xem trước được bằng mã).
  static const _all = [
    ShopPreview(tenantId: 1, code: 'SHOPDEMO', name: 'Shop Demo'),
    ShopPreview(tenantId: 2, code: 'HOAMOC', name: 'Hoa Mộc Cosmetics'),
    ShopPreview(tenantId: 3, code: 'BEPXINH', name: 'Bếp Xinh'),
  ];

  @override
  Future<List<CustomerShop>> listMyShops() async {
    await MockDelay.short();
    return List.unmodifiable(_joined);
  }

  @override
  Future<ShopPreview> previewShop(String code) async {
    await MockDelay.short();
    final c = normalizeShopCode(code);
    return _all.firstWhere(
      (s) => s.code == c,
      orElse: () => throw const ApiException(
        type: ApiErrorType.notFound,
        message: 'Không tìm thấy cửa hàng với mã này.',
      ),
    );
  }

  @override
  Future<CustomerShop> joinShop(String code) async {
    final preview = await previewShop(code);
    if (hasJoined(_joined, preview.code)) {
      throw const ApiException(
        type: ApiErrorType.validation,
        message: 'Bạn đã tham gia cửa hàng này.',
      );
    }
    final shop = CustomerShop(
      tenantId: preview.tenantId,
      code: preview.code,
      name: preview.name,
      logoUrl: preview.logoUrl,
      points: 0,
    );
    _joined.add(shop);
    return shop;
  }
}
