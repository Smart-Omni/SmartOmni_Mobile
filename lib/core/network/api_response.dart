import 'api_exception.dart';

typedef JsonMap = Map<String, dynamic>;

/// Bóc tách response chuẩn của backend SmartOmni:
///
/// ```json
/// { "success": true, "message": null, "data": { ... }, "timestamp": "..." }
/// ```
///
/// Trả về `data` đã được parse bằng [parse]. Ném [ApiException] nếu
/// `success == false`.
T unwrapResponse<T>(Object? body, T Function(Object? data) parse) {
  if (body is! Map<String, dynamic>) {
    throw const ApiException(
      type: ApiErrorType.unknown,
      message: 'Phản hồi từ máy chủ không đúng định dạng.',
    );
  }
  final success = body['success'] == true;
  if (!success) {
    throw ApiException(
      type: ApiErrorType.unknown,
      message: (body['message'] as String?) ?? 'Yêu cầu không thành công.',
    );
  }
  return parse(body['data']);
}

/// Kết quả phân trang.
///
/// Đọc được 3 kiểu JSON của BE:
/// - `Page` mặc định của Spring (products, inventory, orders):
///   `{ content, number, size, totalElements, totalPages }`
/// - PagedModel: `{ content, page: { number, size, totalElements, totalPages } }`
/// - `PageResponse` snake_case (`/api/v1/users`):
///   `{ content, page_number, page_size, total_elements, total_pages }`
class PageResult<T> {
  const PageResult({
    required this.items,
    required this.page,
    required this.size,
    required this.totalElements,
    required this.totalPages,
  });

  final List<T> items;

  /// Trang hiện tại, bắt đầu từ 0 (theo Spring).
  final int page;
  final int size;
  final int totalElements;
  final int totalPages;

  bool get hasMore => page + 1 < totalPages;

  factory PageResult.fromJson(Object? json, T Function(JsonMap item) parse) {
    final map = json is Map<String, dynamic> ? json : const <String, dynamic>{};
    final meta = map['page'] is Map<String, dynamic>
        ? map['page'] as Map<String, dynamic>
        : map;
    final content = (map['content'] as List<dynamic>?) ?? const [];
    return PageResult<T>(
      items: content.whereType<Map<String, dynamic>>().map(parse).toList(),
      page: Json.asInt(meta['number'] ?? meta['page_number']) ?? 0,
      size: Json.asInt(meta['size'] ?? meta['page_size']) ?? content.length,
      totalElements:
          Json.asInt(meta['totalElements'] ?? meta['total_elements']) ??
          content.length,
      totalPages: Json.asInt(meta['totalPages'] ?? meta['total_pages']) ?? 1,
    );
  }
}

/// Helpers đọc JSON an toàn (backend có thể trả số dạng int, double hoặc string).
class Json {
  const Json._();

  static int? asInt(Object? v) => switch (v) {
    final int i => i,
    final num n => n.toInt(),
    final String s => int.tryParse(s),
    _ => null,
  };

  static double? asDouble(Object? v) => switch (v) {
    final num n => n.toDouble(),
    final String s => double.tryParse(s),
    _ => null,
  };

  static DateTime? asDate(Object? v) =>
      v is String ? DateTime.tryParse(v)?.toLocal() : null;

  static String? asString(Object? v) => v?.toString();
}
