import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/router/routes.dart';
import '../../../core/design/design.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../customer_shop/domain/customer_shop.dart';
import '../../customer_shop/presentation/customer_shop_providers.dart';
import '../../customer_shop/presentation/customer_shops_screen.dart';
import 'account_widgets.dart';

/// C-40 Tài khoản của khách (DESIGN.md mục 8b): thẻ hồ sơ, nhóm "Cửa hàng
/// đã tham gia" (+ Thêm), nhóm "Cài đặt", Đăng xuất.
class CustomerAccountScreen extends StatelessWidget {
  const CustomerAccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SoScaffold(
      appBar: const SoAppBar.root(title: 'Tài khoản'),
      slivers: [
        SliverPadding(
          padding: SoSpace.page,
          sliver: SliverList.list(
            children: const [
              _CustomerProfileCard(),
              _JoinedShops(),
              GroupTitle('Cài đặt'),
              SoListGroup(
                children: [
                  SoListRow(
                    icon: LucideIcons.pencil,
                    title: 'Sửa thông tin cá nhân',
                    comingSoon: true,
                  ),
                  SoListRow(
                    icon: LucideIcons.lock,
                    title: 'Đổi mật khẩu',
                    comingSoon: true,
                  ),
                  SoListRow(
                    icon: LucideIcons.fileText,
                    title: 'Điều khoản & quyền riêng tư',
                    comingSoon: true,
                  ),
                ],
              ),
              SizedBox(height: SoSpace.group),
              SoListGroup(children: [LogoutRow()]),
            ],
          ),
        ),
      ],
    );
  }
}

/// Thẻ hồ sơ của khách: ô chữ cái tròn + email. Họ tên, SĐT thêm khi backend
/// trả về trong phiên đăng nhập.
class _CustomerProfileCard extends ConsumerWidget {
  const _CustomerProfileCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.soColors;
    final email = ref.watch(currentSessionProvider)?.email ?? '';
    final initial = email.isEmpty ? '?' : email.characters.first.toUpperCase();
    return Container(
      key: const Key('customer_profile'),
      padding: SoSpace.card,
      decoration: SoShape.card(c),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.brandTint,
              shape: BoxShape.circle,
            ),
            child: Text(
              initial,
              style: context.textTheme.titleLarge?.copyWith(color: c.brand),
            ),
          ),
          const SizedBox(width: SoSpace.s12),
          Expanded(
            child: Text(
              email,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textTheme.titleMedium,
            ),
          ),
        ],
      ),
    );
  }
}

/// Nhóm "Cửa hàng đã tham gia": nút Thêm mở sheet thêm cửa hàng; chạm một
/// cửa hàng mở C-00.
class _JoinedShops extends ConsumerWidget {
  const _JoinedShops();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.soColors;
    final async = ref.watch(myShopsProvider);
    final shops = async.value;

    final Widget body;
    if (shops == null && async.hasError) {
      body = SoEmptyState.error(
        title: 'Không tải được danh sách cửa hàng',
        onAction: () => ref.invalidate(myShopsProvider),
      );
    } else if (shops == null) {
      body = const SoListGroup(children: [SoSkeletonList(count: 2)]);
    } else if (shops.isEmpty) {
      body = Container(
        padding: SoSpace.card,
        decoration: SoShape.card(c),
        child: Text(
          'Bạn chưa tham gia cửa hàng nào.',
          style: context.textTheme.bodyMedium?.copyWith(color: c.ink2),
        ),
      );
    } else {
      body = Container(
        clipBehavior: Clip.antiAlias,
        decoration: SoShape.card(c),
        child: Column(
          children: [
            for (final (i, shop) in shops.indexed) ...[
              if (i > 0) const Divider(indent: SoSpace.s16),
              _ShopRow(shop: shop),
            ],
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            top: SoSpace.group,
            bottom: SoSpace.s8,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Cửa hàng đã tham gia',
                  style: context.soText.title3,
                ),
              ),
              SoButton.ghost(
                key: const Key('account_add_shop'),
                label: 'Thêm',
                icon: LucideIcons.plus,
                size: SoButtonSize.small,
                onPressed: () => showAddShopSheet(context),
              ),
            ],
          ),
        ),
        body,
      ],
    );
  }
}

class _ShopRow extends StatelessWidget {
  const _ShopRow({required this.shop});

  final CustomerShop shop;

  @override
  Widget build(BuildContext context) {
    final c = context.soColors;
    return Material(
      color: c.surface,
      child: InkWell(
        key: Key('account_shop_${shop.tenantId}'),
        onTap: () => context.push(Routes.customerShops),
        child: Padding(
          padding: SoSpace.card,
          child: Row(
            children: [
              SoShopLogo(name: shop.name),
              const SizedBox(width: SoSpace.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shop.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.textTheme.titleMedium,
                    ),
                    Text(
                      '${shop.points} điểm',
                      style: context.textTheme.bodySmall?.copyWith(
                        color: c.ink2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: SoSpace.s8),
              SoTierBadge(tier: shop.tier),
            ],
          ),
        ),
      ),
    );
  }
}
