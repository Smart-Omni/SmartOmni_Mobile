import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Adapter giả cho Dio: [handle] nhận request, trả `(status, body JSON)`.
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
    return ResponseBody.fromString(
      body == null ? '' : jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Dio fakeDio(FakeBackend backend) =>
    Dio(BaseOptions(baseUrl: 'http://test'))..httpClientAdapter = backend;

/// `{ success: true, data }` như `ApiResponse` của BE.
Map<String, Object?> ok([Object? data]) => {'success': true, 'data': data};

Map<String, Object?> apiError(String message) => {
  'success': false,
  'message': message,
};
