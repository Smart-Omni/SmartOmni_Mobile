import 'input_formatters.dart';

/// Hàm kiểm tra dữ liệu form. Trả về `null` nếu hợp lệ, ngược lại trả thông báo lỗi.
///
/// Quy tắc khớp với validation của backend (LoginRequest, ResetPasswordRequest).
class Validators {
  const Validators._();

  static final _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static String? required(String? value, {String field = 'Trường này'}) {
    if (value == null || value.trim().isEmpty) {
      return '$field không được để trống';
    }
    return null;
  }

  static String? email(String? value) {
    final empty = required(value, field: 'Email');
    if (empty != null) return empty;
    if (!_emailRegex.hasMatch(value!.trim())) return 'Email không hợp lệ';
    return null;
  }

  /// Khớp `@Size(min = 6, max = 100)` của BE (ResetPasswordRequest,
  /// RegisterRequest, ChangePasswordRequest, CreateUserRequest).
  static String? newPassword(String? value) {
    final empty = required(value, field: 'Mật khẩu');
    if (empty != null) return empty;
    if (value!.length < 6 || value.length > 100) {
      return 'Mật khẩu phải từ 6 đến 100 ký tự';
    }
    return null;
  }

  static final _subdomainRegex = RegExp(r'^[a-z0-9-]{3,30}$');

  /// Mã cửa hàng gửi BE làm subdomain (khớp `TenantOnboardingRequest`):
  /// đổi sang chữ thường rồi kiểm tra `^[a-z0-9-]{3,30}$`.
  static String? subdomain(String? value) {
    final empty = required(value, field: 'Mã cửa hàng');
    if (empty != null) return empty;
    if (!_subdomainRegex.hasMatch(value!.trim().toLowerCase())) {
      return 'Mã cửa hàng gồm 3–30 chữ thường, số hoặc dấu gạch ngang';
    }
    return null;
  }

  static final _phoneRegex = RegExp(r'^0\d{9}$');

  /// Số điện thoại Việt Nam: 10 số, bắt đầu bằng 0.
  static String? phone(String? value) {
    final empty = required(value, field: 'Số điện thoại');
    if (empty != null) return empty;
    if (!_phoneRegex.hasMatch(value!.trim())) {
      return 'Số điện thoại gồm 10 số, bắt đầu bằng 0';
    }
    return null;
  }

  /// Ô "Nhập lại mật khẩu" phải giống [password].
  static String? confirmPassword(String? value, String password) {
    final empty = required(value, field: 'Mật khẩu');
    if (empty != null) return empty;
    if (value != password) return 'Hai mật khẩu chưa giống nhau';
    return null;
  }

  /// Giá VND đã định dạng bằng `VndInputFormatter` ("159.000"), phải > 0.
  static String? positiveVnd(String? value, {String field = 'Giá'}) {
    final empty = required(value, field: field);
    if (empty != null) return empty;
    final n = VndInputFormatter.parse(value!);
    if (n == null || n <= 0) return '$field phải lớn hơn 0';
    return null;
  }

  /// Số nguyên >= 0, dùng cho đặt lại số lượng tồn kho
  /// (backend `adjust` nhận số lượng tồn MỚI, không phải số chênh lệch).
  static String? nonNegativeInt(String? value, {String field = 'Số lượng'}) {
    final empty = required(value, field: field);
    if (empty != null) return empty;
    final n = int.tryParse(value!.trim());
    if (n == null || n < 0) return '$field phải là số nguyên không âm';
    return null;
  }
}
