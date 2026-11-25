import '../models/platform.dart';

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

  // Gói dịch vụ (T-40, tenant-service). BE lấy tenant từ JWT.
  static const _subscription = '/api/v1/tenants/subscription';
  static const subscriptionStatus = '$_subscription/status';
  static const subscriptionInvoices = '$_subscription/invoices';
  static const subscriptionCheckout = '$_subscription/checkout';
  static String subscriptionOrderStatus(String orderCode) =>
      '$_subscription/orders/${Uri.encodeComponent(orderCode)}/status';

  /// Chỉ bản dev (lỗi P1: BE mở cho mọi user).
  static String subscriptionSimulatePay(String orderCode) =>
      '$_subscription/orders/${Uri.encodeComponent(orderCode)}/simulate-pay';

  // Nhân viên (T-20). Trả `PageResponse` snake_case.
  static const users = '/api/v1/users';
  static String userStatus(int id) => '/api/v1/users/$id/status';

  // Đơn hàng
  static const orders = '/api/v1/orders';
  static String order(int orderId) => '/api/v1/orders/$orderId';
  static String orderStatus(int orderId) => '/api/v1/orders/$orderId/status';
  static const returns = '/api/v1/returns';

  // Sản phẩm
  static const products = '/api/v1/products';
  static String product(int id) => '/api/v1/products/$id';
  static String productSkus(int id) => '/api/v1/products/$id/skus';

  /// SKU của nhiều sản phẩm một lần: `?productIds=1,2,3`.
  static const productSkusBatch = '/api/v1/products/skus';

  // Tồn kho
  static const inventoryList = '/api/v1/inventory';
  static String inventoryAdjust(int skuId) => '/api/v1/inventory/$skuId/adjust';

  // AI
  static String forecast(int skuId) => '/api/v1/ai/forecast/$skuId';

  // Điểm & hạng của khách (C-20, chỉ role CUSTOMER). BE lấy tenant và
  // khách từ JWT, không cần header `X-Tenant-Id`.
  static const loyaltyMe = '/api/v1/loyalty/me';
  static const loyaltyMyClaims = '/api/v1/loyalty/me/claims';
  static const loyaltyMyVouchers = '/api/v1/loyalty/me/vouchers';

  // Kết nối sàn: chỉ OAuth (BE `9558375` bỏ `POST /marketplace-connections`
  // bằng App Key).

  /// Trạng thái kết nối một sàn (`ShopeeConnectionDto` / `TiktokConnectionDto`).
  static String marketplaceConnection(Platform p) =>
      '/api/v1/marketplace-connections/${_slug(p)}';
  static String marketplaceAuthorization(Platform p) =>
      '${marketplaceConnection(p)}/authorization';
  static String marketplaceCallback(Platform p) =>
      '${marketplaceConnection(p)}/callback';
  static String marketplaceDisconnect(Platform p) =>
      '${marketplaceConnection(p)}/disconnect';

  /// Chỉ Shopee có (`UpdateShopeeSettingsRequest`).
  static const shopeeSettings =
      '/api/v1/marketplace-connections/shopee/settings';

  static String _slug(Platform p) => switch (p) {
    Platform.shopee => 'shopee',
    Platform.tiktokShop => 'tiktok-shop',
  };
}
