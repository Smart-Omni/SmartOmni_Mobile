import 'package:flutter/services.dart';

import '../../../core/utils/mock_delay.dart';
import '../domain/shipping_label_repository.dart';

/// Mọi đơn dùng chung một tem mẫu 100×150 mm trong `assets/mock/`.
class ShippingLabelMockRepository implements ShippingLabelRepository {
  const ShippingLabelMockRepository();

  static const asset = 'assets/mock/shipping_label_sample.pdf';

  @override
  Future<Uint8List> fetchLabel(int orderId) async {
    await MockDelay.short();
    final data = await rootBundle.load(asset);
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }
}
