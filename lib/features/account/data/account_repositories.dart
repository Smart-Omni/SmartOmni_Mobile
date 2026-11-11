import 'package:dio/dio.dart';

import '../../../core/auth/session.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/api_paths.dart';
import '../../../core/network/api_response.dart';
import '../../../core/utils/mock_delay.dart';
import '../../auth/data/auth_mock_repository.dart';
import '../../auth/data/mock_account_store.dart';
import '../../customer_shop/data/customer_shop_mock_repository.dart';
import '../domain/account_repository.dart';

/// `users/me` trả `UserProfileResponse` (snake_case: `full_name`, `tenant_id`);
/// `tenants/me` trả `TenantProfileResponse` (camelCase: `companyName`,
/// `storefront.storeName`).
class AccountRemoteRepository implements AccountRepository {
  AccountRemoteRepository(this._dio);

  final Dio _dio;

  @override
  Future<AccountProfile> getProfile() async {
    final JsonMap user;
    try {
      final res = await _dio.get<Object?>(ApiPaths.usersMe);
      user = unwrapResponse(res.data, (data) => data! as JsonMap);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
    final hasTenant = Json.asInt(user['tenant_id']) != null;
    return AccountProfile(
      email: user['email'] as String? ?? '',
      fullName: user['full_name'] as String?,
      phone: user['phone'] as String?,
      storeName: hasTenant ? await _storeName() : null,
    );
  }

  /// Lỗi thì bỏ qua: thẻ hồ sơ vẫn hiện tên, email.
  Future<String?> _storeName() async {
    try {
      final res = await _dio.get<Object?>(ApiPaths.tenantsMe);
      return await unwrapResponse(res.data, (data) {
        final tenant = data! as JsonMap;
        final storefront = tenant['storefront'] as JsonMap?;
        final name = storefront?['storeName'] as String?;
        return name == null || name.trim().isEmpty
            ? tenant['companyName'] as String?
            : name;
      });
    } on DioException {
      return null;
    } on ApiException {
      return null;
    } on TypeError {
      // Body sai định dạng (vd. `storefront` không phải object).
      return null;
    }
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    try {
      await _dio.post<Object?>(
        ApiPaths.changePassword,
        data: {
          'current_password': currentPassword,
          'new_password': newPassword,
          'confirm_password': confirmPassword,
        },
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

/// Hồ sơ theo tài khoản demo / tài khoản khách vừa đăng ký ở mock.
class AccountMockRepository implements AccountRepository {
  AccountMockRepository({required this.session, required this.store});

  final Session? session;
  final MockAccountStore store;

  static const _demoNames = {
    'admin@demo.vn': 'Trần Chủ Shop',
    'staff@demo.vn': 'Lê Nhân Viên',
    'customer@demo.vn': 'Nguyễn Khách',
  };

  @override
  Future<AccountProfile> getProfile() async {
    await MockDelay.short();
    final email = session?.email ?? '';
    final registered = store.find(email);
    final tenantId = session?.tenantId;
    final isMerchant = session?.role.isMerchant ?? false;
    return AccountProfile(
      email: email,
      fullName: registered?.request.fullName ?? _demoNames[email],
      phone: registered?.request.phone,
      storeName: isMerchant && tenantId != null
          ? CustomerShopMockRepository.all
                .where((s) => s.tenantId == tenantId)
                .firstOrNull
                ?.name
          : null,
    );
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    await MockDelay.short();
    final email = session?.email ?? '';
    if (currentPassword !=
        store.passwordFor(email, fallback: MockAccounts.password)) {
      throw const ApiException(
        type: ApiErrorType.validation,
        message: 'Mật khẩu hiện tại không chính xác',
        statusCode: 400,
      );
    }
    store.changePassword(email, newPassword);
  }
}
