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

  static String dateTime(DateTime? value) =>
      value == null ? '—' : _dateTime.format(value);

  static String date(DateTime? value) =>
      value == null ? '—' : _date.format(value);
}
