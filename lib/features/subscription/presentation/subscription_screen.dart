import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/design.dart';
import '../../../core/utils/formatters.dart';
import '../../account/presentation/account_providers.dart';
import '../../account/presentation/account_widgets.dart';
import '../domain/subscription.dart';
import 'checkout_sheet.dart';
import 'subscription_providers.dart';

/// T-40 Gói dịch vụ (chỉ Tenant Admin, chặn ở `resolveRedirect`).
///
/// Thẻ kính: tên gói, trạng thái, hạn, số ngày còn lại (theo
/// `/subscription/status`; M-51 vẫn theo `planType` của `tenants/me`, xem
/// lỗi P5). Thẻ trắng "Mức đã dùng" (luôn mẫu, lỗi P3). Nhóm "Hóa đơn". Nút
/// Thanh toán / Nâng cấp PRO chỉ khi [SubscriptionSummary.canPay]. "Đổi gói"
/// (hạ cấp) BE chưa có nên không hiện.
class SubscriptionScreen extends ConsumerWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(subscriptionStatusProvider);
    final summary = async.value;
    final remote = ref.watch(subscriptionUseRemoteProvider);

    return SoScaffold(
      scrollable: summary != null || async.hasError,
      appBar: const SoAppBar(title: 'Gói dịch vụ'),
      bottomBar: summary != null && summary.canPay
          ? SoActionBar(
              primary: SoButton(
                key: const Key('plan_pay'),
                label: summary.status == PlanStatus.free
                    ? 'Nâng cấp PRO'
                    : 'Thanh toán',
                onPressed: () => _openCheckout(context, ref),
              ),
            )
          : null,
      slivers: [
        SliverPadding(
          padding: SoSpace.page,
          sliver: SliverList.list(
            children: [
              if (!remote) ...[
                const SoMockBanner(
                  message: 'Gói, hóa đơn, hạn mức là dữ liệu mẫu.',
                ),
                const SizedBox(height: SoSpace.s16),
              ],
              if (summary != null)
                _Body(summary: summary, remote: remote)
              else if (async.hasError && !async.isLoading)
                SoEmptyState.error(
                  key: const Key('plan_error'),
                  title: 'Không tải được gói dịch vụ',
                  message: 'Kiểm tra kết nối mạng rồi thử lại.',
                  onAction: () => ref.invalidate(subscriptionStatusProvider),
                )
              else
                const _Skeleton(),
            ],
          ),
        ),
      ],
    );
  }

  /// Đóng sheet với `true` = đã thanh toán: tải lại gói, hóa đơn và
  /// `tenants/me` (để M-51 mở khóa).
  Future<void> _openCheckout(BuildContext context, WidgetRef ref) async {
    final paid = await showCheckoutSheet(context);
    if (paid != true || !context.mounted) return;
    ref
      ..invalidate(subscriptionStatusProvider)
      ..invalidate(subscriptionInvoicesProvider)
      ..invalidate(accountProfileProvider);
    showSoToast(context, 'Thanh toán thành công. Cửa hàng đã ở gói PRO.');
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.summary, required this.remote});

  final SubscriptionSummary summary;
  final bool remote;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoices = ref.watch(subscriptionInvoicesProvider);
    final unpaid = [
      for (final i in invoices.value ?? const <Invoice>[])
        if (!i.paid) i,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PlanCard(summary: summary),
        if (unpaid.isNotEmpty) ...[
          const SizedBox(height: SoSpace.s12),
          SoBanner(
            key: const Key('plan_unpaid'),
            tone: SoBannerTone.warning,
            title: '${unpaid.length} hóa đơn chưa thanh toán',
            message:
                'Tổng ${Formatters.vnd(unpaid.fold<num>(0, (t, i) => t + i.amount))}',
          ),
        ],
        const GroupTitle('Mức đã dùng'),
        if (remote) ...[
          const SoMockBanner(
            key: Key('usage_mock'),
            message: 'Hạn mức và mức đã dùng là dữ liệu mẫu, chờ backend.',
          ),
          const SizedBox(height: SoSpace.s12),
        ],
        const _UsageCard(),
        const GroupTitle('Hóa đơn'),
        _Invoices(async: invoices),
      ],
    );
  }
}

