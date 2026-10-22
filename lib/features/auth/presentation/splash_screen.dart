import 'package:flutter/material.dart';

import '../../../core/design/design.dart';

/// A-01: hiển thị trong lúc app đọc token đã lưu để khôi phục phiên đăng nhập.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.soColors.surface,
      body: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SoLogo(height: 40),
            SizedBox(height: SoSpace.s24),
            SizedBox(width: 120, child: LinearProgressIndicator()),
          ],
        ),
      ),
    );
  }
}
