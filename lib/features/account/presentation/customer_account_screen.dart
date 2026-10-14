import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/design/design.dart';
import 'account_widgets.dart';

/// Tài khoản Customer. Giao diện Customer sẽ làm lại ở đợt sau theo mockup;
/// tạm dùng chung thẻ hồ sơ và hàng đăng xuất với Merchant.
class CustomerAccountScreen extends StatelessWidget {
  const CustomerAccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const SoAppBar.root(title: 'Tài khoản'),
      body: ListView(
        padding: const EdgeInsets.all(SoSpace.screen),
        children: const [
          ProfileCard(),
          GroupTitle('Tài khoản'),
          SoListGroup(
            children: [
              SoListRow(
                icon: LucideIcons.pencil,
                title: 'Sửa thông tin (email, SĐT)',
                comingSoon: true,
              ),
              SoListRow(
                icon: LucideIcons.lock,
                title: 'Đổi mật khẩu',
                comingSoon: true,
              ),
              SoListRow(
                icon: LucideIcons.bell,
                title: 'Thông báo voucher',
                subtitle: 'Hiện voucher được gửi qua email',
                comingSoon: true,
              ),
            ],
          ),
          SizedBox(height: SoSpace.group),
          SoListGroup(children: [LogoutRow()]),
        ],
      ),
    );
  }
}
