import 'package:flutter/material.dart';

import '../../features/loyalty/domain/loyalty_rules.dart';
import '../models/platform.dart';
import 'so_colors.dart';
import 'so_text.dart';
import 'so_tokens.dart';

/// Tông màu của nhãn trạng thái. Ánh xạ trạng thái đơn ở docs/DESIGN.md mục 6.
enum SoStatus { neutral, info, success, warning, danger, brand }

extension SoStatusColors on SoStatus {
  /// (nền, chữ + chấm tròn).
  (Color, Color) colors(SoColors c) => switch (this) {
    SoStatus.neutral => (c.fill, c.ink2),
    SoStatus.info => (c.infoTint, c.info),
    SoStatus.success => (c.successTint, c.success),
    SoStatus.warning => (c.warningTint, c.warning),
    SoStatus.danger => (c.dangerTint, c.danger),
    SoStatus.brand => (c.brandTint, c.brand),
  };
}

/// Nhãn trạng thái: capsule cao 24 nền `*Tint`, chấm tròn 6px + chữ
/// `caption` cùng màu trạng thái. Luôn có chữ, không chỉ màu.
class SoStatusTag extends StatelessWidget {
  const SoStatusTag({super.key, required this.label, required this.status});

  final String label;
  final SoStatus status;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = status.colors(context.soColors);
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: ShapeDecoration(
        color: bg,
        shape: SoShape.squircle(SoRadius.capsuleAll),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
            child: const SizedBox.square(dimension: 6),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            maxLines: 1,
            style: context.textTheme.labelSmall?.copyWith(color: fg),
          ),
        ],
      ),
    );
  }
}

/// Nhãn hạng khách hàng: capsule cao 24 (bản lớn 32), chữ caption 600, màu
/// theo hạng (DESIGN.md mục 2). Không viền.
class SoTierBadge extends StatelessWidget {
  const SoTierBadge({super.key, required this.tier, this.large = false});

  final LoyaltyTier tier;

  /// Cao 32 thay vì 24 (thẻ thành viên).
  final bool large;

  @override
  Widget build(BuildContext context) {
    final c = context.soColors;
    final (bg, fg) = switch (tier) {
      LoyaltyTier.standard => (c.tierStandardBg, c.tierStandardInk),
      LoyaltyTier.silver => (c.tierSilverBg, c.tierSilverInk),
      LoyaltyTier.platinum => (c.tierPlatinumBg, c.tierPlatinumInk),
      LoyaltyTier.diamond => (c.tierDiamondBg, c.tierDiamondInk),
    };
    return Container(
      height: large ? 32 : 24,
      padding: EdgeInsets.symmetric(
        horizontal: large ? SoSpace.s12 : SoSpace.s8,
      ),
      alignment: Alignment.center,
      decoration: ShapeDecoration(
        color: bg,
        shape: SoShape.squircle(SoRadius.capsuleAll),
      ),
      child: Text(
        tier.label,
        style: context.textTheme.labelSmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Kênh bán: chấm tròn 8px màu sàn + tên sàn `footnote` màu ink2.
///
/// Một `Text.rich` duy nhất nên dùng được cả trong chỗ không giới hạn bề
/// rộng (Row, Wrap) lẫn có giới hạn. Đặt cạnh mã đơn thì để mã đơn co lại,
/// không để tên sàn bị cắt.
class SoChannelTag extends StatelessWidget {
  const SoChannelTag({super.key, required this.platform});

  final Platform platform;

  @override
  Widget build(BuildContext context) {
    final c = context.soColors;
    final dot = switch (platform) {
      Platform.shopee => c.shopee,
      Platform.tiktokShop => c.tiktok,
    };
    return Text.rich(
      TextSpan(
        children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsets.only(right: 6),
              child: DecoratedBox(
                decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
                child: const SizedBox.square(dimension: 8),
              ),
            ),
          ),
          TextSpan(text: platform.label),
        ],
      ),
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
      style: context.textTheme.bodySmall?.copyWith(color: c.ink2),
    );
  }
}

/// Mã đơn / mã SKU / email demo: nền `fill`, bo squircle `sm` 10, chữ
/// `code` (JetBrains Mono 13), không viền.
class SoCodeTag extends StatelessWidget {
  const SoCodeTag(this.code, {super.key});

  final String code;

  @override
  Widget build(BuildContext context) {
    final c = context.soColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: SoSpace.s8, vertical: 3),
      decoration: ShapeDecoration(
        color: c.fill,
        shape: SoShape.squircle(SoRadius.smAll),
      ),
      child: Text(
        code,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: context.soText.code.copyWith(color: c.ink),
      ),
    );
  }
}

/// Nhãn "AI" cho nội dung do AI gợi ý: capsule nền brandTint, chữ caption
/// 600 màu brand.
class SoAiLabel extends StatelessWidget {
  const SoAiLabel({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.soColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: SoSpace.s8, vertical: 2),
      decoration: ShapeDecoration(
        color: c.brandTint,
        shape: SoShape.squircle(SoRadius.capsuleAll),
      ),
      child: Text(
        'AI',
        style: context.textTheme.labelSmall?.copyWith(
          color: c.brand,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
