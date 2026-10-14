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

  /// Backend yêu cầu mật khẩu mới tối thiểu 8 ký tự.
  static String? newPassword(String? value) {
    final empty = required(value, field: 'Mật khẩu');
    if (empty != null) return empty;
    if (value!.length < 8) return 'Mật khẩu phải có ít nhất 8 ký tự';
    return null;
  }

  /// Ô "Nhập lại mật khẩu" phải giống [password].
  static String? confirmPassword(String? value, String password) {
    final empty = required(value, field: 'Mật khẩu');
    if (empty != null) return empty;
    if (value != password) return 'Hai mật khẩu chưa giống nhau';
    return null;
  }

  static String? positiveInt(String? value, {String field = 'Số lượng'}) {
    final empty = required(value, field: field);
    if (empty != null) return empty;
    final n = int.tryParse(value!.trim());
    if (n == null || n <= 0) return '$field phải là số nguyên dương';
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
