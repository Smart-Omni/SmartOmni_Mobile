import 'package:flutter/material.dart';

import '../../features/loyalty/domain/loyalty_rules.dart';
import '../models/platform.dart';
import 'so_colors.dart';
import 'so_text.dart';
import 'so_tokens.dart';

/// Tông màu của nhãn trạng thái. Ánh xạ trạng thái đơn ở docs/DESIGN.md mục 6.
enum SoStatus { neutral, info, success, warning, danger, brand }

extension SoStatusColors on SoStatus {
  /// (nền, chữ + ô vuông).
  (Color, Color) colors(SoColors c) => switch (this) {
    SoStatus.neutral => (c.fill, c.ink2),
    SoStatus.info => (c.infoTint, c.info),
    SoStatus.success => (c.successTint, c.success),
    SoStatus.warning => (c.warningTint, c.warning),
    SoStatus.danger => (c.dangerTint, c.danger),
    SoStatus.brand => (c.brandTint, c.brand),
  };
}

/// Nhãn trạng thái cao 24: ô vuông 8px + chữ. Luôn có chữ, không chỉ màu.
class SoStatusTag extends StatelessWidget {
  const SoStatusTag({super.key, required this.label, required this.status});

  final String label;
  final SoStatus status;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = status.colors(context.soColors);
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: SoSpace.s8),
      decoration: BoxDecoration(color: bg, borderRadius: SoRadius.smAll),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 8, color: fg),
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

/// Nhãn hạng khách hàng, chữ caption 600.
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
      decoration: BoxDecoration(
        color: bg,
        borderRadius: SoRadius.smAll,
        border: tier == LoyaltyTier.standard
            ? Border.all(color: c.fillStrong)
            : null,
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

/// Kênh bán: ô vuông 10px màu sàn + tên sàn màu ink.
class SoChannelTag extends StatelessWidget {
  const SoChannelTag({super.key, required this.platform});

  final Platform platform;

  @override
  Widget build(BuildContext context) {
    final c = context.soColors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          color: switch (platform) {
            Platform.shopee => c.shopee,
            Platform.tiktokShop => c.tiktok,
          },
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            platform.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.textTheme.labelLarge?.copyWith(color: c.ink),
          ),
        ),
      ],
    );
  }
}

/// Mã đơn / mã SKU: khung viền 1px ink, chữ mono 12, như in trên tem.
class SoCodeTag extends StatelessWidget {
  const SoCodeTag(this.code, {super.key});

  final String code;

  @override
  Widget build(BuildContext context) {
    final c = context.soColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: SoRadius.smAll,
        border: Border.all(color: c.ink),
      ),
      child: Text(
        code,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: context.soText.code.copyWith(fontSize: 12, height: 16 / 12),
      ),
    );
  }
}

/// Nhãn "AI" cho nội dung do AI gợi ý.
class SoAiLabel extends StatelessWidget {
  const SoAiLabel({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.soColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: c.brandTint,
        borderRadius: SoRadius.smAll,
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
