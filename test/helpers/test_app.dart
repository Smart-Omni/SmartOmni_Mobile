import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:smartomni_mobile/app/app.dart';
import 'package:smartomni_mobile/app/config/app_config.dart';
import 'package:smartomni_mobile/core/storage/token_storage.dart';
import 'package:smartomni_mobile/features/auth/data/auth_mock_repository.dart';
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
  List<Override> overrides = const [],
}) async {
  MockDelay.enabled = false;
  final storage = InMemoryTokenStorage(savedToken);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(testConfig),
        tokenStorageProvider.overrideWithValue(storage),
        ...overrides,
      ],
      child: const SmartOmniApp(),
    ),
  );
  await tester.pumpAndSettle();
  return storage;
}

/// Dựng app, đăng nhập bằng tài khoản demo [email] (mật khẩu mock chung).
///
/// [tallView]: khung test cao 2000px để `ListView` dựng đủ mọi hàng.
Future<InMemoryTokenStorage> loginAs(
  WidgetTester tester,
  String email, {
  List<Override> overrides = const [],
  bool tallView = false,
}) async {
  if (tallView) {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }
  final storage = await pumpSmartOmniApp(tester, overrides: overrides);
  await tester.enterText(find.byKey(const Key('login_email')), email);
  await tester.enterText(
    find.byKey(const Key('login_password')),
    MockAccounts.password,
  );
  await tester.tap(find.byKey(const Key('login_submit')));
  await tester.pumpAndSettle();
  return storage;
}

/// Cuộn tới [finder] rồi chạm.
Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Giả lập điện thoại hẹp 360dp.
void useNarrowPhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(360, 780);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}
