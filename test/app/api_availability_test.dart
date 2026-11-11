import 'package:flutter_test/flutter_test.dart';
import 'package:smartomni_mobile/app/config/api_availability.dart';
import 'package:smartomni_mobile/app/config/app_config.dart';

void main() {
  AppConfig config({required bool useMock}) => AppConfig(
    flavor: Flavor.dev,
    apiBaseUrl: 'http://localhost:8080',
    useMock: useMock,
  );

  test('chế độ mock: không chức năng nào gọi API thật', () {
    final c = config(useMock: true);
    for (final f in ApiFeature.values) {
      expect(c.usesRemote(f), isFalse, reason: f.name);
    }
  });

  test('BE thật: chỉ chức năng đã nối mới gọi API thật', () {
    final c = config(useMock: false);
    for (final f in ApiFeature.values) {
      expect(c.usesRemote(f), connectedFeatures.contains(f), reason: f.name);
    }
    expect(c.usesRemote(ApiFeature.auth), isTrue);
  });
}
