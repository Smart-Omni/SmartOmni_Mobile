import 'package:flutter_test/flutter_test.dart';
import 'package:smartomni_mobile/core/design/design.dart';
import 'package:smartomni_mobile/features/loyalty/domain/loyalty_repository.dart';
import 'package:smartomni_mobile/features/loyalty/domain/loyalty_rules.dart';
import 'package:smartomni_mobile/features/loyalty/presentation/claim_result_screen.dart';

void main() {
  test('chưa đủ 15 ngày: có ngày thì ghi ngày, thiếu ngày không lỗi', () {
    final (title, withDate, tone) = claimFailureText(
      ClaimFailure(
        ClaimEligibility.tooEarly,
        completedAt: DateTime(2026, 10, 10),
      ),
    );
    expect(title, 'Chưa đủ 15 ngày');
    expect(withDate, 'Đơn hoàn tất 10/10. Claim được từ 25/10/2026.');
    expect(tone, SoBannerTone.warning);

    final (_, noDate, _) = claimFailureText(
      const ClaimFailure(ClaimEligibility.tooEarly),
    );
    expect(noDate, 'Đơn chưa đủ 15 ngày kể từ khi hoàn tất.');
  });

  test('đã claim: thiếu ngày claim vẫn có câu đọc được', () {
    final (_, message, _) = claimFailureText(
      const ClaimFailure(ClaimEligibility.alreadyClaimed),
    );
    expect(message, 'Mỗi đơn chỉ claim một lần.');
  });
}
