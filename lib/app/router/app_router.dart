import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/account/presentation/customer_account_screen.dart';
import '../../features/ai_insights/presentation/ai_screens.dart';
import '../../features/auth/presentation/auth_controller.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/reset_password_screen.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/dev_gallery/presentation/design_gallery_screen.dart';
import '../../features/inventory/presentation/inventory_screen.dart';
import '../../features/loyalty/presentation/claim_order_screen.dart';
import '../../features/loyalty/presentation/loyalty_screen.dart';
import '../../features/marketplace/presentation/marketplace_screen.dart';
import '../../features/merchant_more/presentation/merchant_more_screen.dart';
import '../../features/orders/domain/order.dart';
import '../../features/orders/presentation/order_detail_screen.dart';
import '../../features/orders/presentation/orders_screen.dart';
import '../../features/products/presentation/product_create_screen.dart';
import '../../features/products/presentation/product_detail_screen.dart';
import '../../features/products/presentation/products_screen.dart';
import '../../features/storefront/presentation/storefront_screens.dart';
import '../config/app_config.dart';
import 'routes.dart';
import 'shells.dart';

final _rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');

/// Router của app. Tự chuyển trang khi trạng thái đăng nhập thay đổi.
final routerProvider = Provider<GoRouter>((ref) {
  // Cầu nối Riverpod -> go_router: mỗi khi AuthState đổi, router chạy lại redirect.
  final authListenable = ValueNotifier<AuthState>(
    ref.read(authControllerProvider),
  );
  ref.listen(authControllerProvider, (_, next) => authListenable.value = next);
  ref.onDispose(authListenable.dispose);
  final isDev = ref.read(appConfigProvider).flavor == Flavor.dev;

  final router = GoRouter(
    navigatorKey: _rootKey,
    initialLocation: Routes.splash,
    refreshListenable: authListenable,
    redirect: (context, state) => resolveRedirect(
      authListenable.value,
      state.matchedLocation,
      allowDevRoutes: isDev,
    ),
    routes: [
      GoRoute(path: Routes.splash, builder: (_, _) => const SplashScreen()),
      GoRoute(path: Routes.login, builder: (_, _) => const LoginScreen()),
      GoRoute(
        path: Routes.forgotPassword,
        builder: (_, _) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: Routes.resetPassword,
        builder: (_, _) => const ResetPasswordScreen(),
      ),

      // ------------------------------------------------ Merchant (Staff + Admin)
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => MerchantShell(navigationShell: shell),
        branches: [
          _branch(Routes.merchantDashboard, const DashboardScreen()),
          _branch(Routes.merchantOrders, const OrdersScreen()),
          _branch(Routes.merchantProducts, const ProductsScreen()),
          _branch(Routes.merchantInventory, const InventoryScreen()),
          _branch(Routes.merchantMore, const MerchantMoreScreen()),
        ],
      ),
      GoRoute(
        path: Routes.merchantOrderDetail,
        builder: (_, state) => OrderDetailScreen(order: state.extra! as Order),
        // Mở lại app ở route này mà mất `extra` -> quay về danh sách.
        redirect: (_, state) =>
            state.extra is Order ? null : Routes.merchantOrders,
      ),
      GoRoute(
        path: Routes.merchantProductCreate,
        builder: (_, _) => const ProductCreateScreen(),
      ),
      GoRoute(
        path: '/m/product/:id',
        builder: (_, state) =>
            ProductDetailScreen(productId: _intParam(state, 'id')),
      ),
      GoRoute(
        path: Routes.merchantAi,
        builder: (context, _) => AiInsightsScreen(
          onOpenSku: (skuId) => context.push(Routes.merchantAiForecast(skuId)),
        ),
      ),
      GoRoute(
        path: '/m/ai/:skuId',
        builder: (_, state) =>
            SkuForecastScreen(skuId: _intParam(state, 'skuId')),
      ),
      GoRoute(
        path: Routes.merchantMarketplace,
        builder: (_, _) => const MarketplaceScreen(),
      ),

      // --------------------------------------------------------------- Customer
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => CustomerShell(navigationShell: shell),
        branches: [
          _branch(Routes.customerShop, const StorefrontScreen()),
          _branch(Routes.customerLoyalty, const LoyaltyScreen()),
          _branch(Routes.customerClaim, const ClaimOrderScreen()),
          _branch(Routes.customerAccount, const CustomerAccountScreen()),
        ],
      ),
      GoRoute(
        path: '/c/product/:id',
        builder: (_, state) =>
            StorefrontProductScreen(productId: _intParam(state, 'id')),
      ),

      // ------------------------------------------------------- Chỉ bản dev
      if (isDev)
        GoRoute(
          path: Routes.devGallery,
          builder: (_, _) => const DesignGalleryScreen(),
        ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

StatefulShellBranch _branch(String path, Widget screen) => StatefulShellBranch(
  routes: [GoRoute(path: path, builder: (_, _) => screen)],
);

int _intParam(GoRouterState state, String name) =>
    int.tryParse(state.pathParameters[name] ?? '') ?? 0;
