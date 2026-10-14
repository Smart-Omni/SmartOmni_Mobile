import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/l10n.dart';

/// Khung có thanh điều hướng dưới cho Merchant (Staff + Tenant Admin).
class MerchantShell extends StatelessWidget {
  const MerchantShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _ShellScaffold(
      navigationShell: navigationShell,
      destinations: [
        NavigationDestination(
          icon: const Icon(Icons.dashboard_outlined),
          selectedIcon: const Icon(Icons.dashboard),
          label: l10n.navDashboard,
        ),
        NavigationDestination(
          icon: const Icon(Icons.receipt_long_outlined),
          selectedIcon: const Icon(Icons.receipt_long),
          label: l10n.navOrders,
        ),
        NavigationDestination(
          icon: const Icon(Icons.inventory_2_outlined),
          selectedIcon: const Icon(Icons.inventory_2),
          label: l10n.navProducts,
        ),
        NavigationDestination(
          icon: const Icon(Icons.warehouse_outlined),
          selectedIcon: const Icon(Icons.warehouse),
          label: l10n.navInventory,
        ),
        NavigationDestination(
          icon: const Icon(Icons.menu),
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
      destinations: [
        NavigationDestination(
          icon: const Icon(Icons.storefront_outlined),
          selectedIcon: const Icon(Icons.storefront),
          label: l10n.navHome,
        ),
        NavigationDestination(
          icon: const Icon(Icons.stars_outlined),
          selectedIcon: const Icon(Icons.stars),
          label: l10n.navLoyalty,
        ),
        NavigationDestination(
          icon: const Icon(Icons.qr_code_scanner),
          label: l10n.navClaim,
        ),
        NavigationDestination(
          icon: const Icon(Icons.person_outline),
          selectedIcon: const Icon(Icons.person),
          label: l10n.navAccount,
        ),
      ],
    );
  }
}

class _ShellScaffold extends StatelessWidget {
  const _ShellScaffold({
    required this.navigationShell,
    required this.destinations,
  });

  final StatefulNavigationShell navigationShell;
  final List<NavigationDestination> destinations;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        destinations: destinations,
        // Bấm lại tab đang mở -> quay về màn đầu của tab đó.
        onDestinationSelected: (i) => navigationShell.goBranch(
          i,
          initialLocation: i == navigationShell.currentIndex,
        ),
      ),
    );
  }
}
