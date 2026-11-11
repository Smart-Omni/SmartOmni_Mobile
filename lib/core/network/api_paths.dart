/// Mọi đường dẫn API của app, đi qua Nginx Gateway (:8080), đều ở `/api/v1`.
/// Chức năng nào gọi API thật thì bật trong
/// `lib/app/config/api_availability.dart`.
abstract final class ApiPaths {
  // Xác thực
  static const login = '/api/v1/auth/login';
  static const logout = '/api/v1/auth/logout';
  static const refresh = '/api/v1/auth/refresh';
  static const register = '/api/v1/auth/register';
  static const forgotPassword = '/api/v1/auth/forgot-password';
  static const resetPassword = '/api/v1/auth/reset-password';
  static const changePassword = '/api/v1/auth/change-password';

  /// Các endpoint không gắn token (khớp `permitAll` trong `SecurityConfig`
  /// của BE). `logout` vẫn gắn token: BE cần header để thu hồi phiên.
  static const public = [
    login,
    register,
    refresh,
    forgotPassword,
    resetPassword,
  ];

  // Tài khoản
  static const usersMe = '/api/v1/users/me';
  static const tenantsMe = '/api/v1/tenants/me';

  // Nhân viên (T-20). Trả `PageResponse` snake_case.
  static const users = '/api/v1/users';
  static String userStatus(int id) => '/api/v1/users/$id/status';

  // Đơn hàng
  static const orders = '/api/v1/orders';
  static String orderStatus(int orderId) => '/api/v1/orders/$orderId/status';
  static const returns = '/api/v1/returns';

  // Sản phẩm
  static const products = '/api/v1/products';
  static String product(int id) => '/api/v1/products/$id';
  static String productSkus(int id) => '/api/v1/products/$id/skus';

  // Tồn kho
  static const inventoryList = '/api/v1/inventory';
  static String inventoryAdjust(int skuId) => '/api/v1/inventory/$skuId/adjust';

  // AI
  static String forecast(int skuId) => '/api/v1/ai/forecast/$skuId';

  // Kết nối sàn
  static const marketplaceConnections = '/api/v1/marketplace-connections';
}
