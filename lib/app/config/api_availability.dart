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
}

/// Chức năng đã nối được với BE `develop` @ `d4ea062` (docs/API_CONTRACT.md
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
};

extension ApiAvailability on AppConfig {
  /// `true`: gọi Remote. `false`: dùng Mock và màn hiện `SoMockBanner`.
  /// Chế độ mock (`useMock = true`) luôn trả `false`.
  bool usesRemote(ApiFeature feature) =>
      !useMock && connectedFeatures.contains(feature);
}
