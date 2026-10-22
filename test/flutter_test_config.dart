import 'dart:async';

import 'package:google_fonts/google_fonts.dart';

/// Chạy trước mọi file test (quy ước của flutter_test).
///
/// Test không có mạng: tắt tải font của google_fonts để chữ dùng font mặc
/// định của môi trường test thay vì gọi HTTP.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  await testMain();
}
