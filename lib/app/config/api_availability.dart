import 'app_config.dart';

/// Các chức năng có Remote repository riêng. Chức năng vốn luôn là mock
/// (tem vận đơn, nhân viên, voucher…) không cần nằm ở đây.
enum ApiFeature {
  auth,
  register,
  account,
  staff,
  orders,
  products,
  inventory,
  aiForecast,
  marketplace,

  /// C-20 cho khách: thẻ hạng, lịch sử điểm, voucher. C-30 claim vẫn mock.
  loyalty,

  /// T-40: trạng thái gói, hóa đơn, thanh toán VietQR. Hạn mức vẫn mock (P3).
  subscription,
}

/// Chức năng đã nối được với BE `develop` @ `f9495df` (docs/API_CONTRACT.md
/// mục 0). BE sửa xong chức năng nào thì thêm vào đây là app gọi API thật.
const connectedFeatures = {
  ApiFeature.auth,
  ApiFeature.register,
  ApiFeature.account,
  ApiFeature.staff,
  ApiFeature.products,
  ApiFeature.inventory,
  ApiFeature.orders,
  ApiFeature.aiForecast,
  ApiFeature.marketplace,
  ApiFeature.loyalty,
  ApiFeature.subscription,
};

extension ApiAvailability on AppConfig {
  /// `true`: gọi Remote. `false`: dùng Mock và màn hiện `SoMockBanner`.
  /// Chế độ mock (`useMock = true`) luôn trả `false`.
  bool usesRemote(ApiFeature feature) =>
      !useMock && connectedFeatures.contains(feature);
}
