import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/router/routes.dart';
import '../../../core/auth/user_role.dart';
import '../../../core/design/design.dart';
import '../../../core/models/platform.dart';
import '../../account/presentation/account_widgets.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../inbox/presentation/inbox_providers.dart';
import '../../marketplace/domain/marketplace_connection.dart';
import '../../marketplace/presentation/marketplace_providers.dart';
import '../../marketplace/presentation/marketplace_screen.dart';

/// M-50 tab "Thêm" của Merchant: hồ sơ, Công cụ, Quản trị cửa hàng (chỉ
/// Tenant Admin), Đăng xuất.
class MerchantMoreScreen extends ConsumerWidget {
  const MerchantMoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(currentRoleProvider) == UserRole.tenantAdmin;
    return SoScaffold(
      appBar: const SoAppBar.root(title: 'Thêm'),
      slivers: [
        SliverPadding(
          padding: SoSpace.page,
          sliver: SliverList.list(
            children: [
              const ProfileCard(),
              const GroupTitle('Công cụ'),
              SoListGroup(
                children: [
                  SoListRow(
                    key: const Key('menu_ai'),
                    icon: LucideIcons.chartLine,
                    title: 'Dự báo nhu cầu',
                    subtitle: 'Dự kiến bán 7 ngày tới theo SKU',
                    trailing: const SoAiLabel(),
                    onTap: () => context.push(Routes.merchantAi),
                  ),
                  const _InboxRow(),
                  const SoListRow(
                    icon: LucideIcons.undo2,
                    title: 'Danh sách hoàn/trả',
                    comingSoon: true,
                  ),
                ],
              ),
              if (isAdmin) ...[
                const GroupTitle('Quản trị cửa hàng'),
                SoListGroup(
                  children: [
                    const _MarketplaceRow(),
                    SoListRow(
                      key: const Key('menu_staff'),
                      icon: LucideIcons.users,
                      title: 'Quản lý nhân viên',
                      onTap: () => context.push(Routes.merchantStaff),
                    ),
                    SoListRow(
                      key: const Key('menu_voucher'),
                      icon: LucideIcons.ticket,
                      title: 'Phát voucher cho khách',
                      onTap: () => context.push(Routes.merchantVouchers),
                    ),
                    SoListRow(
                      key: const Key('menu_subscription'),
                      icon: LucideIcons.badgeCheck,
                      title: 'Gói dịch vụ',
                      onTap: () => context.push(Routes.merchantSubscription),
                    ),
                    SoListRow(
                      key: const Key('menu_support'),
                      icon: LucideIcons.lifeBuoy,
                      title: 'Yêu cầu hỗ trợ',
                      onTap: () => context.push(Routes.merchantSupport),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: SoSpace.group),
              const SoListGroup(children: [LogoutRow()]),
            ],
          ),
        ),
      ],
    );
  }
}

/// "Hộp thư CSKH" kèm số hội thoại chưa đọc → M-60.
class _InboxRow extends ConsumerWidget {
  const _InboxRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.soColors;
    final unread = ref.watch(inboxUnreadCountProvider);
    return SoListRow(
      key: const Key('menu_inbox'),
      icon: LucideIcons.messagesSquare,
      title: 'Hộp thư CSKH',
      subtitle: 'Tin nhắn Shopee và TikTok Shop',
      onTap: () => context.push(Routes.merchantInbox),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (unread != null && unread > 0)
            Text(
              '$unread',
              key: const Key('menu_inbox_unread'),
              semanticsLabel: '$unread chưa đọc',
              style: context.textTheme.bodySmall?.copyWith(
                color: c.ink2,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          const SizedBox(width: SoSpace.s4),
          Icon(
            LucideIcons.chevronRight,
            size: SoSize.iconSmall,
            color: c.muted,
          ),
        ],
      ),
    );
  }
}

/// "Kết nối sàn" kèm trạng thái của 2 sàn.
class _MarketplaceRow extends ConsumerWidget {
  const _MarketplaceRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.soColors;
    final connections = ref.watch(connectionsProvider);
    return Material(
      color: c.surface,
      child: InkWell(
        key: const Key('menu_marketplace'),
        onTap: () => context.push(Routes.merchantMarketplace),
        child: Padding(
          padding: SoSpace.card,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(LucideIcons.link, color: c.ink2),
              const SizedBox(width: SoSpace.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Kết nối sàn', style: context.textTheme.titleMedium),
                    const SizedBox(height: SoSpace.s8),
                    switch (connections) {
                      AsyncData(:final value) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final platform in Platform.values)
                            Padding(
                              padding: const EdgeInsets.only(
                                bottom: SoSpace.s4,
                              ),
                              child: _PlatformStatus(
                                platform: platform,
                                status: connectionFor(value, platform)?.status,
                              ),
                            ),
                        ],
                      ),
                      AsyncError() => Text(
                        'Không tải được trạng thái',
                        style: context.textTheme.bodySmall,
                      ),
                      _ => const SoSkeleton(width: 160, height: 16),
                    },
                  ],
                ),
              ),
              const SizedBox(width: SoSpace.s12),
              Icon(
                LucideIcons.chevronRight,
                size: SoSize.iconSmall,
                color: c.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlatformStatus extends StatelessWidget {
  const _PlatformStatus({required this.platform, required this.status});

  final Platform platform;
  final ConnectionStatus? status;

  @override
  Widget build(BuildContext context) {
    final (label, tone) = status.tag;
    return Row(
      children: [
        Expanded(child: SoChannelTag(platform: platform)),
        SoStatusTag(
          key: Key('connection_${platform.name}'),
          label: label,
          status: tone,
        ),
      ],
    );
  }
}
