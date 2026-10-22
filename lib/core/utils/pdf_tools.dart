import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

/// Một trang PDF đã vẽ thành ảnh PNG (kèm kích thước điểm ảnh để giữ tỉ lệ).
class PdfPageImage {
  const PdfPageImage(this.png, this.width, this.height);

  final Uint8List png;
  final int width;
  final int height;
}

/// Xem trước / chia sẻ / in PDF bằng gói `printing` (hộp thoại của hệ điều
/// hành, không cần quyền). Đặt sau provider để widget test thay bằng bản giả.
class PdfTools {
  const PdfTools();

  /// Vẽ mọi trang ở [dpi] (250 ≈ 1.000 px cho tem rộng 100 mm, đủ nét khi
  /// phóng to).
  Future<List<PdfPageImage>> rasterize(Uint8List pdf, {double dpi = 250}) =>
      Printing.raster(pdf, dpi: dpi)
          .asyncMap(
            (page) async =>
                PdfPageImage(await page.toPng(), page.width, page.height),
          )
          .toList();

  /// Mở bảng chia sẻ của hệ điều hành.
  Future<void> share(Uint8List pdf, String filename) =>
      Printing.sharePdf(bytes: pdf, filename: filename);

  /// Mở hộp thoại in; xong khi người dùng in hoặc hủy.
  Future<void> printPdf(Uint8List pdf, String jobName) =>
      Printing.layoutPdf(onLayout: (_) => pdf, name: jobName);
}

final pdfToolsProvider = Provider<PdfTools>((ref) => const PdfTools());
