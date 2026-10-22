import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/design.dart';
import '../../../core/utils/clock.dart';
import '../../../core/utils/formatters.dart';
import '../../account/presentation/account_widgets.dart';
import '../domain/subscription.dart';
import 'subscription_providers.dart';

/// T-40 Gói dịch vụ (chỉ Tenant Admin, chặn ở `resolveRedirect`).
///
/// Thẻ kính: tên gói, hạn, nhãn trạng thái. Thẻ trắng "Mức đã dùng": SKU, kết
/// nối sàn, dung lượng ảnh. Nhóm "Hóa đơn". Đổi gói / Thanh toán chưa làm
/// trong app (toast "Sắp có").
class SubscriptionScreen extends ConsumerWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(subscriptionOverviewProvider);
    final data = async.value;
    final now = ref.watch(clockProvider)();

    return SoScaffold(
      scrollable: data != null || async.hasError,
      appBar: const SoAppBar(title: 'Gói dịch vụ'),
      bottomBar: SoActionBar(
        secondary: SoButton.secondary(
          key: const Key('plan_change'),
          label: 'Đổi gói',
          onPressed: () => showSoToast(context, 'Đổi gói sắp có'),
        ),
        primary: SoButton(
          key: const Key('plan_pay'),
          label: 'Thanh toán',
          onPressed: () => showSoToast(context, 'Thanh toán sắp có'),
        ),
      ),
      slivers: [
        SliverPadding(
          padding: SoSpace.page,
          sliver: SliverList.list(
            children: [
              const SoMockBanner(
                message: 'Tên gói, giá, hạn mức là dữ liệu mẫu, chờ backend.',
              ),
              const SizedBox(height: SoSpace.s16),
              if (data != null)
                _Body(data: data, now: now)
              else if (async.hasError && !async.isLoading)
                SoEmptyState.error(
                  key: const Key('plan_error'),
                  title: 'Không tải được gói dịch vụ',
                  message: 'Kiểm tra kết nối mạng rồi thử lại.',
                  onAction: () => ref.invalidate(subscriptionOverviewProvider),
                )
              else
                const _Skeleton(),
            ],
          ),
        ),
      ],
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.data, required this.now});

  final SubscriptionOverview data;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final s = data.subscription;
    final unpaid = data.unpaid;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PlanCard(subscription: s, now: now),
        if (unpaid.isNotEmpty) ...[
          const SizedBox(height: SoSpace.s12),
          SoBanner(
            key: const Key('plan_unpaid'),
            tone: SoBannerTone.warning,
            title: '${unpaid.length} hóa đơn chưa thanh toán',
            message: unpaid.length == 1
                ? '${Formatters.vnd(unpaid.first.amount)} · hạn '
                      '${Formatters.date(unpaid.first.dueDate)}'
                : 'Tổng ${Formatters.vnd(unpaid.fold<int>(0, (t, i) => t + i.amount))}',
          ),
        ],
        const GroupTitle('Mức đã dùng'),
        Container(
          padding: SoSpace.card,
          decoration: SoShape.card(context.soColors),
          child: Column(
            children: [
              _UsageRow(
                key: const Key('usage_skus'),
                label: 'Số SKU',
                unit: 'SKU',
                quota: s.skus,
              ),
              const SizedBox(height: SoSpace.s16),
              _UsageRow(
                key: const Key('usage_connections'),
                label: 'Kết nối sàn',
                unit: 'kết nối',
                quota: s.connections,
              ),
              const SizedBox(height: SoSpace.s16),
              _UsageRow(
                key: const Key('usage_storage'),
                label: 'Dung lượng ảnh',
                unit: 'GB',
                quota: s.imageStorageGb,
              ),
            ],
          ),
        ),
        const GroupTitle('Hóa đơn'),
        if (data.invoices.isEmpty)
          Text(
            'Chưa có hóa đơn nào.',
            key: const Key('invoices_empty'),
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.soColors.ink2,
            ),
          )
        else
          SoListGroup(
            children: [for (final i in data.invoices) _InvoiceRow(invoice: i)],
          ),
      ],
    );
  }
}

