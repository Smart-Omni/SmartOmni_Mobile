import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../core/auth/user_role.dart';
import '../../account/presentation/account_widgets.dart';
import '../../auth/presentation/auth_controller.dart';

/// Tab "Thêm" của Merchant. Mục hiển thị theo role.
class MerchantMoreScreen extends ConsumerWidget {
  const MerchantMoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(currentRoleProvider) == UserRole.tenantAdmin;
    return Scaffold(
      appBar: AppBar(title: const Text('Thêm')),
      body: ListView(
        children: [
          const ProfileHeader(),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.auto_graph),
            title: const Text('AI dự báo & gợi ý'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(Routes.merchantAi),
          ),
          const ComingSoonTile(
            icon: Icons.forum_outlined,
            title: 'Hộp thư CSKH (Shopee/TikTok)',
          ),
          const ComingSoonTile(
            icon: Icons.assignment_return_outlined,
            title: 'Danh sách hoàn/trả',
          ),
          if (isAdmin) ...[
            const Divider(),
            const _SectionLabel('Quản trị cửa hàng'),
            ListTile(
              key: const Key('menu_marketplace'),
              leading: const Icon(Icons.link),
              title: const Text('Kết nối sàn'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(Routes.merchantMarketplace),
            ),
            const ComingSoonTile(
              icon: Icons.group_outlined,
              title: 'Quản lý nhân viên',
            ),
            const ComingSoonTile(
              icon: Icons.card_giftcard,
              title: 'Phát voucher cho khách',
            ),
            const ComingSoonTile(
              icon: Icons.workspace_premium_outlined,
              title: 'Gói dịch vụ SaaS',
            ),
            const ComingSoonTile(
              icon: Icons.support_agent,
              title: 'Yêu cầu hỗ trợ',
            ),
          ],
          const Divider(),
          const LogoutTile(),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
    child: Text(text, style: Theme.of(context).textTheme.labelLarge),
  );
}
