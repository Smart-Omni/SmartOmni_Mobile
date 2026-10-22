import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'config/app_config.dart';

/// Không tự thử lại provider bị lỗi. Mặc định Riverpod 3 thử lại tới 10 lần
/// (~38 giây), trong lúc đó màn vẫn hiện skeleton; app muốn hiện lỗi ngay để
/// người dùng bấm "Thử lại".
Duration? noAutoRetry(int retryCount, Object error) => null;

/// Điểm khởi động chung cho mọi flavor.
void bootstrap(Flavor flavor) {
  WidgetsFlutterBinding.ensureInitialized();
  final config = AppConfig.forFlavor(flavor);

  runApp(
    ProviderScope(
      retry: noAutoRetry,
      overrides: [appConfigProvider.overrideWithValue(config)],
      child: const SmartOmniApp(),
    ),
  );
}
