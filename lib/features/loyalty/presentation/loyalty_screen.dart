import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../core/design/design.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../customer_shop/presentation/customer_shop_providers.dart';
import '../../customer_shop/presentation/no_shop_state.dart';
import '../domain/loyalty_repository.dart';
import '../domain/loyalty_rules.dart';
import 'loyalty_providers.dart';

/// C-20 Điểm & hạng (DESIGN.md mục 8b, mockup glass): thẻ hạng kính, voucher,
/// lịch sử điểm của cửa hàng đang xem.
class LoyaltyScreen extends ConsumerWidget {
  const LoyaltyScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref
      ..invalidate(loyaltySummaryProvider)
      ..invalidate(vouchersProvider);
    await ref.read(loyaltySummaryProvider.future);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shopAsync = ref.watch(currentShopProvider);
    final shop = shopAsync.value;
    final summaryAsync = ref.watch(loyaltySummaryProvider);
    final summary = summaryAsync.value;
    final noShop = shopAsync.hasValue && shop == null;

    return SoScaffold(
      appBar: SoAppBar.root(
        title: 'Điểm & hạng',
        leading: shop == null
            ? null
            : SoShopSwitcher(
                key: const Key('shop_switcher'),
                name: shop.name,
                onTap: () => context.push(Routes.customerShops),
              ),
      ),
      onRefresh: summary != null ? () => _refresh(ref) : null,
      scrollable: summary != null || summaryAsync.hasError,
      slivers: [
        SliverPadding(
          padding: SoSpace.page,
          sliver: noShop
              ? const SliverToBoxAdapter(child: NoShopState())
              : summary != null
              ? SliverList.list(
                  children: [
                    const SoMockBanner(
                      message:
                          'Điểm, voucher và lịch sử là dữ liệu mẫu, backend '
                          'chưa có API.',
                    ),
                    const SizedBox(height: SoSpace.s16),
                    _TierCard(summary: summary),
                    const _Vouchers(),
                    const _SectionTitle('Lịch sử điểm'),
                    _History(entries: summary.history),
                  ],
                )
              : summaryAsync.hasError || shopAsync.hasError
              ? SliverToBoxAdapter(
                  child: SoEmptyState.error(
                    title: 'Không tải được điểm',
                    message: switch (summaryAsync.error ?? shopAsync.error) {
                      final ApiException e => e.message,
                      _ => null,
                    },
                    onAction: () => ref
                      ..invalidate(myShopsProvider)
                      ..invalidate(loyaltySummaryProvider),
                  ),
                )
              : const _Skeleton(),
        ),
      ],
    );
  }
}

/// Tiêu đề nhóm (title3) kèm số đếm, cách nhóm trước 28.
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {this.count});

  final String title;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        top: SoSpace.group,
        bottom: SoSpace.sectionTitle,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Flexible(child: Text(title, style: context.soText.title3)),
          if (count != null) ...[
            const SizedBox(width: SoSpace.s8),
            Text(
              '$count',
              style: context.textTheme.bodySmall?.copyWith(
                color: context.soColors.ink2,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Thẻ kính nổi bật duy nhất của màn: điểm, nhãn hạng, thanh 3 nấc, câu
/// "còn N điểm" kèm quy tắc tích điểm.
class _TierCard extends StatelessWidget {
  const _TierCard({required this.summary});

  final LoyaltySummary summary;

  @override
  Widget build(BuildContext context) {
    final c = context.soColors;
    final points = summary.totalPoints;
    final tier = summary.tier;
    final next = tier.next;
    final segments = LoyaltyRules.tierSegments(points);
    final ink2 = context.textTheme.bodyMedium?.copyWith(color: c.ink2);
    const rule =
        'Cứ 1.000 ₫ đã thanh toán được 1 điểm, không tính phí ship và thuế.';

    return SoGlass(
      key: const Key('tier_card'),
      padding: SoSpace.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Điểm tích lũy',
                      style: context.textTheme.bodySmall?.copyWith(
                        color: c.ink2,
                      ),
                    ),
                    Text(
                      Formatters.number(points),
                      key: const Key('tier_points'),
                      style: context.soText.metric,
                    ),
                  ],
                ),
              ),
              SoTierBadge(tier: tier, large: true),
            ],
          ),
          const SizedBox(height: SoSpace.s16),
          Semantics(
            label: next == null
                ? 'Đang ở hạng ${tier.label}, hạng cao nhất'
                : 'Đang ở hạng ${tier.label}, còn ${summary.pointsToNext} '
                      'điểm để lên ${next.label}',
            excludeSemantics: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    for (final (i, value) in segments.indexed) ...[
                      if (i > 0) const SizedBox(width: SoSpace.s4),
                      Expanded(child: _Segment(value: value)),
                    ],
                  ],
                ),
                const SizedBox(height: SoSpace.s8),
                Row(
                  children: [
                    for (final (i, t) in LoyaltyTier.values.skip(1).indexed)
                      Expanded(
                        child: Text(
                          '${t.label} · ${Formatters.number(t.minPoints)}',
                          textAlign: i == 2 ? TextAlign.end : TextAlign.start,
                          style: context.textTheme.labelSmall?.copyWith(
                            color: c.ink2,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: SoSpace.s16),
          Text.rich(
            key: const Key('tier_next'),
            next == null
                ? const TextSpan(text: 'Bạn đang ở hạng cao nhất. $rule')
                : TextSpan(
                    children: [
                      const TextSpan(text: 'Còn '),
                      TextSpan(
                        text: '${Formatters.number(summary.pointsToNext)} điểm',
                        style: TextStyle(
                          color: c.ink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      TextSpan(text: ' để lên ${next.label}. $rule'),
                    ],
                  ),
            style: ink2,
          ),
        ],
      ),
    );
  }
}

/// Một nấc của thanh hạng: rãnh fillStrong, phần đã đạt màu brand.
class _Segment extends StatelessWidget {
  const _Segment({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final c = context.soColors;
    final shape = SoShape.squircle(SoRadius.capsuleAll);
    return Container(
      height: 8,
      clipBehavior: Clip.antiAlias,
      decoration: ShapeDecoration(color: c.fillStrong, shape: shape),
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: value,
        heightFactor: 1,
        child: DecoratedBox(
          decoration: ShapeDecoration(color: c.brand, shape: shape),
        ),
      ),
    );
  }
}

/// Nhóm "Voucher của bạn": mỗi voucher một thẻ trắng.
class _Vouchers extends ConsumerWidget {
  const _Vouchers();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(vouchersProvider);
    final vouchers = async.value;
    final c = context.soColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionTitle('Voucher của bạn', count: vouchers?.length),
        if (vouchers == null && async.hasError)
          SoEmptyState.error(
            title: 'Không tải được voucher',
            onAction: () => ref.invalidate(vouchersProvider),
          )
        else if (vouchers == null)
          const SoSkeleton(height: 84, radius: SoRadius.lg)
        else if (vouchers.isEmpty)
          Container(
            padding: SoSpace.card,
            decoration: SoShape.card(c),
            child: Text(
              'Chưa có voucher. Cửa hàng sẽ gửi khi có ưu đãi.',
              style: context.textTheme.bodyMedium?.copyWith(color: c.ink2),
            ),
          )
        else
          for (final (i, v) in vouchers.indexed) ...[
            if (i > 0) const SizedBox(height: SoSpace.cardGap),
            _VoucherCard(voucher: v),
          ],
      ],
    );
  }
}

