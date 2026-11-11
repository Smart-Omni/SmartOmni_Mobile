/// Hồ sơ người dùng đang đăng nhập (thẻ hồ sơ M-50, C-40).
class AccountProfile {
  const AccountProfile({
    required this.email,
    this.fullName,
    this.phone,
    this.storeName,
  });

  final String email;
  final String? fullName;
  final String? phone;

  /// Tên cửa hàng của Merchant. `null` với khách hoặc khi không tải được.
  final String? storeName;
}

abstract class AccountRepository {
  /// GET /api/v1/users/me (+ GET /api/v1/tenants/me khi có tenant).
  Future<AccountProfile> getProfile();

  /// POST /api/v1/auth/change-password. Ném `ApiException` (vd. sai mật
  /// khẩu hiện tại) với `message` để hiện trong sheet.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  });
}
