import 'package:flutter/material.dart';

import '../../../core/design/design.dart';

/// Dữ liệu A-05 chuyển sang màn OTP (GoRouter `extra`).
class RegisterOtpArgs {
  const RegisterOtpArgs({required this.email, required this.shopName});

  final String email;

  /// Cửa hàng khách sẽ tham gia, hiện trên thẻ kính.
  final String shopName;
}

/// A-05 OTP: xác minh email bằng mã 6 số. Làm đầy đủ ở bước 2.
class RegisterOtpScreen extends StatelessWidget {
  const RegisterOtpScreen({super.key, required this.args});

  /// `null` khi mở thẳng route (không đi từ A-05).
  final RegisterOtpArgs? args;

  @override
  Widget build(BuildContext context) {
    return SoScaffold(
      appBar: const SoAppBar(title: 'Xác minh email'),
      slivers: [
        SliverPadding(
          padding: SoSpace.page,
          sliver: SliverToBoxAdapter(
            child: Text(
              'Mã đã gửi tới ${args?.email ?? 'email của bạn'}.',
              style: context.textTheme.bodyMedium,
            ),
          ),
        ),
      ],
    );
  }
}
