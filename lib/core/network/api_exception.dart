import 'package:dio/dio.dart';

/// Loại lỗi để UI hiển thị thông báo phù hợp.
enum ApiErrorType {
  network, // Không có mạng / không kết nối được server
  timeout,
  unauthorized, // 401 - token hết hạn hoặc sai
  forbidden, // 403 - không đủ quyền / tài khoản bị khóa
  notFound, // 404
  validation, // 400 - dữ liệu gửi lên không hợp lệ
  server, // 5xx
  unknown,
}

/// Lỗi thống nhất cho toàn app. Repository luôn ném [ApiException],
/// UI không cần biết tới Dio.
class ApiException implements Exception {
  const ApiException({
    required this.type,
    required this.message,
    this.statusCode,
    this.code,
  });

  final ApiErrorType type;

  /// Thông điệp hiển thị cho người dùng. Ưu tiên `message` backend trả về.
  final String message;
  final int? statusCode;

  /// Mã lỗi nghiệp vụ nếu backend gửi kèm (`errorCode`), vd. `ACCOUNT_TEMP_LOCKED`.
  final String? code;

  /// Chuyển [DioException] thành [ApiException].
  ///
  /// Backend trả lỗi dạng: `{ "success": false, "message": "...", "timestamp": "..." }`.
  factory ApiException.fromDio(DioException e) {
    final status = e.response?.statusCode;
    final serverMessage = _extractMessage(e.response?.data);

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const ApiException(
          type: ApiErrorType.timeout,
          message: 'Máy chủ phản hồi quá lâu. Vui lòng thử lại.',
        );
      case DioExceptionType.connectionError:
        return const ApiException(
          type: ApiErrorType.network,
          message: 'Không thể kết nối máy chủ. Kiểm tra mạng và thử lại.',
        );
      case DioExceptionType.badResponse:
        return ApiException(
          type: _typeForStatus(status),
          message: serverMessage ?? _defaultMessageForStatus(status),
          statusCode: status,
          code: _extractCode(e.response?.data),
        );
      default: // cancel, badCertificate, unknown, ...
        if (e.error is ApiException) return e.error! as ApiException;
        return ApiException(
          type: ApiErrorType.unknown,
          message: serverMessage ?? 'Đã có lỗi xảy ra. Vui lòng thử lại.',
          statusCode: status,
        );
    }
  }

  static String? _extractMessage(Object? data) {
    if (data is Map<String, dynamic>) {
      final msg = data['message'];
      if (msg is String && msg.isNotEmpty) return msg;
    }
    return null;
  }

  static String? _extractCode(Object? data) {
    if (data is Map<String, dynamic>) {
      final code = data['errorCode'] ?? data['code'];
      if (code is String && code.isNotEmpty) return code;
    }
    return null;
  }

  static ApiErrorType _typeForStatus(int? status) {
    if (status == null) return ApiErrorType.unknown;
    if (status == 400 || status == 422) return ApiErrorType.validation;
    if (status == 401) return ApiErrorType.unauthorized;
    if (status == 403) return ApiErrorType.forbidden;
    if (status == 404) return ApiErrorType.notFound;
    if (status >= 500) return ApiErrorType.server;
    return ApiErrorType.unknown;
  }

  static String _defaultMessageForStatus(int? status) {
    return switch (_typeForStatus(status)) {
      ApiErrorType.unauthorized => 'Phiên đăng nhập đã hết hạn.',
      ApiErrorType.forbidden => 'Bạn không có quyền thực hiện thao tác này.',
      ApiErrorType.notFound => 'Không tìm thấy dữ liệu.',
      ApiErrorType.validation => 'Dữ liệu không hợp lệ.',
      ApiErrorType.server => 'Máy chủ đang gặp sự cố. Vui lòng thử lại sau.',
      _ => 'Đã có lỗi xảy ra. Vui lòng thử lại.',
    };
  }

  @override
  String toString() => 'ApiException($type, $statusCode): $message';
}
