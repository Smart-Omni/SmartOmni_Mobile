import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/config/app_config.dart';
import '../../../core/auth/session.dart';
import '../../../core/auth/user_role.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/storage/token_storage.dart';
import '../data/auth_mock_repository.dart';
import '../data/auth_remote_repository.dart';
import '../domain/auth_failure.dart';
import '../domain/auth_repository.dart';

/// Chọn repository thật hoặc mock theo cấu hình `USE_MOCK`.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  return config.useMock
      ? AuthMockRepository()
      : AuthRemoteRepository(ref.watch(dioProvider));
});

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
  StreamSubscription<void>? _expiredSub;

  @override
  AuthState build() {
    _expiredSub = ref
        .watch(sessionExpiredEventsProvider)
        .stream
        .listen((_) => _expire());
    ref.onDispose(() => _expiredSub?.cancel());
    Future.microtask(_restore);
    return const AuthUnknown();
  }

  TokenStorage get _storage => ref.read(tokenStorageProvider);
  AuthRepository get _repo => ref.read(authRepositoryProvider);

  Future<void> _restore() async {
    final token = await _storage.readToken();
    final session = token == null ? null : Session.fromToken(token);
    if (!ref.mounted) return;
    if (session == null ||
        session.isExpired() ||
        !session.role.isSupportedOnMobile) {
      await _storage.clear();
      state = const Unauthenticated();
      return;
    }
    state = Authenticated(session);
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

    await _storage.writeToken(session.accessToken);
    state = Authenticated(session);
  }

  Future<void> logout() async {
    await _repo.logout();
    await _storage.clear();
    state = const Unauthenticated();
  }

  Future<void> _expire() async {
    if (state is! Authenticated) return;
    await _storage.clear();
    state = const Unauthenticated(
      reason: 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
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
