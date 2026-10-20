import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/router/routes.dart';
import '../../../core/design/design.dart';
import '../../../core/models/platform.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/input_formatters.dart';
import '../../../core/utils/validators.dart';
import '../../account/presentation/account_widgets.dart';
import '../../customer_shop/presentation/customer_shop_providers.dart';
import '../domain/loyalty_repository.dart';
import '../domain/loyalty_rules.dart';
import 'claim_result_screen.dart';
import 'loyalty_providers.dart';

/// C-30 Claim đơn (DESIGN.md mục 8b): khách chọn sàn, nhập mã đơn đã mua để
/// cộng điểm cho cửa hàng đang xem; kết quả ở màn con "Kết quả claim".
class ClaimOrderScreen extends ConsumerStatefulWidget {
  const ClaimOrderScreen({super.key});

  @override
  ConsumerState<ClaimOrderScreen> createState() => _ClaimOrderScreenState();
}

class _ClaimOrderScreenState extends ConsumerState<ClaimOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeCtrl = TextEditingController();
  Platform _platform = Platform.shopee;
  bool _busy = false;
  bool _scanTapped = false;

  /// Thử sai quá nhiều lần: khóa nút Claim tới lúc này.
  DateTime? _lockedUntil;

  bool get _locked =>
      _lockedUntil != null && DateTime.now().isBefore(_lockedUntil!);

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || _locked) return;
    if (!_formKey.currentState!.validate()) return;
    final shop = await ref.read(currentShopProvider.future);
    if (shop == null || !mounted) return;
    setState(() => _busy = true);
    ClaimOutcome? outcome;
    try {
      final result = await ref
          .read(loyaltyRepositoryProvider)
          .claimOrder(
            tenantId: shop.tenantId,
            platform: _platform,
            orderCode: _codeCtrl.text,
          );
      ref.invalidate(loyaltySummaryProvider);
      outcome = ClaimOutcome.success(result, shopName: shop.name);
    } on ClaimFailure catch (f) {
      if (f.kind == ClaimEligibility.tooManyAttempts) {
        _lockedUntil = DateTime.now().add(f.retryAfter ?? Duration.zero);
      }
      outcome = ClaimOutcome.failure(f, shopName: shop.name);
    } catch (e) {
      if (mounted) {
        showSoToast(
          context,
          e is ApiException ? e.message : 'Kiểm tra kết nối mạng rồi thử lại.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (outcome == null || !mounted) return;
    final next = await context.push<ClaimNext>(
      Routes.customerClaimResult,
      extra: outcome,
    );
    if (next == ClaimNext.another && mounted) {
      setState(() {
        _codeCtrl.clear();
        _scanTapped = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.soColors;
    final shopAsync = ref.watch(currentShopProvider);
    final shop = shopAsync.value;

    return SoScaffold(
      appBar: SoAppBar.root(
        title: 'Claim đơn',
        leading: shop == null
            ? null
            : SoShopSwitcher(
                key: const Key('shop_switcher'),
                name: shop.name,
                onTap: () => context.push(Routes.customerShops),
              ),
      ),
      slivers: [
        SliverPadding(
          padding: SoSpace.page,
          sliver: SliverToBoxAdapter(
            child: shopAsync.hasValue && shop == null
                ? SoEmptyState(
                    icon: LucideIcons.store,
                    title: 'Bạn chưa tham gia cửa hàng nào',
                    message: 'Nhập mã cửa hàng để xem sản phẩm và tích điểm.',
                    actionLabel: 'Thêm cửa hàng',
                    onAction: () => context.push(Routes.customerShops),
                  )
                // Form dựng hết một lần (không lười) để validate() thấy mọi ô.
                : Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SoMockBanner(
                          message:
                              'Thử: 240920SHOP01 (Shopee, hợp lệ), '
                              '241008SHOP02 (chưa đủ 15 ngày), 241012SHOP03 '
                              '(chưa hoàn tất).',
                        ),
                        const SizedBox(height: SoSpace.s16),
                        Text(
                          'Nhập mã đơn đã mua trên sàn để cộng điểm cho '
                          '${shop?.name ?? 'cửa hàng'}.',
                          style: context.textTheme.bodyMedium?.copyWith(
                            color: c.ink2,
                          ),
                        ),
                        const SizedBox(height: SoSpace.s16),
                        _formCard(context),
                        const GroupTitle('Điều kiện'),
                        const _Conditions(),
                      ],
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _formCard(BuildContext context) {
    final c = context.soColors;
    final lockedUntil = _lockedUntil;
    return Container(
      padding: SoSpace.card,
      decoration: SoShape.card(c),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Mua trên sàn',
            style: context.textTheme.labelLarge?.copyWith(color: c.ink2),
          ),
          const SizedBox(height: SoSpace.s4),
          SoSegmented<Platform>(
            key: const Key('claim_platform'),
            selected: _platform,
            onChanged: (p) => setState(() => _platform = p),
            segments: [
              for (final p in Platform.values)
                SoSegment(value: p, label: p.label),
            ],
          ),
          const SizedBox(height: SoSpace.s16),
          SoTextField(
            key: const Key('claim_code'),
            label: 'Mã đơn hàng',
            controller: _codeCtrl,
            hint: 'Vd: 240920SHOP01',
            mono: true,
            inputFormatters: orderCodeFormatters,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            helper: _scanTapped
                ? 'Quét mã sắp có, hãy nhập mã đơn.'
                : 'Xem ở mục Đơn mua của app sàn.',
            validator: (v) => Validators.required(v, field: 'Mã đơn'),
            suffix: IconButton(
              key: const Key('claim_scan'),
              tooltip: 'Quét mã đơn',
              icon: Icon(LucideIcons.scanLine, color: c.ink2),
              onPressed: () => setState(() => _scanTapped = true),
            ),
          ),
          const SizedBox(height: SoSpace.s16),
          SoButton(
            key: const Key('claim_submit'),
            label: 'Claim điểm',
            expand: true,
            loading: _busy,
            onPressed: _locked ? null : _submit,
          ),
          if (_locked && lockedUntil != null) ...[
            const SizedBox(height: SoSpace.s8),
            Text(
              'Tạm khóa claim tới ${Formatters.time(lockedUntil)}.',
              key: const Key('claim_locked'),
              style: context.textTheme.bodySmall?.copyWith(color: c.danger),
            ),
          ],
        ],
      ),
    );
  }
}

/// Nhóm "Điều kiện": 3 bước có số trong thẻ trắng.
class _Conditions extends StatelessWidget {
  const _Conditions();

  static const _steps = [
    ('Đơn đã ', 'hoàn tất', ' trên sàn (bạn đã nhận hàng).'),
    ('Đã qua ', '15 ngày', ' kể từ ngày hoàn tất.'),
    ('Đơn chưa được claim ở cửa hàng này.', '', ''),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.soColors;
    return Container(
      padding: SoSpace.card,
      decoration: SoShape.card(c),
      child: Column(
        children: [
          for (final (i, (before, bold, after)) in _steps.indexed) ...[
            if (i > 0) const SizedBox(height: SoSpace.s12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: c.brandTint,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${i + 1}',
                    style: context.textTheme.labelSmall?.copyWith(
                      color: c.brand,
                    ),
                  ),
                ),
                const SizedBox(width: SoSpace.s12),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: before),
                        TextSpan(
                          text: bold,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        TextSpan(text: after),
                      ],
                    ),
                    style: context.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
