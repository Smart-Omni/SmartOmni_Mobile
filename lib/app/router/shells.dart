import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/design/design.dart';
import '../../l10n/l10n.dart';

/// Khung có thanh điều hướng dưới cho Merchant (Staff + Tenant Admin):
/// Tổng quan · Đơn hàng · Sản phẩm · Tồn kho · Thêm.
class MerchantShell extends StatelessWidget {
  const MerchantShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _ShellScaffold(
      navigationShell: navigationShell,
      items: [
        SoNavItem(
          key: const Key('nav_dashboard'),
          icon: LucideIcons.layoutDashboard,
          label: l10n.navDashboard,
        ),
        SoNavItem(
          key: const Key('nav_orders'),
          icon: LucideIcons.receiptText,
          label: l10n.navOrders,
        ),
        SoNavItem(
          key: const Key('nav_products'),
          icon: LucideIcons.box,
          label: l10n.navProducts,
        ),
        SoNavItem(
          key: const Key('nav_inventory'),
          icon: LucideIcons.warehouse,
          label: l10n.navInventory,
        ),
        SoNavItem(
          key: const Key('nav_more'),
          icon: LucideIcons.ellipsis,
          label: l10n.navMore,
        ),
      ],
    );
  }
}

/// Khung có thanh điều hướng dưới cho Customer.
class CustomerShell extends StatelessWidget {
  const CustomerShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _ShellScaffold(
      navigationShell: navigationShell,
      items: [
        SoNavItem(icon: LucideIcons.store, label: l10n.navHome),
        SoNavItem(icon: LucideIcons.star, label: l10n.navLoyalty),
        SoNavItem(icon: LucideIcons.scanLine, label: l10n.navClaim),
        SoNavItem(icon: LucideIcons.user, label: l10n.navAccount),
      ],
    );
  }
}

class _ShellScaffold extends StatelessWidget {
  const _ShellScaffold({required this.navigationShell, required this.items});

  final StatefulNavigationShell navigationShell;
  final List<SoNavItem> items;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: SoBottomNav(
        items: items,
        currentIndex: navigationShell.currentIndex,
        // Bấm lại tab đang mở -> quay về màn đầu của tab đó.
        onTap: (i) => navigationShell.goBranch(
          i,
          initialLocation: i == navigationShell.currentIndex,
        ),
      ),
    );
  }
}
