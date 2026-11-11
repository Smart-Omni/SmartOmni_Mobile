import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartomni_mobile/core/auth/jwt_decoder.dart';
import 'package:smartomni_mobile/core/network/api_client.dart';
import 'package:smartomni_mobile/core/network/api_paths.dart';
import 'package:smartomni_mobile/core/storage/token_storage.dart';

import '../helpers/fake_backend.dart';

final _now = DateTime(2026, 11, 11, 10);

String _jwt(Duration fromNow) => JwtDecoder.buildUnsigned({
  'sub': '1',
  'role': 'TENANT_ADMIN',
  'exp': _now.add(fromNow).millisecondsSinceEpoch ~/ 1000,
});

final _old = _jwt(const Duration(hours: 1));
final _expired = _jwt(const Duration(minutes: -1));
final _fresh = _jwt(const Duration(hours: 2));
const _me = '/api/v1/users/me';

/// Dio thật + interceptor thật, BE giả: `/users/me` chỉ nhận token [_fresh].
class _Harness {
  _Harness({
    required String access,
    bool refreshOk = true,
    bool rejectAll = false,
    Future<(int, Object?)> Function(RequestOptions o)? onRefresh,
  }) {
    storage = InMemoryTokenStorage(access, 'r1');
    backend = FakeBackend((o) async {
      if (o.path == ApiPaths.refresh) {
        // Chậm một chút để các request cùng lúc chồng lên nhau.
        await Future<void>.delayed(const Duration(milliseconds: 20));
        if (onRefresh != null) return onRefresh(o);
        return refreshOk
            ? (200, ok({'access_token': _fresh, 'refresh_token': 'r2'}))
            : (401, apiError('Refresh token không hợp lệ hoặc đã hết hạn'));
      }
      if (o.path == _me) {
        return !rejectAll && o.headers['Authorization'] == 'Bearer $_fresh'
            ? (200, ok({'id': 1}))
            : (401, apiError('Unauthorized'));
      }
      return (200, ok());
    });
    dio = fakeDio(backend);
    dio.interceptors.add(
      AuthInterceptor(
        tokenStorage: storage,
        refresher: TokenRefresher(dio: fakeDio(backend), storage: storage),
        retry: dio.fetch,
        onUnauthorized: () => expiredEvents++,
        clock: () => _now,
      ),
    );
  }

  late final InMemoryTokenStorage storage;
  late final FakeBackend backend;
  late final Dio dio;
  int expiredEvents = 0;
}