/// Thẻ kính nổi bật duy nhất của màn: tên gói, trạng thái, hạn.
class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.summary});

  final SubscriptionSummary summary;

  @override
  Widget build(BuildContext context) {
    final s = summary;
    final ink2 = context.textTheme.bodyMedium?.copyWith(
      color: context.soColors.ink2,
    );
    final (label, status) = switch (s.status) {
      PlanStatus.free => ('Miễn phí', SoStatus.neutral),
      PlanStatus.active => ('Đang dùng', SoStatus.success),
      PlanStatus.expiringSoon => ('Sắp hết hạn', SoStatus.warning),
      PlanStatus.expired => ('Đã hết hạn', SoStatus.danger),
    };
    final end = s.periodEnd;
    final detail = switch (s.status) {
      PlanStatus.free => 'Nâng cấp PRO để dùng dự báo nhu cầu bằng AI.',
      PlanStatus.expired =>
        end == null ? 'Gói PRO đã hết hạn.' : 'Hết hạn ${Formatters.date(end)}',
      _ =>
        '${end == null ? 'Còn' : 'Hết hạn ${Formatters.date(end)} · còn'} '
            '${s.daysRemaining} ngày',
    };
    final name = s.planName.toUpperCase() == 'FREE' ? 'Free' : s.planName;
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
                child: Text(
                  name,
                  key: const Key('plan_name'),
                  style: context.textTheme.titleLarge,
                ),
              ),
              SoStatusTag(
                key: const Key('plan_status'),
                label: label,
                status: status,
              ),
            ],
          ),
          const SizedBox(height: SoSpace.s8),
          Text(detail, key: const Key('plan_detail'), style: ink2),
        ],
      ),
    );
  }
}

/// Thẻ trắng ba hạn mức (dữ liệu mẫu).
class _UsageCard extends ConsumerWidget {
  const _UsageCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usage = ref.watch(subscriptionUsageProvider).value;
    if (usage == null) {
      return const SoSkeleton(height: 168, radius: SoRadius.lg);
    }
    return Container(
      padding: SoSpace.card,
      decoration: SoShape.card(context.soColors),
      child: Column(
        children: [
          _UsageRow(
            key: const Key('usage_skus'),
            label: 'Số SKU',
            unit: 'SKU',
            quota: usage.skus,
          ),
          const SizedBox(height: SoSpace.s16),
          _UsageRow(
            key: const Key('usage_connections'),
            label: 'Kết nối sàn',
            unit: 'kết nối',
            quota: usage.connections,
          ),
          const SizedBox(height: SoSpace.s16),
          _UsageRow(
            key: const Key('usage_storage'),
            label: 'Dung lượng ảnh',
            unit: 'GB',
            quota: usage.imageStorageGb,
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

/// Nhóm "Hóa đơn": đang tải / lỗi + Thử lại / rỗng / danh sách.
class _Invoices extends ConsumerWidget {
  const _Invoices({required this.async});

  final AsyncValue<List<Invoice>> async;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = async.value;
    if (list == null) {
      if (async.hasError && !async.isLoading) {
        return SoBanner(
          key: const Key('invoices_error'),
          tone: SoBannerTone.danger,
          title: 'Không tải được hóa đơn',
          actionLabel: 'Thử lại',
          onAction: () => ref.invalidate(subscriptionInvoicesProvider),
        );
      }
      return const SoSkeletonList(count: 3);
    }
    if (list.isEmpty) {
      return Text(
        'Chưa có hóa đơn nào.',
        key: const Key('invoices_empty'),
        style: context.textTheme.bodyMedium?.copyWith(
          color: context.soColors.ink2,
        ),
      );
    }
    return SoListGroup(
      children: [for (final i in list) _InvoiceRow(invoice: i)],
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
    final (start, end) = (i.periodStart, i.periodEnd);
    final paidAt = i.paidAt;
    final due = i.dueDate;
    final parts = [
      if (start != null && end != null)
        '${Formatters.date(start)} – ${Formatters.date(end)}',
      if (i.paid && paidAt != null) 'Trả ${Formatters.date(paidAt)}',
      if (!i.paid && due != null) 'Hạn ${Formatters.date(due)}',
    ];
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
              Expanded(child: Text(parts.join(' · '), style: text.bodySmall)),
              const SizedBox(width: SoSpace.s8),
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
