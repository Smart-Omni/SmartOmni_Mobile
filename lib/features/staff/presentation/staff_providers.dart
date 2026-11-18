import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/config/api_availability.dart';
import '../../../app/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../data/staff_mock_repository.dart';
import '../data/staff_remote_repository.dart';
import '../domain/staff.dart';

/// `false`: T-20 là dữ liệu mẫu, màn hiện `SoMockBanner`.
final staffUseRemoteProvider = Provider<bool>(
  (ref) => ref.watch(appConfigProvider).usesRemote(ApiFeature.staff),
);

final staffRepositoryProvider = Provider<StaffRepository>(
  (ref) => ref.watch(staffUseRemoteProvider)
      ? StaffRemoteRepository(ref.watch(dioProvider))
      : StaffMockRepository(),
);

/// Danh sách đã sắp xếp (chủ cửa hàng → đang hoạt động → đã khóa).
final staffListProvider = FutureProvider.autoDispose<List<StaffMember>>(
  (ref) async => sortStaff(await ref.watch(staffRepositoryProvider).list()),
);
