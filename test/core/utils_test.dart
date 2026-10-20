import 'package:flutter_test/flutter_test.dart';
import 'package:smartomni_mobile/core/utils/formatters.dart';
import 'package:smartomni_mobile/core/utils/input_formatters.dart';
import 'package:smartomni_mobile/core/utils/validators.dart';

void main() {
  group('Validators', () {
    test('email', () {
      expect(Validators.email(''), isNotNull);
      expect(Validators.email('abc'), isNotNull);
      expect(Validators.email('a@b.vn'), isNull);
    });

    test('mật khẩu mới tối thiểu 8 ký tự (khớp backend)', () {
      expect(Validators.newPassword('1234567'), isNotNull);
      expect(Validators.newPassword('12345678'), isNull);
    });

    test('số lượng tồn không âm', () {
      expect(Validators.nonNegativeInt('-1'), isNotNull);
      expect(Validators.nonNegativeInt('abc'), isNotNull);
      expect(Validators.nonNegativeInt('0'), isNull);
      expect(Validators.nonNegativeInt('15'), isNull);
    });
  });

  group('Formatters', () {
    test('định dạng tiền VND', () {
      expect(Formatters.vnd(1250000), '1.250.000 ₫');
      expect(Formatters.vnd(null), '—');
    });

    test('định dạng ngày', () {
      expect(Formatters.date(DateTime(2026, 10, 4)), '04/10/2026');
      expect(
        Formatters.dateTime(DateTime(2026, 10, 4, 9, 5)),
        '04/10/2026 09:05',
      );
    });
  });

  group('Ô giá VND (M-32)', () {
    String type(String text) => const VndInputFormatter()
        .formatEditUpdate(TextEditingValue.empty, TextEditingValue(text: text))
        .text;

    test('tự thêm dấu chấm nghìn, bỏ ký tự không phải số', () {
      expect(type('159000'), '159.000');
      expect(type('1.590.0000'), '15.900.000');
      expect(type('00012'), '12');
      expect(type('abc'), '');
    });

    test('quá 12 chữ số thì giữ giá trị cũ', () {
      const old = TextEditingValue(text: '999.999.999.999');
      final next = const VndInputFormatter().formatEditUpdate(
        old,
        const TextEditingValue(text: '9999999999990'),
      );
      expect(next, old);
    });

    test('parse + positiveVnd', () {
      expect(VndInputFormatter.parse('159.000'), 159000);
      expect(Validators.positiveVnd(''), isNotNull);
      expect(Validators.positiveVnd('0'), isNotNull);
      expect(Validators.positiveVnd('159.000'), isNull);
    });
  });
}
