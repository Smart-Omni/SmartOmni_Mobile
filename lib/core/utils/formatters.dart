import 'package:intl/intl.dart';

/// Định dạng hiển thị dùng chung.
class Formatters {
  const Formatters._();

  static final _vnd = NumberFormat.decimalPattern('vi_VN');
  static final _dateTime = DateFormat('dd/MM/yyyy HH:mm');
  static final _date = DateFormat('dd/MM/yyyy');

  /// 1250000 -> "1.250.000 ₫"
  static String vnd(num? amount) =>
      amount == null ? '—' : '${_vnd.format(amount)} ₫';

  /// 1250 -> "1.250"
  static String number(num? value) => value == null ? '—' : _vnd.format(value);

  /// Số tiền rút gọn cho ô chỉ số: 3870000 -> "3,87 tr", 1250000000 -> "1,25 tỷ".
  /// Dưới 1 triệu thì hiện đầy đủ ("870.000 ₫").
  static String compactVnd(num amount) {
    final abs = amount.abs();
    if (abs >= 1e9) return '${_short(amount / 1e9)} tỷ';
    if (abs >= 1e6) return '${_short(amount / 1e6)} tr';
    return vnd(amount);
  }

  static String _short(num value) =>
      NumberFormat('#,##0.##', 'vi_VN').format(value);

  /// 0.634 -> "63%"
  static String percent(double ratio) => '${(ratio * 100).round()}%';

  /// 14:05
  static String time(DateTime? value) =>
      value == null ? '—' : DateFormat('HH:mm').format(value);

  static String dateTime(DateTime? value) =>
      value == null ? '—' : _dateTime.format(value);

  static String date(DateTime? value) =>
      value == null ? '—' : _date.format(value);
}
