import '../../../core/utils/mock_delay.dart';
import '../domain/staff.dart';

/// Danh sách mẫu khớp tài khoản demo (admin@, staff@, disabled@demo.vn).
/// Khóa / thêm chỉ đổi danh sách trong phiên chạy app, không ảnh hưởng đăng
/// nhập mock.
class StaffMockRepository implements StaffRepository {
  final _members = <StaffMember>[
    const StaffMember(
      id: 1,
      email: 'admin@demo.vn',
      name: 'Nguyễn Thu Hà',
      isOwner: true,
    ),
    const StaffMember(id: 2, email: 'staff@demo.vn', name: 'Lê Văn Bình'),
    const StaffMember(id: 6, email: 'cuc.pham@demo.vn', name: 'Phạm Thị Cúc'),
    const StaffMember(
      id: 4,
      email: 'disabled@demo.vn',
      name: 'Đỗ Quang Dũng',
      active: false,
    ),
  ];

  @override
  Future<List<StaffMember>> list() async {
    await MockDelay.short();
    return List.unmodifiable(_members);
  }

  @override
  Future<StaffMember> add({
    required String email,
    required String password,
  }) async {
    await MockDelay.short();
    final normalized = email.trim().toLowerCase();
    if (_members.any((m) => m.email.toLowerCase() == normalized)) {
      throw const DuplicateStaffEmailException();
    }
    final id = _members.fold(0, (max, m) => m.id > max ? m.id : max) + 1;
    final member = StaffMember(id: id, email: normalized);
    _members.add(member);
    return member;
  }

  @override
  Future<StaffMember> setActive(int id, {required bool active}) async {
    await MockDelay.short();
    final i = _members.indexWhere((m) => m.id == id);
    if (i < 0 || !canToggleStaff(_members[i])) {
      throw StateError('Không khóa được tài khoản $id');
    }
    return _members[i] = _members[i].copyWith(active: active);
  }
}