void main() {
  test('401 → refresh một lần → gọi lại request cũ thành công', () async {
    final h = _Harness(access: _old);

    final res = await h.dio.get<Object?>(_me);

    expect(res.statusCode, 200);
    expect(h.backend.calls(ApiPaths.refresh), 1);
    final refreshReq = h.backend.requests.firstWhere(
      (r) => r.path == ApiPaths.refresh,
    );
    expect(refreshReq.data, {'refresh_token': 'r1'});
    expect(refreshReq.headers['Authorization'], isNull);
    // BE xoay vòng refresh token: lưu cả cặp mới.
    expect(await h.storage.readToken(), _fresh);
    expect(await h.storage.readRefreshToken(), 'r2');
    expect(h.expiredEvents, 0);
  });

  test('refresh thất bại → báo hết phiên, request trả lỗi 401', () async {
    final h = _Harness(access: _old, refreshOk: false);

    await expectLater(
      h.dio.get<Object?>(_me),
      throwsA(
        isA<DioException>().having(
          (e) => e.response?.statusCode,
          'status',
          401,
        ),
      ),
    );
    expect(h.backend.calls(ApiPaths.refresh), 1);
    expect(h.expiredEvents, 1);
  });

  test('nhiều request cùng gặp 401 → chỉ refresh một lần', () async {
    final h = _Harness(access: _old);

    final results = await Future.wait([
      for (var i = 0; i < 3; i++) h.dio.get<Object?>(_me),
    ]);

    expect(results.map((r) => r.statusCode), [200, 200, 200]);
    expect(h.backend.calls(ApiPaths.refresh), 1);
    expect(h.expiredEvents, 0);
  });

  test('token đã hết hạn (exp) → refresh trước khi gửi', () async {
    final h = _Harness(access: _expired);

    final res = await h.dio.get<Object?>(_me);

    expect(res.statusCode, 200);
    expect(h.backend.calls(ApiPaths.refresh), 1);
    // Không gửi token hết hạn lên BE (BE sẽ trả 403 body rỗng).
    final sent = h.backend.requests.where((r) => r.path == _me).toList();
    expect(sent, hasLength(1));
    expect(sent.single.headers['Authorization'], 'Bearer $_fresh');
  });

  test('gọi lại vẫn 401 → báo hết phiên, không refresh lần hai', () async {
    // BE từ chối cả token mới.
    final h = _Harness(access: _old, rejectAll: true);

    await expectLater(h.dio.get<Object?>(_me), throwsA(isA<DioException>()));
    expect(h.backend.calls(ApiPaths.refresh), 1);
    expect(h.backend.calls(_me), 2);
    expect(h.expiredEvents, 1);
  });

  group('lỗi tạm thời khi refresh: không đăng xuất, giữ token', () {
    Future<void> expectKeptSession(_Harness h) async {
      expect(h.expiredEvents, 0);
      expect(await h.storage.readToken(), isNotNull);
      expect(await h.storage.readRefreshToken(), 'r1');
    }

    test('refresh trả 502 (BE đang khởi động lại)', () async {
      final h = _Harness(
        access: _old,
        onRefresh: (o) async => (502, apiError('Bad Gateway')),
      );
      await expectLater(h.dio.get<Object?>(_me), throwsA(isA<DioException>()));
      await expectKeptSession(h);
    });

    test('refresh trả trang HTML 200 (wifi công cộng)', () async {
      final h = _Harness(access: _old, onRefresh: (o) async => captivePortal);
      await expectLater(h.dio.get<Object?>(_me), throwsA(isA<DioException>()));
      await expectKeptSession(h);
    });

    test('refresh thiếu access_token', () async {
      final h = _Harness(
        access: _old,
        onRefresh: (o) async => (200, ok({'refresh_token': 'r2'})),
      );
      await expectLater(h.dio.get<Object?>(_me), throwsA(isA<DioException>()));
      await expectKeptSession(h);
    });

    test('mất mạng khi refresh trước lúc gửi: vẫn gửi bằng token cũ', () async {
      final h = _Harness(access: _expired, onRefresh: offline);
      await expectLater(h.dio.get<Object?>(_me), throwsA(isA<DioException>()));
      final sent = h.backend.requests.where((r) => r.path == _me).single;
      expect(sent.headers['Authorization'], 'Bearer $_expired');
      await expectKeptSession(h);
    });

    test('400/403 từ refresh thì coi là bị từ chối', () async {
      for (final status in [400, 403]) {
        final h = _Harness(
          access: _old,
          onRefresh: (o) async =>
              (status, apiError('Refresh token không hợp lệ')),
        );
        await expectLater(
          h.dio.get<Object?>(_me),
          throwsA(isA<DioException>()),
        );
        expect(h.expiredEvents, 1, reason: '$status');
      }
    });
  });

  test('đường công khai không gắn token', () async {
    final h = _Harness(access: _old);

    await h.dio.post<Object?>(ApiPaths.login, data: {'email': 'a@b.vn'});
    await h.dio.post<Object?>(ApiPaths.logout);

    final login = h.backend.requests.firstWhere(
      (r) => r.path == ApiPaths.login,
    );
    final logout = h.backend.requests.firstWhere(
      (r) => r.path == ApiPaths.logout,
    );
    expect(login.headers['Authorization'], isNull);
    // logout cần token để BE thu hồi phiên.
    expect(logout.headers['Authorization'], 'Bearer $_old');
  });
}
