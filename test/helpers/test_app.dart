import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartomni_mobile/app/app.dart';
import 'package:smartomni_mobile/app/config/app_config.dart';
import 'package:smartomni_mobile/core/storage/token_storage.dart';
import 'package:smartomni_mobile/core/utils/mock_delay.dart';

/// Cấu hình dùng trong test: luôn chạy mock, không gọi mạng.
const testConfig = AppConfig(
  flavor: Flavor.dev,
  apiBaseUrl: 'http://localhost:8080',
  useMock: true,
);

/// Dựng toàn bộ app ở chế độ mock để test luồng người dùng.
Future<InMemoryTokenStorage> pumpSmartOmniApp(
  WidgetTester tester, {
  String? savedToken,
}) async {
  MockDelay.enabled = false;
  final storage = InMemoryTokenStorage(savedToken);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(testConfig),
        tokenStorageProvider.overrideWithValue(storage),
      ],
      child: const SmartOmniApp(),
    ),
  );
  await tester.pumpAndSettle();
  return storage;
}
