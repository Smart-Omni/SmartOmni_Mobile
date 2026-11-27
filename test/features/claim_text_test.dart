import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartomni_mobile/core/design/design.dart';
import 'package:smartomni_mobile/features/loyalty/domain/loyalty_repository.dart';
import 'package:smartomni_mobile/features/loyalty/domain/loyalty_rules.dart';
import 'package:smartomni_mobile/features/loyalty/presentation/claim_result_screen.dart';
import 'package:smartomni_mobile/l10n/generated/app_localizations.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('vi'));

  test('chưa đủ 15 ngày: có ngày thì ghi ngày, thiếu ngày không lỗi', () {
    final (title, withDate, tone) = claimFailureText(
      ClaimFailure(
        ClaimEligibility.tooEarly,
        completedAt: DateTime(2026, 10, 10),
      ),
      l10n,
    );
    expect(title, 'Chưa đủ 15 ngày');
    expect(withDate, 'Đơn hoàn tất 10/10. Claim được từ 25/10/2026.');
    expect(tone, SoBannerTone.warning);

    final (_, noDate, _) = claimFailureText(
      const ClaimFailure(ClaimEligibility.tooEarly),
      l10n,
    );
    expect(noDate, 'Đơn chưa đủ 15 ngày kể từ khi hoàn tất.');
  });

  test('đã claim: thiếu ngày claim vẫn có câu đọc được', () {
    final (_, message, _) = claimFailureText(
      const ClaimFailure(ClaimEligibility.alreadyClaimed),
      l10n,
    );
    expect(message, 'Mỗi đơn chỉ claim một lần.');
  });

  test('BE báo ngày đủ điều kiện (không có ngày hoàn tất): hiện ngày BE', () {
    final (_, message, _) = claimFailureText(
      ClaimFailure(
        ClaimEligibility.tooEarly,
        eligibleFrom: DateTime(2026, 12, 9),
      ),
      l10n,
    );
    expect(message, contains('Claim được từ 09/12/2026.'));
  });

  test('chọn sàn, đang đồng bộ, thử sai nhiều: câu tiếng Việt từ arb', () {
    String msg(ClaimFailure f) => claimFailureText(f, l10n).$2;
    expect(
      msg(const ClaimFailure(ClaimEligibility.platformRequired)),
      l10n.claimErrPlatformRequired,
    );
    expect(
      msg(const ClaimFailure(ClaimEligibility.syncing)),
      contains('ít phút'),
    );
    expect(
      msg(const ClaimFailure(ClaimEligibility.tooManyAttempts)),
      l10n.claimErrTooManyLater,
    );
    expect(
      msg(
        const ClaimFailure(
          ClaimEligibility.tooManyAttempts,
          retryAfter: Duration(minutes: 5),
        ),
      ),
      'Tạm khóa claim, thử lại sau 5 phút.',
    );
  });
}
