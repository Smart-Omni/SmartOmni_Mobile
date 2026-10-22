import 'dart:typed_data';

/// ⚠️ Backend chưa có API tem vận đơn (đề xuất
/// `GET /api/orders/{id}/shipping-label` trả PDF, docs/API_CONTRACT.md) -> mock.
abstract interface class ShippingLabelRepository {
  /// File PDF tem do sàn tạo cho đơn [orderId].
  ///
  /// Ném [LabelNotReadyException] khi sàn chưa tạo tem.
  Future<Uint8List> fetchLabel(int orderId);
}

/// Sàn chưa tạo tem cho đơn: thử lại sau, không phải lỗi mạng.
class LabelNotReadyException implements Exception {
  const LabelNotReadyException();
}
