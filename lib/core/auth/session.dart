import 'jwt_decoder.dart';
import 'user_role.dart';

/// Phiên đăng nhập hiện tại.
class Session {
  const Session({
    required this.accessToken,
    required this.userId,
    required this.role,
    this.refreshToken,
    this.tenantId,
    this.email,
    this.fullName,
    this.expiresAt,
  });

  final String accessToken;

  /// Dùng để gia hạn phiên (`POST /api/v1/auth/refresh`). Mock không có.
  final String? refreshToken;
  final int userId;
  final UserRole role;

  /// `null` với Super Admin và khách (không gắn tenant).
  final int? tenantId;
  final String? email;
  final String? fullName;
  final DateTime? expiresAt;

  bool isExpired([DateTime? now]) =>
      expiresAt != null && !expiresAt!.isAfter(now ?? DateTime.now());

  /// Dựng lại phiên từ JWT đã lưu (khi mở lại app).
  /// Payload backend: `{ sub: "7", role: "TENANT_ADMIN", tenantId: 1,
  /// tenant_id: 1, subdomain, exp }` (không có email).
  static Session? fromToken(String token, {String? refreshToken}) {
    final payload = JwtDecoder.decodePayload(token);
    if (payload == null) return null;
    final userId = int.tryParse('${payload['sub']}');
    if (userId == null) return null;
    final tenant = payload['tenantId'];
    return Session(
      accessToken: token,
      refreshToken: refreshToken,
      userId: userId,
      role: UserRole.fromBackend(payload['role'] as String?),
      tenantId: tenant is num
          ? tenant.toInt()
          : int.tryParse('${tenant ?? ''}'),
      email: payload['email'] as String?,
      expiresAt: JwtDecoder.expiry(token),
    );
  }
}
