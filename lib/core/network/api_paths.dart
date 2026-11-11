/// Mọi đường dẫn API của app, đi qua Nginx Gateway (:8080).
///
/// Đơn, hoàn/trả, sản phẩm, tồn kho, AI, kết nối sàn: controller BE vẫn nhận
/// `/api/...` trong khi Nginx chỉ cho qua `/api/v1/...` (docs/API_CONTRACT.md
/// mục 0). BE chuyển xong thì sửa đường dẫn ở đây rồi bật chức năng trong
/// `lib/app/config/api_availability.dart`.
abstract final class ApiPaths {
  // Xác thực
  static const login = '/api/v1/auth/login';
  static const logout = '/api/v1/auth/logout';
  static const refresh = '/api/v1/auth/refresh';
  static const register = '/api/v1/auth/register';
  static const forgotPassword = '/api/v1/auth/forgot-password';
  static const resetPassword = '/api/v1/auth/reset-password';

  /// Các endpoint không gắn token (khớp `permitAll` trong `SecurityConfig`
  /// của BE). `logout` vẫn gắn token: BE cần header để thu hồi phiên.
  static const public = [
    login,
    register,
    refresh,
    forgotPassword,
    resetPassword,
  ];

  // Đơn hàng
  static const orders = '/api/orders';
  static String orderStatus(int orderId) => '/api/orders/$orderId/status';
  static const returns = '/api/returns';

  // Sản phẩm
  static const products = '/api/products';
  static String product(int id) => '/api/products/$id';
  static String productSkus(int id) => '/api/products/$id/skus';

  // Tồn kho
  static String inventoryAdjust(int skuId) => '/api/inventory/$skuId/adjust';

  // AI
  static String forecast(int skuId) => '/api/ai/forecast/$skuId';

  // Kết nối sàn
  static const marketplaceConnections = '/api/marketplace-connections';
}
