import 'jwt_decoder.dart';
import 'user_role.dart';

/// Phiên đăng nhập hiện tại.
class Session {
  const Session({
    required this.accessToken,
    required this.userId,
    required this.role,
    this.tenantId,
    this.email,
    this.expiresAt,
  });

  final String accessToken;
  final int userId;
  final UserRole role;

  /// `null` với Super Admin (không gắn tenant).
  final int? tenantId;
  final String? email;
  final DateTime? expiresAt;

  bool isExpired([DateTime? now]) =>
      expiresAt != null && !expiresAt!.isAfter(now ?? DateTime.now());

  /// Dựng lại phiên từ JWT đã lưu (khi mở lại app).
  /// Payload backend: `{ sub: "<userId>", role: "ADMIN", tenantId: 1, exp: ... }`.
  static Session? fromToken(String token) {
    final payload = JwtDecoder.decodePayload(token);
    if (payload == null) return null;
    final userId = int.tryParse('${payload['sub']}');
    if (userId == null) return null;
    final tenant = payload['tenantId'];
    return Session(
      accessToken: token,
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
