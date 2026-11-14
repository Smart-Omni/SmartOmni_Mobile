import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/config/api_availability.dart';
import '../../../app/config/app_config.dart';
import '../../../core/auth/session.dart';
import '../../../core/auth/user_role.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/storage/token_storage.dart';
import '../data/auth_mock_repository.dart';
import '../data/auth_remote_repository.dart';
import '../data/mock_account_store.dart';
import '../data/registration_mock_repository.dart';
import '../data/registration_remote_repository.dart';
import '../domain/auth_failure.dart';
import '../domain/auth_repository.dart';
import '../domain/registration.dart';

/// Tài khoản khách đăng ký mới ở chế độ mock, dùng chung cho đăng nhập,
/// đăng ký, cửa hàng và điểm mock.
final mockAccountStoreProvider = Provider<MockAccountStore>(
  (ref) => MockAccountStore(),
);

/// Chọn repository thật hoặc mock theo `api_availability.dart`.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return ref.watch(appConfigProvider).usesRemote(ApiFeature.auth)
      ? AuthRemoteRepository(ref.watch(dioProvider))
      : AuthMockRepository(store: ref.watch(mockAccountStoreProvider));
});

/// `true`: A-05 gọi BE thật (không OTP, mã cửa hàng chỉ kiểm định dạng).
final registerUseRemoteProvider = Provider<bool>(
  (ref) => ref.watch(appConfigProvider).usesRemote(ApiFeature.register),
);

final registrationRepositoryProvider = Provider<RegistrationRepository>(
  (ref) => ref.watch(registerUseRemoteProvider)
      ? RegistrationRemoteRepository(ref.watch(dioProvider))
      : RegistrationMockRepository(ref.watch(mockAccountStoreProvider)),
);

/// Trạng thái đăng nhập của app.
sealed class AuthState {
  const AuthState();
}

/// Đang đọc token đã lưu (màn hình splash).
class AuthUnknown extends AuthState {
  const AuthUnknown();
}

class Unauthenticated extends AuthState {
  const Unauthenticated({this.reason});

  /// Lý do bị đăng xuất (vd: phiên hết hạn) để hiển thị ở màn đăng nhập.
  final String? reason;
}

class Authenticated extends AuthState {
  const Authenticated(this.session);

  final Session session;
}

/// Quản lý phiên đăng nhập: khôi phục khi mở app, đăng nhập, đăng xuất.
class AuthController extends Notifier<AuthState> {
  StreamSubscription<SessionEndReason>? _expiredSub;

  @override
  AuthState build() {
    _expiredSub = ref
        .watch(sessionExpiredEventsProvider)
        .stream
        .listen(_expire);
    ref.onDispose(() => _expiredSub?.cancel());
    Future.microtask(_restore);
    return const AuthUnknown();
  }

  TokenStorage get _storage => ref.read(tokenStorageProvider);
  AuthRepository get _repo => ref.read(authRepositoryProvider);

  /// Mở app: dựng lại phiên đã lưu. Luôn rời [AuthUnknown], kể cả khi đọc
  /// token hay gia hạn gặp lỗi bất ngờ (lúc đó về đăng nhập, không xóa token).
  Future<void> _restore() async {
    AuthState next;
    try {
      next = await _restoredState();
    } catch (_) {
      next = const Unauthenticated();
    }
    if (ref.mounted) state = next;
  }

  Future<AuthState> _restoredState() async {
    final session = await _readSession();
    if (session == null || !session.role.isSupportedOnMobile) {
      return _signedOut();
    }
    if (!session.isExpired()) return Authenticated(session);

    // Access token hết hạn: gia hạn thay vì đăng xuất.
    final String? fresh;
    try {
      fresh = await ref.read(tokenRefresherProvider).refresh();
    } on TemporaryRefreshFailure {
      // Mất mạng / BE lỗi tạm: giữ phiên cũ và token, interceptor gia hạn ở
      // request sau.
      return Authenticated(session);
    }
    if (fresh == null) return _signedOut(); // BE từ chối refresh token.
    final renewed = await _readSession();
    return renewed == null || !renewed.role.isSupportedOnMobile
        ? _signedOut()
        : Authenticated(renewed);
  }

  Future<AuthState> _signedOut() async {
    await _storage.clear();
    return const Unauthenticated();
  }

  Future<Session?> _readSession() async {
    final token = await _storage.readToken();
    if (token == null) return null;
    return Session.fromToken(
      token,
      refreshToken: await _storage.readRefreshToken(),
    );
  }

  /// Đăng nhập. Ném [LoginFailure] (đã phân loại) để màn hình hiển thị lỗi.
  Future<void> login({required String email, required String password}) async {
    final Session session;
    try {
      session = await _repo.login(email: email.trim(), password: password);
    } on ApiException catch (e) {
      throw LoginFailure.fromApi(e);
    }

    if (!session.role.isSupportedOnMobile) {
      throw const LoginFailure(
        LoginFailureKind.superAdmin,
        'Tài khoản này không dùng được trên app mobile. '
        'Vui lòng đăng nhập Super Admin Console trên web.',
      );
    }

    await signIn(session);
  }

  /// Vào app bằng phiên đã có (vd. sau khi xác minh OTP đăng ký).
  Future<void> signIn(Session session) async {
    await _storage.writeTokens(
      access: session.accessToken,
      refresh: session.refreshToken,
    );
    state = Authenticated(session);
  }

  /// Đăng xuất, xóa cả access token và refresh token. [reason] hiện ở màn
  /// đăng nhập (vd. sau khi đổi mật khẩu).
  Future<void> logout({String? reason}) async {
    await _repo.logout();
    await _storage.clear();
    state = Unauthenticated(reason: reason);
  }

  Future<void> _expire(SessionEndReason reason) async {
    if (state is! Authenticated) return;
    await _storage.clear();
    state = Unauthenticated(
      reason: switch (reason) {
        SessionEndReason.expired =>
          'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
        SessionEndReason.revoked =>
          'Phiên đăng nhập đã bị thu hồi (tài khoản bị khóa hoặc đổi quyền). '
              'Vui lòng đăng nhập lại.',
      },
    );
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

/// Tiện ích: phiên hiện tại (null nếu chưa đăng nhập).
final currentSessionProvider = Provider<Session?>((ref) {
  final state = ref.watch(authControllerProvider);
  return state is Authenticated ? state.session : null;
});

final currentRoleProvider = Provider<UserRole?>(
  (ref) => ref.watch(currentSessionProvider)?.role,
);
