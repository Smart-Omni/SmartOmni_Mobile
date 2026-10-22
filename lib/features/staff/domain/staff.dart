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

  final int id;
  final String email;

  /// Staff vừa thêm (chỉ nhập email + mật khẩu tạm) chưa có tên.
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

/// ⚠️ Backend chưa có API quản lý Staff (docs/API_CONTRACT.md) -> mock.
abstract interface class StaffRepository {
  Future<List<StaffMember>> list();

  /// Tạo Staff bằng email + mật khẩu tạm. Ném [DuplicateStaffEmailException]
  /// khi email đã có trong cửa hàng.
  Future<StaffMember> add({required String email, required String password});

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
