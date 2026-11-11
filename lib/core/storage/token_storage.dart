import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Nơi lưu JWT và refresh token. Tách thành interface để test có thể thay
/// bằng bản lưu trong RAM.
abstract class TokenStorage {
  Future<String?> readToken();
  Future<String?> readRefreshToken();

  /// Ghi cả cặp token. [refreshToken] `null` thì xóa refresh token cũ.
  Future<void> writeTokens({required String access, String? refresh});

  /// Xóa cả access token và refresh token.
  Future<void> clear();
}

/// Lưu token an toàn: Keychain (iOS) / Android Keystore (Android).
class SecureTokenStorage implements TokenStorage {
  SecureTokenStorage([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'smartomni_access_token';
  static const _refreshKey = 'smartomni_refresh_token';
  final FlutterSecureStorage _storage;

  @override
  Future<String?> readToken() => _storage.read(key: _key);

  @override
  Future<String?> readRefreshToken() => _storage.read(key: _refreshKey);

  @override
  Future<void> writeTokens({required String access, String? refresh}) async {
    await _storage.write(key: _key, value: access);
    if (refresh == null) {
      await _storage.delete(key: _refreshKey);
    } else {
      await _storage.write(key: _refreshKey, value: refresh);
    }
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _key);
    await _storage.delete(key: _refreshKey);
  }
}

/// Bản lưu trong bộ nhớ, dùng cho test.
class InMemoryTokenStorage implements TokenStorage {
  InMemoryTokenStorage([this._token, this._refresh]);

  String? _token;
  String? _refresh;

  @override
  Future<String?> readToken() async => _token;

  @override
  Future<String?> readRefreshToken() async => _refresh;

  @override
  Future<void> writeTokens({required String access, String? refresh}) async {
    _token = access;
    _refresh = refresh;
  }

  @override
  Future<void> clear() async => _token = _refresh = null;
}

final tokenStorageProvider = Provider<TokenStorage>(
  (ref) => SecureTokenStorage(),
);