/// Thẻ kính nổi bật duy nhất của màn: tên gói, hạn, nhãn trạng thái.
class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.subscription, required this.now});

  final Subscription subscription;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final s = subscription;
    final (label, status) = switch (planStatus(s.expiresAt, now)) {
      PlanStatus.active => ('Đang dùng', SoStatus.success),
      PlanStatus.expiringSoon => ('Sắp hết hạn', SoStatus.warning),
      PlanStatus.expired => ('Đã hết hạn', SoStatus.danger),
    };
    return SoGlass(
      key: const Key('plan_card'),
      padding: SoSpace.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Gói hiện tại', style: context.textTheme.bodySmall),
          const SizedBox(height: SoSpace.s4),
          Row(
            children: [
              Expanded(
                child: Text(s.planName, style: context.textTheme.titleLarge),
              ),
              SoStatusTag(
                key: const Key('plan_status'),
                label: label,
                status: status,
              ),
            ],
          ),
          const SizedBox(height: SoSpace.s8),
          Text(
            'Hết hạn ${Formatters.date(s.expiresAt)}',
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.soColors.ink2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Nhãn + "đã dùng / tối đa" + thanh capsule màu theo [usageLevel].
class _UsageRow extends StatelessWidget {
  const _UsageRow({
    super.key,
    required this.label,
    required this.unit,
    required this.quota,
  });

  final String label;
  final String unit;
  final UsageQuota quota;

  @override
  Widget build(BuildContext context) {
    final c = context.soColors;
    final text = context.textTheme;
    final limit = quota.limit;
    final level = usageLevel(quota);
    final (color, note) = switch (level) {
      UsageLevel.normal => (c.brand, null),
      UsageLevel.near => (c.warning, 'Sắp chạm hạn mức'),
      UsageLevel.full => (c.danger, 'Đã hết hạn mức'),
    };
    final amount = limit == null
        ? '${Formatters.number(quota.used)} $unit · Không giới hạn'
        : '${Formatters.number(quota.used)} / ${Formatters.number(limit)} $unit';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: text.titleSmall)),
            Text(amount, style: context.soText.money),
          ],
        ),
        if (limit != null) ...[
          const SizedBox(height: SoSpace.s8),
          SoProgressBar(
            value: limit <= 0 ? 1 : quota.used / limit,
            color: color,
            semanticsLabel: '$label $amount${note == null ? '' : ', $note'}',
          ),
        ],
        if (note != null) ...[
          const SizedBox(height: SoSpace.s4),
          Text(note, style: text.bodySmall?.copyWith(color: color)),
        ],
      ],
    );
  }
}

class _InvoiceRow extends StatelessWidget {
  const _InvoiceRow({required this.invoice});

  final Invoice invoice;

  @override
  Widget build(BuildContext context) {
    final i = invoice;
    final text = context.textTheme;
    return Container(
      key: Key('invoice_${i.code}'),
      color: context.soColors.surface,
      padding: SoSpace.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Flexible(child: SoCodeTag(i.code)),
              const SizedBox(width: SoSpace.s12),
              const Spacer(),
              Text(Formatters.vnd(i.amount), style: context.soText.money),
            ],
          ),
          const SizedBox(height: SoSpace.s8),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Tháng ${i.period.month}/${i.period.year}'
                  '${i.paid ? '' : ' · hạn ${Formatters.date(i.dueDate)}'}',
                  style: text.bodySmall,
                ),
              ),
              i.paid
                  ? const SoStatusTag(
                      label: 'Đã thanh toán',
                      status: SoStatus.success,
                    )
                  : const SoStatusTag(
                      label: 'Chưa thanh toán',
                      status: SoStatus.warning,
                    ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Skeleton cùng hình thẻ gói + thẻ mức dùng + nhóm hóa đơn.
class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) => const Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SoSkeleton(height: 104, radius: SoRadius.lg),
      SizedBox(height: SoSpace.group + 28),
      SoSkeleton(height: 168, radius: SoRadius.lg),
      SizedBox(height: SoSpace.group + 28),
      SoSkeletonList(count: 3),
    ],
  );
}
