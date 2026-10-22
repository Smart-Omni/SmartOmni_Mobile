import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/router/routes.dart';
import '../../../core/design/design.dart';
import '../../../core/models/platform.dart';
import '../../../core/utils/clock.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/input_formatters.dart';
import '../../../core/utils/text_fold.dart';
import '../../account/presentation/account_widgets.dart';
import '../../loyalty/domain/loyalty_rules.dart';
import '../domain/voucher.dart';
import 'voucher_providers.dart';

/// T-30 Phát voucher cho khách (chỉ Tenant Admin, chặn ở `resolveRedirect`).
///
/// Thẻ form: Phát cho (hạng trở lên / chọn từng khách), Sàn (khóa sàn không
/// hỗ trợ), Giá trị giảm, Đơn tối thiểu, Hạn dùng. Bấm phát -> sheet xác nhận
/// -> đợt mới "Đang tạo" ở nhóm "Đợt phát gần đây". Email chỉ gửi khi sàn xác
/// nhận tạo thành công (F-T4).
class VoucherScreen extends ConsumerStatefulWidget {
  const VoucherScreen({super.key});

  @override
  ConsumerState<VoucherScreen> createState() => _VoucherScreenState();
}

class _VoucherScreenState extends ConsumerState<VoucherScreen> {
  final _formKey = GlobalKey<FormState>();
  final _discount = TextEditingController();
  final _minOrder = TextEditingController();
  VoucherAudience _audience = const TierAudience(LoyaltyTier.silver);
  Platform? _platform;
  int _days = voucherValidDays.first;
  bool _busy = false;

  /// Làm mới danh sách một lần sau khi phát, để thấy đợt mới đổi trạng thái.
  Timer? _recheck;

  @override
  void dispose() {
    _discount.dispose();
    _minOrder.dispose();
    _recheck?.cancel();
    super.dispose();
  }

  /// Sàn đang chọn; mặc định là sàn đầu tiên tạo được voucher.
  Platform? _selectedPlatform(VoucherSetup setup) =>
      _platform ??
      Platform.values
          .where((p) => setup.supportOf(p) == VoucherSupport.available)
          .firstOrNull;

  Future<void> _pickCustomers(VoucherSetup setup) async {
    final current = _audience;
    final picked = await showSoBottomSheet<Set<int>>(
      context: context,
      builder: (_) => _PickCustomersSheet(
        customers: setup.customers,
        initial: current is PickedAudience ? current.customerIds : const {},
      ),
    );
    if (picked != null && picked.isNotEmpty && mounted) {
      setState(() => _audience = PickedAudience(picked));
    }
  }

