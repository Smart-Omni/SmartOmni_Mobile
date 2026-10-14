import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/config/app_config.dart';
import '../../../l10n/l10n.dart';
import '../../auth/presentation/auth_controller.dart';

/// Thông tin người đang đăng nhập.
class ProfileHeader extends ConsumerWidget {
  const ProfileHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(currentSessionProvider);
    final config = ref.watch(appConfigProvider);
    return ListTile(
      leading: const CircleAvatar(child: Icon(Icons.person)),
      title: Text(session?.email ?? 'Người dùng #${session?.userId ?? ''}'),
      subtitle: Text(
        [
          session?.role.label ?? '',
          if (session?.tenantId != null) 'Cửa hàng #${session!.tenantId}',
          'Môi trường: ${config.flavor.name}${config.useMock ? ' (mock)' : ''}',
        ].join(' · '),
      ),
    );
  }
}

/// Nút đăng xuất có hộp thoại xác nhận.
class LogoutTile extends ConsumerWidget {
  const LogoutTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return ListTile(
      key: const Key('logout_tile'),
      leading: const Icon(Icons.logout),
      title: Text(l10n.logout),
      onTap: () async {
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            content: Text(l10n.logoutConfirm),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                key: const Key('logout_confirm'),
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(l10n.logout),
              ),
            ],
          ),
        );
        if (ok ?? false) {
          await ref.read(authControllerProvider.notifier).logout();
        }
      },
    );
  }
}

/// Mục chưa làm - hiển thị để thấy được phạm vi app.
class ComingSoonTile extends StatelessWidget {
  const ComingSoonTile({
    super.key,
    required this.icon,
    required this.title,
    this.note = 'Backend chưa có API',
  });

  final IconData icon;
  final String title;
  final String note;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(note),
      trailing: const Chip(label: Text('Sắp có')),
      enabled: false,
    );
  }
}
