import 'dart:convert';

/// Giải mã phần payload của JWT (KHÔNG kiểm tra chữ ký - việc đó do backend làm).
///
/// App chỉ đọc payload để biết `sub` (userId), `role`, `tenantId`, `exp`
/// nhằm khôi phục phiên khi mở lại app và biết khi nào token hết hạn.
class JwtDecoder {
  const JwtDecoder._();

  static Map<String, dynamic>? decodePayload(String token) {
    final parts = token.split('.');
    if (parts.length != 3) return null;
    try {
      final normalized = base64Url.normalize(parts[1]);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final json = jsonDecode(decoded);
      return json is Map<String, dynamic> ? json : null;
    } on FormatException {
      return null;
    }
  }

  /// Thời điểm hết hạn (claim `exp`, tính bằng giây).
  static DateTime? expiry(String token) {
    final exp = decodePayload(token)?['exp'];
    if (exp is! num) return null;
    return DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000);
  }

  static bool isExpired(String token, {DateTime? now}) {
    final exp = expiry(token);
    if (exp == null) return true;
    return !exp.isAfter(now ?? DateTime.now());
  }

  /// Tạo JWT giả (không có chữ ký hợp lệ) - CHỈ dùng cho mock và test.
  static String buildUnsigned(Map<String, dynamic> payload) {
    String enc(Map<String, dynamic> m) =>
        base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
    return '${enc({'alg': 'none', 'typ': 'JWT'})}.${enc(payload)}.mock';
  }
}