  Future<void> _submit(VoucherSetup setup) async {
    if (_busy) return;
    final platform = _selectedPlatform(setup);
    if (platform == null || !_formKey.currentState!.validate()) return;

    final discount = VndInputFormatter.parse(_discount.text)!;
    final minOrder = VndInputFormatter.parse(_minOrder.text)!;
    final expiresAt = voucherExpiry(ref.read(clockProvider)(), _days);
    final audience = _audience;
    final ids = audienceIds(setup.customers, audience);

    final ok = await showSoBottomSheet<bool>(
      context: context,
      builder: (sheetContext) => SoBottomSheet(
        title: 'Phát voucher cho ${ids.length} khách?',
        secondary: SoButton.secondary(
          key: const Key('voucher_confirm_cancel'),
          label: 'Hủy',
          onPressed: () => Navigator.pop(sheetContext, false),
        ),
        primary: SoButton(
          key: const Key('voucher_confirm'),
          label: 'Phát voucher',
          onPressed: () => Navigator.pop(sheetContext, true),
        ),
        child: _Summary(
          rows: [
            ('Đối tượng', '${audienceLabel(audience)} · ${ids.length} khách'),
            ('Sàn', platform.label),
            ('Giảm', Formatters.vnd(discount)),
            ('Đơn tối thiểu', Formatters.vnd(minOrder)),
            ('Hết hạn', Formatters.date(expiresAt)),
          ],
        ),
      ),
    );
    if (!(ok ?? false) || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref
          .read(voucherRepositoryProvider)
          .issue(
            VoucherDraft(
              platform: platform,
              discount: discount,
              minOrder: minOrder,
              expiresAt: expiresAt,
              audience: audienceLabel(audience),
              customerIds: ids,
            ),
          );
      ref.invalidate(voucherBatchesProvider);
      _recheck?.cancel();
      _recheck = Timer(
        const Duration(seconds: 4),
        () => ref.invalidate(voucherBatchesProvider),
      );
      // Xóa số tiền để không bấm phát lặp lại cùng một đợt.
      _discount.clear();
      _minOrder.clear();
      if (mounted) {
        showSoToast(
          context,
          'Đã gửi yêu cầu tạo voucher lên ${platform.label}',
        );
      }
    } catch (_) {
      if (mounted) {
        showSoToast(
          context,
          'Chưa gửi được yêu cầu. Kiểm tra kết nối mạng rồi thử lại.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final setupAsync = ref.watch(voucherSetupProvider);
    final setup = setupAsync.value;
    final platform = setup == null ? null : _selectedPlatform(setup);
    final count = setup == null ? 0 : audienceCount(setup.customers, _audience);
    final canIssue = setup != null && platform != null && count > 0;

    return SoScaffold(
      scrollable: setup != null || setupAsync.hasError,
      appBar: const SoAppBar(title: 'Phát voucher'),
      onRefresh: () async {
        ref.invalidate(voucherBatchesProvider);
        try {
          await ref.read(voucherBatchesProvider.future);
        } catch (_) {
          // Lỗi đã hiện trong nhóm "Đợt phát gần đây".
        }
      },
      bottomBar: SoActionBar(
        primary: SoButton(
          key: const Key('voucher_submit'),
          label: canIssue
              ? 'Phát cho $count khách trên ${platform.label}'
              : 'Phát voucher',
          loading: _busy,
          onPressed: canIssue ? () => _submit(setup) : null,
        ),
      ),
      slivers: [
        SliverPadding(
          padding: SoSpace.page,
          sliver: SliverList.list(
            children: [
              const SoMockBanner(
                message: 'Khách và đợt phát là dữ liệu mẫu, chưa gọi API sàn.',
              ),
              const SizedBox(height: SoSpace.s16),
              if (setup != null)
                _form(setup, platform, count)
              else if (setupAsync.hasError && !setupAsync.isLoading)
                SoEmptyState.error(
                  key: const Key('voucher_setup_error'),
                  title: 'Không tải được danh sách khách',
                  message: 'Kiểm tra kết nối mạng rồi thử lại.',
                  onAction: () => ref.invalidate(voucherSetupProvider),
                )
              else
                const SoSkeleton(height: 420, radius: SoRadius.lg),
              const GroupTitle('Đợt phát gần đây'),
              const _Batches(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _form(VoucherSetup setup, Platform? platform, int count) {
    final c = context.soColors;
    final text = context.textTheme;
    final picked = _audience is PickedAudience;
    final now = ref.watch(clockProvider)();

    Widget label(String s) => Padding(
      padding: const EdgeInsets.only(bottom: SoSpace.s8),
      child: Text(s, style: text.titleSmall),
    );
    Widget help(String s, {Key? key, Color? color}) => Padding(
      padding: const EdgeInsets.only(top: SoSpace.s8),
      child: Text(
        s,
        key: key,
        style: text.bodySmall?.copyWith(color: color ?? c.ink2),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (platform == null) ...[
          SoBanner(
            key: const Key('voucher_no_platform'),
            tone: SoBannerTone.warning,
            title: 'Chưa có sàn nào tạo được voucher',
            message: 'Kết nối shop Shopee hoặc TikTok Shop để phát voucher.',
            actionLabel: 'Kết nối sàn',
            onAction: () => context.push(Routes.merchantMarketplace),
          ),
          const SizedBox(height: SoSpace.s16),
        ],
        Container(
          padding: SoSpace.card,
          decoration: SoShape.card(c),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                label('Phát cho'),
                Wrap(
                  spacing: SoSpace.s8,
                  runSpacing: SoSpace.s8,
                  children: [
                    for (final tier in LoyaltyTier.values)
                      SoFilterChip(
                        key: Key('voucher_tier_${tier.name}'),
                        label: audienceLabel(TierAudience(tier)),
                        count: countFromTier(setup.customers, tier),
                        selected: switch (_audience) {
                          TierAudience(:final fromTier) => fromTier == tier,
                          PickedAudience() => false,
                        },
                        onSelected: () =>
                            setState(() => _audience = TierAudience(tier)),
                      ),
                    SoFilterChip(
                      key: const Key('voucher_pick'),
                      label: picked
                          ? audienceLabel(_audience)
                          : 'Chọn từng khách',
                      selected: picked,
                      onSelected: () => _pickCustomers(setup),
                    ),
                  ],
                ),
                if (count == 0)
                  help(
                    'Chưa có khách nào ở hạng này.',
                    key: const Key('voucher_no_customers'),
                    color: c.warning,
                  ),
                const SizedBox(height: SoSpace.s20),
                label('Sàn'),
                SoSegmented<Platform>(
                  key: const Key('voucher_platform'),
                  selected: platform ?? Platform.values.first,
                  onChanged: (p) => setState(() => _platform = p),
                  segments: [
                    for (final p in Platform.values)
                      SoSegment(
                        value: p,
                        label: p.label,
                        enabled: setup.supportOf(p) == VoucherSupport.available,
                      ),
                  ],
                ),
                for (final p in Platform.values)
                  if (setup.supportOf(p) case final s
                      when s != VoucherSupport.available)
                    help(
                      s == VoucherSupport.unsupported
                          ? '${p.label} chưa cho tạo voucher qua API.'
                          : 'Chưa kết nối ${p.label}. Kết nối ở mục Kết nối sàn.',
                      key: Key('voucher_locked_${p.name}'),
                    ),
                const SizedBox(height: SoSpace.s20),
                SoTextField(
                  key: const Key('voucher_discount'),
                  label: 'Giá trị giảm',
                  hint: 'Vd: 30.000',
                  controller: _discount,
                  keyboardType: TextInputType.number,
                  inputFormatters: const [VndInputFormatter()],
                  textInputAction: TextInputAction.next,
                  suffixText: '₫',
                  validator: (v) =>
                      validateDiscount(VndInputFormatter.parse(v ?? '')),
                ),
                const SizedBox(height: SoSpace.s16),
                SoTextField(
                  key: const Key('voucher_min_order'),
                  label: 'Đơn tối thiểu',
                  hint: 'Vd: 200.000',
                  controller: _minOrder,
                  keyboardType: TextInputType.number,
                  inputFormatters: const [VndInputFormatter()],
                  textInputAction: TextInputAction.done,
                  suffixText: '₫',
                  validator: (v) => validateMinOrder(
                    VndInputFormatter.parse(v ?? ''),
                    VndInputFormatter.parse(_discount.text),
                  ),
                ),
                const SizedBox(height: SoSpace.s20),
                label('Hạn dùng'),
                Wrap(
                  spacing: SoSpace.s8,
                  children: [
                    for (final d in voucherValidDays)
                      SoFilterChip(
                        key: Key('voucher_days_$d'),
                        label: '$d ngày',
                        selected: _days == d,
                        onSelected: () => setState(() => _days = d),
                      ),
                  ],
                ),
                help(
                  'Hết hạn ${Formatters.date(voucherExpiry(now, _days))}',
                  key: const Key('voucher_expiry'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: SoSpace.s12),
        const SoBanner(
          tone: SoBannerTone.info,
          title: 'Email gửi sau khi sàn xác nhận',
          message:
              'Chỉ gửi email cho khách khi sàn xác nhận tạo voucher thành công.',
        ),
      ],
    );
  }
}

/// Bảng tóm tắt trong sheet xác nhận: nhãn trái, giá trị phải.
class _Summary extends StatelessWidget {
  const _Summary({required this.rows});

  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    final text = context.textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (label, value) in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: SoSpace.s8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: text.bodyMedium?.copyWith(
                      color: context.soColors.ink2,
                    ),
                  ),
                ),
                Text(value, style: text.titleSmall),
              ],
            ),
          ),
        const SizedBox(height: SoSpace.s8),
        Text(
          'Email chỉ gửi cho khách khi sàn xác nhận tạo thành công.',
          style: text.bodySmall?.copyWith(color: context.soColors.ink2),
        ),
      ],
    );
  }
}

/// Nhóm "Đợt phát gần đây".
class _Batches extends ConsumerWidget {
  const _Batches();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(voucherBatchesProvider);
    final batches = async.value;
    if (batches == null) {
      if (async.hasError && !async.isLoading) {
        return SoEmptyState.error(
          key: const Key('voucher_batches_error'),
          title: 'Không tải được đợt phát',
          message: 'Kiểm tra kết nối mạng rồi thử lại.',
          onAction: () => ref.invalidate(voucherBatchesProvider),
        );
      }
      return const SoSkeletonList(count: 3);
    }
    if (batches.isEmpty) {
      return Text(
        'Chưa có đợt phát nào.',
        key: const Key('voucher_batches_empty'),
        style: context.textTheme.bodyMedium?.copyWith(
          color: context.soColors.ink2,
        ),
      );
    }
    return SoListGroup(
      children: [for (final b in batches) _BatchRow(batch: b)],
    );
  }
}

class _BatchRow extends StatelessWidget {
  const _BatchRow({required this.batch});

  final VoucherBatch batch;

  @override
  Widget build(BuildContext context) {
    final b = batch;
    final c = context.soColors;
    final text = context.textTheme;
    final (label, status) = switch (b.status) {
      VoucherBatchStatus.creating => ('Đang tạo', SoStatus.info),
      VoucherBatchStatus.success => ('Thành công', SoStatus.success),
      VoucherBatchStatus.failed => ('Lỗi', SoStatus.danger),
      VoucherBatchStatus.unknown => ('Chưa rõ · đối soát', SoStatus.warning),
    };
    final note = switch (b.status) {
      VoucherBatchStatus.creating => 'Đang chờ sàn xác nhận, chưa gửi email.',
      VoucherBatchStatus.success => 'Đã gửi email ${b.customerCount} khách.',
      VoucherBatchStatus.failed => b.failureReason ?? 'Sàn không tạo được.',
      VoucherBatchStatus.unknown =>
        'Kiểm tra trên sàn trước khi phát lại để tránh tạo trùng.',
    };
    return Container(
      key: Key('voucher_batch_${b.id}'),
      color: c.surface,
      padding: SoSpace.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  'Giảm ${Formatters.vnd(b.discount)} · đơn từ '
                  '${Formatters.vnd(b.minOrder)}',
                  style: text.titleMedium,
                ),
              ),
              const SizedBox(width: SoSpace.s8),
              SoStatusTag(label: label, status: status),
            ],
          ),
          const SizedBox(height: SoSpace.s4),
          Wrap(
            spacing: SoSpace.s8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SoChannelTag(platform: b.platform),
              Text(
                '${b.audience} · ${b.customerCount} khách · '
                '${Formatters.dateTime(b.createdAt)}',
                style: text.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: SoSpace.s4),
          Text(
            note,
            style: text.bodySmall?.copyWith(
              color: switch (b.status) {
                VoucherBatchStatus.failed => c.danger,
                VoucherBatchStatus.unknown => c.warning,
                _ => c.ink2,
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Sheet "Chọn từng khách": tìm theo tên / email, chạm để chọn.
class _PickCustomersSheet extends StatefulWidget {
  const _PickCustomersSheet({required this.customers, required this.initial});

  final List<VoucherCustomer> customers;
  final Set<int> initial;

  @override
  State<_PickCustomersSheet> createState() => _PickCustomersSheetState();
}

class _PickCustomersSheetState extends State<_PickCustomersSheet> {
  late final _selected = {...widget.initial};
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final c = context.soColors;
    final q = foldVietnamese(_query.trim());
    final shown = [
      for (final cu in widget.customers)
        if (q.isEmpty ||
            foldVietnamese(cu.name).contains(q) ||
            cu.email.contains(q))
          cu,
    ];
    return SoBottomSheet(
      title: 'Chọn khách',
      secondary: SoButton.secondary(
        key: const Key('pick_cancel'),
        label: 'Hủy',
        onPressed: () => Navigator.pop(context),
      ),
      primary: SoButton(
        key: const Key('pick_done'),
        label: _selected.isEmpty
            ? 'Chọn khách'
            : 'Chọn ${_selected.length} khách',
        onPressed: _selected.isEmpty
            ? null
            : () => Navigator.pop(context, _selected),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SoTextField(
            key: const Key('pick_search'),
            label: 'Tìm khách',
            hint: 'Tên hoặc email',
            prefix: Icon(LucideIcons.search, color: c.ink2),
            onChanged: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: SoSpace.s12),
          if (shown.isEmpty)
            Text(
              'Không có khách khớp "$_query".',
              style: context.textTheme.bodyMedium?.copyWith(color: c.ink2),
            )
          else
            SoListGroup(
              children: [
                for (final cu in shown)
                  SoListRow(
                    key: Key('pick_${cu.id}'),
                    title: cu.name,
                    subtitle: cu.email,
                    onTap: () => setState(
                      () => _selected.contains(cu.id)
                          ? _selected.remove(cu.id)
                          : _selected.add(cu.id),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SoTierBadge(tier: cu.tier),
                        const SizedBox(width: SoSpace.s12),
                        Icon(
                          _selected.contains(cu.id)
                              ? LucideIcons.squareCheck
                              : LucideIcons.square,
                          color: _selected.contains(cu.id) ? c.brand : c.muted,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
