import '../../../core/network/api_response.dart';
import '../../../core/utils/text_fold.dart';

/// Một người trong cửa hàng ở T-20: chủ cửa hàng (Tenant Admin) hoặc Staff.
///
/// Chưa có phân quyền con cho Staff (docs/USER_FLOWS.md F-T3: chưa chốt).
class StaffMember {
  const StaffMember({
    required this.id,
    required this.email,
    this.name,
    this.isOwner = false,
    this.active = true,
  });

  /// `UserProfileResponse` của `/api/v1/users` (snake_case). Chủ cửa hàng là
  /// role `TENANT_ADMIN` (hoặc `ADMIN`, tên cũ); `DISABLED` = Đã khóa.
  factory StaffMember.fromJson(JsonMap json) {
    final name = (json['full_name'] as String?)?.trim();
    final role = (json['role'] as String?)?.toUpperCase();
    return StaffMember(
      id: Json.asInt(json['id']) ?? 0,
      email: json['email'] as String? ?? '',
      name: name == null || name.isEmpty ? null : name,
      isOwner: role == 'TENANT_ADMIN' || role == 'ADMIN',
      active: (json['status'] as String?)?.toUpperCase() != 'DISABLED',
    );
  }

  final int id;
  final String email;

  /// Tài khoản cũ có thể chưa có tên: hiện email thay.
  final String? name;
  final bool isOwner;

  /// `false` = Đã khóa: không đăng nhập được.
  final bool active;

  String get displayName => name ?? email;

  StaffMember copyWith({bool? active}) => StaffMember(
    id: id,
    email: email,
    name: name,
    isOwner: isOwner,
    active: active ?? this.active,
  );
}

/// Remote: `/api/v1/users`. Mock: danh sách mẫu.
abstract interface class StaffRepository {
  Future<List<StaffMember>> list();

  /// Tạo Staff bằng họ tên + email + mật khẩu tạm. Ném
  /// [DuplicateStaffEmailException] khi email đã có trong cửa hàng.
  Future<StaffMember> add({
    required String name,
    required String email,
    required String password,
  });

  /// Khóa ([active] = false) hoặc mở khóa một Staff.
  Future<StaffMember> setActive(int id, {required bool active});
}

class DuplicateStaffEmailException implements Exception {
  const DuplicateStaffEmailException();
}

/// Chủ cửa hàng không tự khóa được chính mình.
bool canToggleStaff(StaffMember member) => !member.isOwner;

/// Thứ tự hiển thị: chủ cửa hàng → đang hoạt động → đã khóa, mỗi nhóm theo
/// tên (không phân biệt dấu/hoa thường).
List<StaffMember> sortStaff(Iterable<StaffMember> members) {
  int rank(StaffMember m) => m.isOwner ? 0 : (m.active ? 1 : 2);
  return [...members]..sort((a, b) {
    final byRank = rank(a).compareTo(rank(b));
    if (byRank != 0) return byRank;
    return foldVietnamese(
      a.displayName,
    ).compareTo(foldVietnamese(b.displayName));
  });
}
