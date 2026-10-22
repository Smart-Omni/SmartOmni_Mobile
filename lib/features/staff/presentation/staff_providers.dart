import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/staff_mock_repository.dart';
import '../domain/staff.dart';

/// Chỉ có Mock: backend chưa có API quản lý Staff.
final staffRepositoryProvider = Provider<StaffRepository>(
  (ref) => StaffMockRepository(),
);

/// Danh sách đã sắp xếp (chủ cửa hàng → đang hoạt động → đã khóa).
final staffListProvider = FutureProvider.autoDispose<List<StaffMember>>(
  (ref) async => sortStaff(await ref.watch(staffRepositoryProvider).list()),
);
