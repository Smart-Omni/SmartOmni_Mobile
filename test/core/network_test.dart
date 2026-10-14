import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartomni_mobile/core/network/api_exception.dart';
import 'package:smartomni_mobile/core/network/api_response.dart';

void main() {
  group('unwrapResponse', () {
    test('trả về data khi success = true', () {
      final body = {'success': true, 'data': 42, 'timestamp': '2026-10-14'};
      expect(unwrapResponse(body, (d) => d! as int), 42);
    });

    test('ném ApiException với message của backend khi success = false', () {
      final body = {'success': false, 'message': 'Token khong hop le'};
      expect(
        () => unwrapResponse(body, (d) => d),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            'Token khong hop le',
          ),
        ),
      );
    });

    test('body không phải JSON object -> lỗi định dạng', () {
      expect(
        () => unwrapResponse('oops', (d) => d),
        throwsA(isA<ApiException>()),
      );
    });
  });

  group('PageResult.fromJson', () {
    test('đọc kiểu Page cũ của Spring', () {
      final page = PageResult.fromJson({
        'content': [
          {'id': 1},
          {'id': 2},
        ],
        'number': 0,
        'size': 2,
        'totalElements': 5,
        'totalPages': 3,
      }, (j) => j['id']);
      expect(page.items, [1, 2]);
      expect(page.totalElements, 5);
      expect(page.hasMore, isTrue);
    });

    test('đọc kiểu PagedModel mới (có object page)', () {
      final page = PageResult.fromJson({
        'content': [
          {'id': 9},
        ],
        'page': {'number': 1, 'size': 1, 'totalElements': 2, 'totalPages': 2},
      }, (j) => j['id']);
      expect(page.items, [9]);
      expect(page.page, 1);
      expect(page.hasMore, isFalse);
    });
  });

  group('ApiException.fromDio', () {
    RequestOptions req() => RequestOptions(path: '/api/x');

    test('lấy message backend khi lỗi 401', () {
      final e = ApiException.fromDio(
        DioException(
          requestOptions: req(),
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: req(),
            statusCode: 401,
            data: {
              'success': false,
              'message': 'Email hoac mat khau khong dung',
            },
          ),
        ),
      );
      expect(e.type, ApiErrorType.unauthorized);
      expect(e.message, 'Email hoac mat khau khong dung');
    });

    test('mất kết nối -> network', () {
      final e = ApiException.fromDio(
        DioException(
          requestOptions: req(),
          type: DioExceptionType.connectionError,
        ),
      );
      expect(e.type, ApiErrorType.network);
    });

    test('500 không có message -> thông điệp mặc định', () {
      final e = ApiException.fromDio(
        DioException(
          requestOptions: req(),
          type: DioExceptionType.badResponse,
          response: Response(requestOptions: req(), statusCode: 503),
        ),
      );
      expect(e.type, ApiErrorType.server);
      expect(e.message, isNotEmpty);
    });
  });

  group('Json helpers', () {
    test('đọc số từ nhiều kiểu', () {
      expect(Json.asInt('5'), 5);
      expect(Json.asInt(5.9), 5);
      expect(Json.asDouble('318000.00'), 318000);
      expect(Json.asDouble(null), isNull);
    });
  });
}
