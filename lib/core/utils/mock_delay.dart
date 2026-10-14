/// Giả lập độ trễ mạng cho repository mock, để UI hiển thị trạng thái loading
/// giống khi gọi API thật.
///
/// Trong test đặt [MockDelay.enabled] = false để chạy nhanh.
class MockDelay {
  const MockDelay._();

  static bool enabled = true;

  static Future<void> short() => enabled
      ? Future.delayed(const Duration(milliseconds: 400))
      : Future.value();
}
