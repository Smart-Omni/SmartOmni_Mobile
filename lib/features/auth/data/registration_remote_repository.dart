import 'package:dio/dio.dart';

import '../../../core/auth/session.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/api_paths.dart';
import '../../../core/network/api_response.dart';
import '../domain/registration.dart';
import 'auth_remote_repository.dart';

/// `POST /api/v1/auth/register` (`RegisterRequest` của BE). BE trả
/// `AuthResponse` ngay, không có bước OTP.
///
/// BE hiện bỏ qua `subdomain`: khách tạo ra chưa gắn cửa hàng nào
/// (docs/API_CONTRACT.md mục 0).
class RegistrationRemoteRepository implements RegistrationRepository {
  RegistrationRemoteRepository(this._dio);

  final Dio _dio;

  @override
  Future<Session?> register(RegistrationRequest request) async {
    try {
      final res = await _dio.post<Object?>(
        ApiPaths.register,
        data: {
          'email': request.email.trim(),
          'password': request.password,
          'full_name': request.fullName.trim(),
          'phone': request.phone.trim(),
          'subdomain': request.shopCode.trim().toLowerCase(),
        },
      );
      return unwrapResponse<Session>(
        res.data,
        (data) => sessionFromAuthResponse(data! as JsonMap),
      );
    } on DioException catch (e) {
      final error = ApiException.fromDio(e);
      // BE: 409 + EMAIL_ALREADY_EXISTS (errorCode chưa gửi ra, dựa vào 409).
      final taken =
          error.statusCode == 409 || error.code == 'EMAIL_ALREADY_EXISTS';
      throw taken
          ? const RegisterFailure(
              RegisterFailureKind.emailTaken,
              'Email này đã có tài khoản.',
            )
          : RegisterFailure(RegisterFailureKind.other, error.message);
    }
  }

  @override
  Future<void> resendOtp(String email) =>
      throw UnsupportedError('BE không có bước OTP');

  @override
  Future<Session> verifyEmail({required String email, required String otp}) =>
      throw UnsupportedError('BE không có bước OTP');
}
