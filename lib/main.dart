import 'app/bootstrap.dart';
import 'app/config/app_config.dart';

/// Entry mặc định khi chạy `flutter run` không chỉ định `-t` -> môi trường dev.
///
/// Android có flavor nên cần thêm `--flavor dev`:
///   flutter run --flavor dev
/// iOS (chưa cấu hình flavor):
///   flutter run
void main() => bootstrap(Flavor.dev);
