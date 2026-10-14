import '../../core/auth/user_role.dart';
import '../../features/auth/presentation/auth_controller.dart';

/// Toàn bộ đường dẫn (route) của app ở một chỗ để tránh gõ sai.
///
/// - `/m/...` : khu vực Merchant (Staff + Tenant Admin)
/// - `/c/...` : khu vực Customer
class Routes {
  const Routes._();

  // Chung
  static const splash = '/splash';
  static const login = '/login';
  static const forgotPassword = '/forgot-password';
  static const resetPassword = '/reset-password';

  // Merchant - các tab (nằm trong bottom navigation)
  static const merchantDashboard = '/m/dashboard';
  static const merchantOrders = '/m/orders';
  static const merchantProducts = '/m/products';
  static const merchantInventory = '/m/inventory';
  static const merchantMore = '/m/more';

  // Merchant - màn hình con (mở toàn màn hình, che bottom navigation)
  static const merchantOrderDetail = '/m/order-detail';
  static const merchantProductCreate = '/m/product-new';
  static String merchantProductDetail(int id) => '/m/product/$id';
  static const merchantAi = '/m/ai';
  static String merchantAiForecast(int skuId) => '/m/ai/$skuId';
  static const merchantMarketplace = '/m/marketplace';

  // Customer - các tab
  static const customerShop = '/c/shop';
  static const customerLoyalty = '/c/loyalty';
  static const customerClaim = '/c/claim';
  static const customerAccount = '/c/account';

  // Customer - màn hình con
  static String customerProduct(int id) => '/c/product/$id';

  // Chỉ có ở bản dev (flavor dev)
  static const devPrefix = '/dev/';
  static const devGallery = '/dev/gallery';

  /// Route chỉ Tenant Admin được vào.
  static const tenantAdminOnly = [merchantMarketplace];

  /// Trang chủ theo role sau khi đăng nhập.
  static String homeFor(UserRole role) =>
      role.isCustomer ? customerShop : merchantDashboard;
}

/// Quyết định chuyển hướng dựa trên trạng thái đăng nhập + role.
///
/// Trả về `null` nếu được phép ở lại [location]. Tách thành hàm thuần (pure
/// function) để viết unit test dễ dàng (xem test/app/routes_test.dart).
///
/// [allowDevRoutes]: `true` ở bản dev, cho vào `/dev/...` (vd. gallery) mà
/// không cần đăng nhập. Bản khác: coi `/dev/...` như route không tồn tại.
String? resolveRedirect(
  AuthState auth,
  String location, {
  bool allowDevRoutes = false,
}) {
  const publicRoutes = [
    Routes.login,
    Routes.forgotPassword,
    Routes.resetPassword,
  ];

  if (location.startsWith(Routes.devPrefix)) {
    if (allowDevRoutes) return null;
    return switch (auth) {
      Authenticated(:final session) => Routes.homeFor(session.role),
      AuthUnknown() => Routes.splash,
      Unauthenticated() => Routes.login,
    };
  }

  switch (auth) {
    case AuthUnknown():
      return location == Routes.splash ? null : Routes.splash;

    case Unauthenticated():
      return publicRoutes.contains(location) ? null : Routes.login;

    case Authenticated(:final session):
      final role = session.role;
      final home = Routes.homeFor(role);

      if (location == Routes.splash ||
          location == '/' ||
          publicRoutes.contains(location)) {
        return home;
      }
      // Không cho Customer vào khu Merchant và ngược lại.
      if (role.isCustomer && location.startsWith('/m/')) return home;
      if (role.isMerchant && location.startsWith('/c/')) return home;
      // Chức năng chỉ dành cho Tenant Admin.
      if (role != UserRole.tenantAdmin &&
          Routes.tenantAdminOnly.any(location.startsWith)) {
        return Routes.merchantMore;
      }
      return null;
  }
}
