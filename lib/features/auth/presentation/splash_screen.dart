import 'package:flutter/material.dart';

/// Hiển thị trong lúc app đọc token đã lưu để khôi phục phiên đăng nhập.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
