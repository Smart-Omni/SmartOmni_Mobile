import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartomni_mobile/app/app.dart';
import 'package:smartomni_mobile/core/auth/jwt_decoder.dart';
import 'package:smartomni_mobile/core/network/api_client.dart';
import 'package:smartomni_mobile/core/network/api_paths.dart';
import 'package:smartomni_mobile/features/auth/presentation/login_screen.dart';

import '../helpers/fake_backend.dart';
import '../helpers/test_app.dart';

const _me = '/api/v1/users/me';

/// Đang đăng nhập; mọi API trả [meResponse], refresh luôn bị từ chối (BE đã
/// xóa refresh token khi khóa / đổi quyền).
Future<void> _callApiThenRefreshFails(
  WidgetTester tester,
  Map<String, Object?> meResponse,
) async {
  final token = JwtDecoder.buildUnsigned({
    'sub': '2',
    'role': 'MANAGER',
    'tenantId': 3,
    'exp':
        DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
        1000,
  });
  final storage = await pumpSmartOmniApp(tester, savedToken: token);
  await storage.writeTokens(access: token, refresh: 'r1');
  expect(find.byType(LoginScreen), findsNothing);

  final backend = FakeBackend(
    (o) async => o.path == ApiPaths.refresh
        ? (401, apiError('Refresh token không hợp lệ hoặc đã hết hạn'))
        : (401, meResponse),
  );
  // Dio thật của app (có AuthInterceptor), chỉ thay phần gửi mạng.
  final container = ProviderScope.containerOf(
    tester.element(find.byType(SmartOmniApp)),
  );
  container.read(dioProvider).httpClientAdapter = backend;
  container.read(tokenRefresherProvider).dio.httpClientAdapter = backend;

  await tester.runAsync(() async {
    await expectLater(
      container.read(dioProvider).get<Object?>(_me),
      throwsA(isA<DioException>()),
    );
  });
  await tester.pumpAndSettle();
  expect(backend.calls(ApiPaths.refresh), 1);
  expect(find.byType(LoginScreen), findsOneWidget);
  expect(await storage.readToken(), isNull);
}

void main() {
  testWidgets('401 TOKEN_REVOKED + refresh thất bại → màn đăng nhập báo phiên '
      'bị thu hồi', (tester) async {
    await _callApiThenRefreshFails(tester, {
      'success': false,
      'message': 'Phiên đăng nhập đã bị thu hồi',
      'code': 'TOKEN_REVOKED',
    });
    expect(
      find.text(
        'Phiên đăng nhập đã bị thu hồi (tài khoản bị khóa hoặc đổi quyền). '
        'Vui lòng đăng nhập lại.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('401 thường + refresh thất bại → giữ câu hết hạn cũ', (
    tester,
  ) async {
    await _callApiThenRefreshFails(tester, apiError('Unauthorized'));
    expect(
      find.text('Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.'),
      findsOneWidget,
    );
  });
}
