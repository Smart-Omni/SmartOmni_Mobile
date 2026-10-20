import '../../../core/network/api_exception.dart';
import '../../../core/utils/mock_delay.dart';
import '../domain/customer_shop.dart';

/// Mock: khách demo đã tham gia 2 cửa hàng; còn 1 mã ("BEPXINH") để thử
/// tham gia thêm. Tài khoản đăng ký mới ([joinedCodes]) chỉ có cửa hàng đã
/// chọn khi đăng ký, 0 điểm.
class CustomerShopMockRepository implements CustomerShopRepository {
  CustomerShopMockRepository({List<String>? joinedCodes})
    : _joined = joinedCodes == null
          ? [..._demoJoined]
          : [
              for (final s in all)
                if (joinedCodes.contains(s.code))
                  CustomerShop(
                    tenantId: s.tenantId,
                    code: s.code,
                    name: s.name,
                    points: 0,
                  ),
            ];

  final List<CustomerShop> _joined;

  static const _demoJoined = [
    CustomerShop(tenantId: 1, code: 'SHOPDEMO', name: 'Shop Demo', points: 620),
    CustomerShop(
      tenantId: 2,
      code: 'HOAMOC',
      name: 'Hoa Mộc Cosmetics',
      points: 120,
    ),
  ];

  /// Mọi cửa hàng có trên hệ thống (xem trước được bằng mã).
  static const all = [
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
    return all.firstWhere(
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
