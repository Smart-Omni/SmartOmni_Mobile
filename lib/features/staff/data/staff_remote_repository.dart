import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/api_paths.dart';
import '../../../core/network/api_response.dart';
import '../domain/staff.dart';

/// T-20 qua `UserController` của BE (chỉ `TENANT_ADMIN` gọi được). BE tự lọc
/// theo tenant của người gọi.
class StaffRemoteRepository implements StaffRepository {
  StaffRemoteRepository(this._dio);

  final Dio _dio;

  /// Role hiện ở T-20: chủ cửa hàng và nhân viên.
  static const _shownRoles = {'TENANT_ADMIN', 'ADMIN', 'MANAGER'};

  /// Chủ cửa hàng ở lần tải gần nhất. BE không chặn tự khóa mình, app chặn.
  final _ownerIds = <int>{};

  @override
  Future<List<StaffMember>> list() async {
    try {
      // shortcut: chỉ tải trang đầu 100 người; cửa hàng hiếm khi nhiều hơn.
      final res = await _dio.get<Object?>(
        ApiPaths.users,
        queryParameters: {
          'page': 0,
          'size': 100,
          'sortBy': 'createdAt',
          'sortDir': 'asc',
        },
      );
      final members = unwrapResponse<List<StaffMember>>(res.data, (data) {
        final page = PageResult.fromJson(data, (j) => j);
        return [
          for (final json in page.items)
            if (_shownRoles.contains((json['role'] as String?)?.toUpperCase()))
              StaffMember.fromJson(json),
        ];
      });
      _ownerIds
        ..clear()
        ..addAll([
          for (final m in members)
            if (!canToggleStaff(m)) m.id,
        ]);
      return members;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  @override
  Future<StaffMember> add({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final res = await _dio.post<Object?>(
        ApiPaths.users,
        data: {
          'email': email.trim(),
          'password': password,
          'full_name': name.trim(),
          'role': 'MANAGER',
        },
      );
      return unwrapResponse<StaffMember>(
        res.data,
        (data) => StaffMember.fromJson(data! as JsonMap),
      );
    } on DioException catch (e) {
      // BE: 409 + EMAIL_EXISTS khi email đã có trong tenant.
      if (e.response?.statusCode == 409) {
        throw const DuplicateStaffEmailException();
      }
      throw ApiException.fromDio(e);
    }
  }

  @override
  Future<StaffMember> setActive(int id, {required bool active}) async {
    if (_ownerIds.contains(id)) {
      throw StateError('Không khóa được chủ cửa hàng');
    }
    try {
      final res = await _dio.patch<Object?>(
        ApiPaths.userStatus(id),
        data: {'status': active ? 'ACTIVE' : 'DISABLED'},
      );
      return unwrapResponse<StaffMember>(
        res.data,
        (data) => StaffMember.fromJson(data! as JsonMap),
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
