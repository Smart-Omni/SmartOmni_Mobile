import 'package:flutter/material.dart';

import 'account_widgets.dart';

/// Tài khoản Customer.
class CustomerAccountScreen extends StatelessWidget {
  const CustomerAccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tài khoản')),
      body: ListView(
        children: const [
          ProfileHeader(),
          Divider(),
          ComingSoonTile(
            icon: Icons.edit_outlined,
            title: 'Sửa thông tin (email, SĐT)',
          ),
          ComingSoonTile(icon: Icons.lock_outline, title: 'Đổi mật khẩu'),
          ComingSoonTile(
            icon: Icons.notifications_outlined,
            title: 'Thông báo voucher',
            note: 'Hiện voucher được gửi qua email',
          ),
          Divider(),
          LogoutTile(),
        ],
      ),
    );
  }
}