class _VoucherCard extends StatelessWidget {
  const _VoucherCard({required this.voucher});

  final CustomerVoucher voucher;

  @override
  Widget build(BuildContext context) {
    final c = context.soColors;
    final v = voucher;
    final daysLeft = LoyaltyRules.voucherDaysLeft(v.expiresAt, DateTime.now());
    final small = context.textTheme.bodySmall;
    final Widget? expiry = switch (daysLeft) {
      null => null,
      < 0 => Text('Đã hết hạn', style: small?.copyWith(color: c.ink2)),
      <= LoyaltyRules.voucherExpiringDays => Text(
        daysLeft == 0 ? 'Hết hạn hôm nay' : 'Hết hạn sau $daysLeft ngày',
        style: small?.copyWith(color: c.warning, fontWeight: FontWeight.w600),
      ),
      _ => Text(
        'HSD ${Formatters.date(v.expiresAt).substring(0, 5)}',
        style: small?.copyWith(color: c.ink2),
      ),
    };

    return Container(
      key: Key('voucher_${v.code}'),
      padding: SoSpace.card,
      decoration: SoShape.card(c),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(v.description, style: context.textTheme.titleMedium),
                const SizedBox(height: SoSpace.s8),
                Wrap(
                  spacing: SoSpace.s8,
                  runSpacing: SoSpace.s4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SoCodeTag(v.code),
                    SoChannelTag(platform: v.platform),
                    ?expiry,
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: SoSpace.s12),
          SoButton.secondary(
            key: Key('copy_${v.code}'),
            label: 'Sao chép',
            size: SoButtonSize.small,
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: v.code));
              if (context.mounted) {
                showSoToast(context, 'Đã sao chép ${v.code}');
              }
            },
          ),
        ],
      ),
    );
  }
}

/// Nhóm "Lịch sử điểm": một thẻ trắng, mỗi lần cộng điểm một hàng.
class _History extends StatelessWidget {
  const _History({required this.entries});

  final List<PointEntry> entries;

  @override
  Widget build(BuildContext context) {
    final c = context.soColors;
    if (entries.isEmpty) {
      return Container(
        padding: SoSpace.card,
        decoration: SoShape.card(c),
        child: Text(
          'Chưa có lần tích điểm nào.',
          style: context.textTheme.bodyMedium?.copyWith(color: c.ink2),
        ),
      );
    }
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: SoShape.card(c),
      child: Column(
        children: [
          for (final (i, e) in entries.indexed) ...[
            if (i > 0) const Divider(indent: SoSpace.s16),
            Padding(
              key: Key('history_${e.orderCode}'),
              padding: SoSpace.card,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: SoSpace.s8,
                          runSpacing: SoSpace.s4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            SoChannelTag(platform: e.platform),
                            Text(e.orderCode, style: context.soText.code),
                          ],
                        ),
                        const SizedBox(height: SoSpace.s4),
                        Text(
                          'Claim ngày ${Formatters.date(e.claimedAt)}',
                          style: context.textTheme.bodySmall?.copyWith(
                            color: c.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: SoSpace.s12),
                  Text(
                    '+${Formatters.number(e.points)}',
                    style: context.soText.money.copyWith(color: c.success),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Skeleton cùng hình thẻ hạng + nhóm voucher.
class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    return SliverList.list(
      children: [
        const SoSkeleton(height: 36, radius: SoRadius.capsule),
        const SizedBox(height: SoSpace.s16),
        Container(
          padding: SoSpace.card,
          decoration: SoShape.card(context.soColors),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SoSkeleton(width: 96, height: 14),
              SizedBox(height: SoSpace.s8),
              SoSkeleton(width: 120, height: 36),
              SizedBox(height: SoSpace.s16),
              SoSkeleton(height: 8),
              SizedBox(height: SoSpace.s16),
              SoSkeleton(height: 14),
            ],
          ),
        ),
        const SizedBox(height: SoSpace.group + 26 + SoSpace.sectionTitle),
        const SoSkeleton(height: 84, radius: SoRadius.lg),
      ],
    );
  }
}
