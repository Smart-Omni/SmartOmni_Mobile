import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/config/app_config.dart';
import '../../../core/design/design.dart';
import '../../../l10n/l10n.dart';
import '../../auth/presentation/auth_controller.dart';
import 'account_providers.dart';

/// Thẻ hồ sơ M-50: ô chữ cái brand, họ tên, email, "vai trò · tên cửa hàng",
/// mã tenant. Hồ sơ chưa tải xong (hoặc lỗi) thì dùng tạm dữ liệu trong phiên.
class ProfileCard extends ConsumerWidget {
  const ProfileCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.soColors;
    final session = ref.watch(currentSessionProvider);
    final profile = ref.watch(accountProfileProvider).value;
    final config = ref.watch(appConfigProvider);
    final email =
        profile?.email ??
        session?.email ??
        'Người dùng #${session?.userId ?? ''}';
    final name = profile?.fullName ?? session?.fullName;
    final title = name ?? email;
    final initial = title.isEmpty ? '?' : title.characters.first.toUpperCase();
    final tenantId = session?.tenantId;
    final storeName = profile?.storeName;

    return Container(
      key: const Key('profile_card'),
      padding: const EdgeInsets.all(SoSpace.s16),
      decoration: SoShape.card(c),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.brand,
              borderRadius: SoRadius.mdAll,
            ),
            child: Text(
              initial,
              style: context.textTheme.titleMedium?.copyWith(color: c.onBrand),
            ),
          ),
          const SizedBox(width: SoSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  key: const Key('profile_name'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.titleMedium,
                ),
                if (name != null)
                  Text(
                    email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.bodySmall,
                  ),
                Text(
                  [
                    ?session?.role.label,
                    if (storeName != null)
                      storeName
                    else if (tenantId != null)
                      'Cửa hàng #$tenantId',
                  ].join(' · '),
                  style: context.textTheme.bodyMedium?.copyWith(color: c.ink2),
                ),
                const SizedBox(height: SoSpace.s8),
                Wrap(
                  spacing: SoSpace.s8,
                  runSpacing: SoSpace.s4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (tenantId != null) SoCodeTag('TENANT-$tenantId'),
                    Text(
                      'Bản ${config.flavor.name}'
                      '${config.useMock ? ' · dữ liệu mẫu' : ''}',
                      style: context.textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Hàng "Đăng xuất" chữ danger, xác nhận bằng bottom sheet.
class LogoutRow extends ConsumerWidget {
  const LogoutRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return SoListRow(
      key: const Key('logout_tile'),
      icon: LucideIcons.logOut,
      title: l10n.logout,
      destructive: true,
      trailing: const SizedBox.shrink(),
      onTap: () async {
        final ok = await showSoBottomSheet<bool>(
          context: context,
          builder: (sheetContext) => SoBottomSheet(
            title: l10n.logout,
            secondary: SoButton.secondary(
              label: l10n.cancel,
              onPressed: () => Navigator.pop(sheetContext, false),
            ),
            primary: SoButton.danger(
              key: const Key('logout_confirm'),
              label: l10n.logout,
              onPressed: () => Navigator.pop(sheetContext, true),
            ),
            child: Text(
              l10n.logoutConfirm,
              style: context.textTheme.bodyMedium,
            ),
          ),
        );
        if (ok ?? false) {
          await ref.read(authControllerProvider.notifier).logout();
        }
      },
    );
  }
}

/// Tiêu đề nhóm (title3), cách nhóm trước 28.
class GroupTitle extends StatelessWidget {
  const GroupTitle(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: SoSpace.group, bottom: SoSpace.s8),
    child: Text(title, style: context.soText.title3),
  );
}
