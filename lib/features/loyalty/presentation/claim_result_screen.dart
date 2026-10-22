import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/router/routes.dart';
import '../../../core/design/design.dart';
import '../../../core/utils/formatters.dart';
import '../domain/loyalty_repository.dart';
import '../domain/loyalty_rules.dart';

/// Kết quả một lần claim, truyền từ C-30 sang màn kết quả (GoRouter `extra`).
class ClaimOutcome {
  const ClaimOutcome.success(ClaimResult this.result, {required this.shopName})
    : failure = null;

  const ClaimOutcome.failure(
    ClaimFailure this.failure, {
    required this.shopName,
  }) : result = null;

  final ClaimResult? result;
  final ClaimFailure? failure;
  final String shopName;
}

/// Việc C-30 làm tiếp khi màn kết quả đóng.
enum ClaimNext {
  /// "Claim đơn khác": xóa mã đơn cũ.
  another,

  /// "Sửa mã đơn": giữ nguyên sàn và mã để sửa.
  edit,
}

/// Tiêu đề, mô tả, màu banner cho từng loại lỗi claim (DESIGN.md mục 8b).
(String, String, SoBannerTone) claimFailureText(ClaimFailure f) {
  // Backend có thể không trả ngày: khi đó vẫn có câu đọc được.
  final completedAt = f.completedAt;
  final claimedAt = f.claimedAt;
  return switch (f.kind) {
    ClaimEligibility.tooEarly => (
      'Chưa đủ 15 ngày',
      completedAt == null
          ? 'Đơn chưa đủ 15 ngày kể từ khi hoàn tất.'
          : 'Đơn hoàn tất ${Formatters.date(completedAt).substring(0, 5)}. '
                'Claim được từ ${Formatters.date(f.claimableFrom)}.',
      SoBannerTone.warning,
    ),
    ClaimEligibility.alreadyClaimed => (
      'Đơn đã được claim',
      [
        if (claimedAt != null) 'Đã claim ngày ${Formatters.date(claimedAt)}.',
        'Mỗi đơn chỉ claim một lần.',
      ].join(' '),
      SoBannerTone.danger,
    ),
    ClaimEligibility.notFound => (
      'Không tìm thấy đơn',
      'Kiểm tra lại mã và sàn đã chọn.',
      SoBannerTone.danger,
    ),
    ClaimEligibility.notCompleted => (
      'Đơn chưa hoàn tất',
      'Sàn chưa xác nhận hoàn tất. Nhận hàng xong chờ thêm 15 ngày.',
      SoBannerTone.warning,
    ),
    ClaimEligibility.tooManyAttempts => (
      'Thử sai quá nhiều lần',
      'Tạm khóa claim, thử lại sau '
          '${(f.retryAfter ?? Duration.zero).inMinutes.clamp(1, 999)} phút.',
      SoBannerTone.danger,
    ),
    ClaimEligibility.eligible => throw StateError('Claim hợp lệ không có lỗi'),
  };
}

/// C-30 kết quả: thẻ kính thành công, hoặc banner lỗi + "Sửa mã đơn".
class ClaimResultScreen extends StatelessWidget {
  const ClaimResultScreen({super.key, required this.outcome});

  /// `null` khi mở thẳng route (không đi từ C-30).
  final ClaimOutcome? outcome;

  @override
  Widget build(BuildContext context) {
    final outcome = this.outcome;
    final result = outcome?.result;
    final failure = outcome?.failure;
    return SoScaffold(
      appBar: const SoAppBar(title: 'Kết quả claim'),
      slivers: [
        SliverPadding(
          padding: SoSpace.page,
          sliver: SliverList.list(
            children: [
              if (result != null)
                _SuccessCard(result: result, shopName: outcome!.shopName)
              else if (failure != null)
                ..._failure(context, failure)
              else
                SoEmptyState(
                  title: 'Không có kết quả claim',
                  actionLabel: 'Về Claim đơn',
                  onAction: () => context.go(Routes.customerClaim),
                ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _failure(BuildContext context, ClaimFailure f) {
    final (title, message, tone) = claimFailureText(f);
    return [
      SoBanner(
        key: Key('claim_error_${f.kind.name}'),
        tone: tone,
        title: title,
        message: message,
      ),
      const SizedBox(height: SoSpace.s16),
      SoButton(
        key: const Key('claim_edit'),
        label: 'Sửa mã đơn',
        expand: true,
        onPressed: () => context.pop(ClaimNext.edit),
      ),
    ];
  }
}

/// Thẻ kính thành công: +điểm, mã đơn, đã thanh toán, điểm cũ → mới, lên
/// hạng (nếu có); Claim đơn khác / Xem hạng.
class _SuccessCard extends StatelessWidget {
  const _SuccessCard({required this.result, required this.shopName});

  final ClaimResult result;
  final String shopName;

  @override
  Widget build(BuildContext context) {
    final c = context.soColors;
    final r = result;
    return SoGlass(
      key: const Key('claim_success'),
      padding: SoSpace.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: c.successTint,
                  shape: BoxShape.circle,
                ),
                child: Icon(LucideIcons.check, color: c.success),
              ),
              const SizedBox(width: SoSpace.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '+${Formatters.number(r.points)} điểm',
                      style: context.soText.metricSm,
                    ),
                    Text(
                      '$shopName · ${Formatters.dateTime(r.claimedAt)}',
                      style: context.textTheme.bodySmall?.copyWith(
                        color: c.ink2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: SoSpace.s16),
          _Row(label: 'Mã đơn', value: SoCodeTag(r.orderCode)),
          const SizedBox(height: SoSpace.s8),
          _Row(
            label: 'Đã thanh toán',
            value: Text(
              Formatters.vnd(r.amountPaid),
              style: context.soText.money,
            ),
          ),
          const SizedBox(height: SoSpace.s8),
          _Row(
            label: 'Điểm',
            value: Text(
              '${Formatters.number(r.pointsBefore)} → '
              '${Formatters.number(r.pointsAfter)}',
              key: const Key('claim_points_change'),
              style: context.soText.money,
            ),
          ),
          if (r.tieredUp) ...[
            const SizedBox(height: SoSpace.s16),
            Container(
              key: const Key('claim_tier_up'),
              padding: const EdgeInsets.all(SoSpace.s12),
              decoration: ShapeDecoration(
                color: c.surface,
                shape: SoShape.squircle(SoRadius.mdAll),
              ),
              child: Wrap(
                spacing: SoSpace.s8,
                runSpacing: SoSpace.s8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SoTierBadge(tier: r.tierBefore),
                  Icon(
                    LucideIcons.chevronRight,
                    size: SoSize.iconSmall,
                    color: c.muted,
                  ),
                  SoTierBadge(tier: r.tierAfter),
                  Text('Bạn đã lên hạng', style: context.textTheme.titleMedium),
                ],
              ),
            ),
          ],
          const SizedBox(height: SoSpace.s16),
          Row(
            children: [
              Expanded(
                child: SoButton.secondary(
                  key: const Key('claim_another'),
                  label: 'Claim đơn khác',
                  onPressed: () => context.pop(ClaimNext.another),
                ),
              ),
              const SizedBox(width: SoSpace.s12),
              Expanded(
                child: SoButton(
                  key: const Key('claim_view_tier'),
                  label: 'Xem hạng',
                  onPressed: () => context.go(Routes.customerLoyalty),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Nhãn footnote ink2 bên trái, giá trị bên phải.
class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final Widget value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: context.textTheme.bodySmall?.copyWith(
              color: context.soColors.ink2,
            ),
          ),
        ),
        value,
      ],
    );
  }
}
