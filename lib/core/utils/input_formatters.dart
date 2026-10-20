import 'package:flutter/services.dart';

import 'formatters.dart';

/// Ô tiền VND: chỉ nhận chữ số, tự thêm dấu chấm nghìn khi gõ
/// ("159000" → "159.000"). Đọc lại số bằng [parse].
class VndInputFormatter extends TextInputFormatter {
  const VndInputFormatter();

  /// Tối đa 12 chữ số (999 tỷ), đủ cho giá bán và không tràn `int`.
  static const maxDigits = 12;

  static int? parse(String text) =>
      int.tryParse(text.replaceAll(RegExp(r'\D'), ''));

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return TextEditingValue.empty;
    if (digits.length > maxDigits) return oldValue;
    final text = Formatters.number(int.parse(digits));
    // shortcut: con trỏ luôn về cuối, sửa giữa số sẽ nhảy con trỏ; giữ vị trí
    // nếu người dùng phàn nàn.
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// Mã SKU: chỉ chữ không dấu, số và "-", viết hoa (vd. "at 001-m" → "AT001-M").
final skuCodeFormatters = <TextInputFormatter>[
  FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9-]')),
  TextInputFormatter.withFunction(
    (oldValue, newValue) =>
        newValue.copyWith(text: newValue.text.toUpperCase()),
  ),
];
