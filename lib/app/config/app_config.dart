import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Môi trường chạy app. Mỗi flavor có entry point riêng: `lib/main_<flavor>.dart`.
enum Flavor { dev, staging, prod }

/// Cấu hình theo môi trường.
///
/// Giá trị có thể ghi đè khi chạy bằng `--dart-define`, ví dụ:
/// ```
/// flutter run --flavor dev -t lib/main_dev.dart \
///   --dart-define=API_BASE_URL=http://192.168.1.10:8080 \
///   --dart-define=USE_MOCK=false
/// ```
class AppConfig {
  const AppConfig({
    required this.flavor,
    required this.apiBaseUrl,
    required this.useMock,
    this.connectTimeout = const Duration(seconds: 15),
    this.receiveTimeout = const Duration(seconds: 20),
  });

  final Flavor flavor;

  /// Địa chỉ Nginx Gateway của backend (cổng 8080).
  final String apiBaseUrl;

  /// `true`: mọi repository dùng dữ liệu giả (không cần backend).
  /// `false`: gọi API thật cho các chức năng backend đã có; các chức năng
  /// backend chưa có API vẫn dùng mock (xem docs/API_CONTRACT.md).
  final bool useMock;

  final Duration connectTimeout;
  final Duration receiveTimeout;

  bool get isProd => flavor == Flavor.prod;

  static const _baseUrlOverride = String.fromEnvironment('API_BASE_URL');
  static const _useMockOverride = String.fromEnvironment('USE_MOCK');

  /// Tạo config mặc định cho từng flavor, có áp dụng giá trị `--dart-define`.
  factory AppConfig.forFlavor(Flavor flavor) {
    final defaults = switch (flavor) {
      // 10.0.2.2 = "localhost của máy tính" khi chạy trên Android Emulator.
      Flavor.dev => const AppConfig(
        flavor: Flavor.dev,
        apiBaseUrl: 'http://10.0.2.2:8080',
        useMock: true,
      ),
      Flavor.staging => const AppConfig(
        flavor: Flavor.staging,
        apiBaseUrl: 'https://staging-api.smartomni.example',
        useMock: false,
      ),
      Flavor.prod => const AppConfig(
        flavor: Flavor.prod,
        apiBaseUrl: 'https://api.smartomni.example',
        useMock: false,
      ),
    };

    return AppConfig(
      flavor: flavor,
      apiBaseUrl: _baseUrlOverride.isNotEmpty
          ? _baseUrlOverride
          : defaults.apiBaseUrl,
      useMock: _useMockOverride.isNotEmpty
          ? _useMockOverride.toLowerCase() == 'true'
          : defaults.useMock,
    );
  }
}

/// Provider chứa cấu hình. Được override trong `bootstrap()` cho từng flavor.
final appConfigProvider = Provider<AppConfig>(
  (ref) => throw UnimplementedError(
    'appConfigProvider phải được override trong bootstrap()',
  ),
);
