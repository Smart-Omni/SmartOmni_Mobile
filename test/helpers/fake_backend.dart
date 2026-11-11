import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Adapter giả cho Dio: [handle] nhận request, trả `(status, body)`. Body là
/// `String` thì gửi nguyên văn dạng HTML, còn lại mã hóa JSON. [handle] ném
/// lỗi (vd. [offline]) để giả lập mất mạng.
/// Ghi lại mọi request để test kiểm tra header/body đã gửi.
class FakeBackend implements HttpClientAdapter {
  FakeBackend(this.handle);

  final Future<(int, Object?)> Function(RequestOptions o) handle;
  final requests = <RequestOptions>[];

  int calls(String path) => requests.where((r) => r.path == path).length;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final (status, body) = await handle(options);
    final html = body is String;
    return ResponseBody.fromString(
      html ? body : (body == null ? '' : jsonEncode(body)),
      status,
      headers: {
        Headers.contentTypeHeader: [
          html ? 'text/html; charset=utf-8' : Headers.jsonContentType,
        ],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Ném trong [FakeBackend.handle] để giả lập không kết nối được máy chủ.
Never offline(RequestOptions o) =>
    throw DioException.connectionError(requestOptions: o, reason: 'offline');

/// Trang HTML mã 200 như wifi công cộng chặn request (captive portal).
const captivePortal = (200, '<html><body>Đăng nhập wifi</body></html>');

Dio fakeDio(FakeBackend backend) =>
    Dio(BaseOptions(baseUrl: 'http://test'))..httpClientAdapter = backend;

/// `{ success: true, data }` như `ApiResponse` của BE.
Map<String, Object?> ok([Object? data]) => {'success': true, 'data': data};

Map<String, Object?> apiError(String message) => {
  'success': false,
  'message': message,
};
