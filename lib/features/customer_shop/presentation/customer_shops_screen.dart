import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/router/routes.dart';
import '../../../core/design/design.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/input_formatters.dart';
import '../domain/customer_shop.dart';
import 'customer_shop_providers.dart';

/// Mở sheet "Thêm cửa hàng" (C-00, C-40). Tham gia xong: cửa hàng mới thành
/// cửa hàng đang xem, về C-10 kèm toast.
Future<void> showAddShopSheet(BuildContext context) async {
  final joined = await showSoBottomSheet<CustomerShop>(
    context: context,
    builder: (_) => const _AddShopSheet(),
  );
  if (joined == null || !context.mounted) return;
  // Toast đi qua ScaffoldMessenger nên vẫn hiện ở C-10 sau khi chuyển màn.
  showSoToast(context, 'Đã tham gia ${joined.name}');
  context.go(Routes.customerShop);
}

/// C-00 Cửa hàng của bạn (DESIGN.md mục 8b): danh sách cửa hàng đã tham
/// gia, chạm để đổi cửa hàng đang xem; "Thêm cửa hàng" mở sheet nhập mã.
class CustomerShopsScreen extends ConsumerWidget {
  const CustomerShopsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shopsAsync = ref.watch(myShopsProvider);
    final current = ref.watch(currentShopProvider).value;
    final shops = shopsAsync.value;

    return SoScaffold(
      appBar: const SoAppBar(title: 'Cửa hàng của bạn'),
      scrollable: shops != null || shopsAsync.hasError,
      slivers: [
        SliverPadding(
          padding: SoSpace.page,
          sliver: shops != null
              ? SliverList.list(
                  children: [
                    const SoMockBanner(
                      message:
                          'Danh sách cửa hàng là dữ liệu mẫu, backend chưa có '
                          'API.',
                    ),
                    const SizedBox(height: SoSpace.s16),
                    if (shops.isEmpty)
                      SoEmptyState(
                        icon: LucideIcons.store,
                        title: 'Bạn chưa tham gia cửa hàng nào',
                        message:
                            'Nhập mã cửa hàng để xem sản phẩm và tích điểm.',
                        actionLabel: 'Thêm cửa hàng',
                        onAction: () => showAddShopSheet(context),
                      )
                    else ...[
                      for (final (i, shop) in shops.indexed) ...[
                        if (i > 0) const SizedBox(height: SoSpace.cardGap),
                        _ShopCard(
                          shop: shop,
                          current: shop.tenantId == current?.tenantId,
                          onTap: () {
                            ref
                                .read(selectedShopIdProvider.notifier)
                                .select(shop.tenantId);
                            context.pop();
                          },
                        ),
                      ],
                      const SizedBox(height: SoSpace.s16),
                      SoButton.secondary(
                        key: const Key('shops_add'),
                        label: 'Thêm cửa hàng',
                        icon: LucideIcons.plus,
                        expand: true,
                        onPressed: () => showAddShopSheet(context),
                      ),
                    ],
                  ],
                )
              : shopsAsync.hasError
              ? SliverToBoxAdapter(
                  child: SoEmptyState.error(
                    title: 'Không tải được danh sách cửa hàng',
                    message: shopsAsync.error is ApiException
                        ? (shopsAsync.error! as ApiException).message
                        : null,
                    onAction: () => ref.invalidate(myShopsProvider),
                  ),
                )
              : const _Skeleton(),
        ),
      ],
    );
  }
}

/// Thẻ một cửa hàng: logo tròn, tên, hạng, điểm. Cửa hàng đang xem: viền
/// brand + nhãn "Đang xem".
class _ShopCard extends StatelessWidget {
  const _ShopCard({
    required this.shop,
    required this.current,
    required this.onTap,
  });

  final CustomerShop shop;
  final bool current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.soColors;
    final shape = RoundedSuperellipseBorder(
      borderRadius: SoRadius.lgAll,
      side: current ? BorderSide(color: c.brand, width: 2) : BorderSide.none,
    );
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: c.surface,
        shape: shape,
        shadows: SoShadow.card(c.shadowTint),
      ),
      child: Material(
        type: MaterialType.transparency,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: Key('shop_${shop.tenantId}'),
          onTap: onTap,
          child: Semantics(
            selected: current,
            child: Padding(
              padding: SoSpace.card,
              child: Row(
                children: [
                  SoShopLogo(name: shop.name),
                  const SizedBox(width: SoSpace.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          shop.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: context.textTheme.titleMedium,
                        ),
                        const SizedBox(height: SoSpace.s4),
                        Wrap(
                          spacing: SoSpace.s8,
                          runSpacing: SoSpace.s4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            SoTierBadge(tier: shop.tier),
                            Text(
                              '${shop.points} điểm',
                              style: context.textTheme.bodySmall?.copyWith(
                                color: c.ink2,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (current) ...[
                    const SizedBox(width: SoSpace.s8),
                    const SoStatusTag(
                      key: Key('shop_current'),
                      label: 'Đang xem',
                      status: SoStatus.brand,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Sheet "Thêm cửa hàng": nhập mã (tự tra sau khi ngừng gõ 0,5 giây), thẻ
/// kết quả, lỗi dưới ô; Hủy / Tham gia cửa hàng.
class _AddShopSheet extends ConsumerStatefulWidget {
  const _AddShopSheet();

  @override
  ConsumerState<_AddShopSheet> createState() => _AddShopSheetState();
}

class _AddShopSheetState extends ConsumerState<_AddShopSheet> {
  static const _debounce = Duration(milliseconds: 500);

  final _code = TextEditingController();
  Timer? _timer;
  ShopPreview? _preview;
  String? _error;
  bool _looking = false;
  bool _joining = false;
  bool _qrTapped = false;

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    super.dispose();
  }

  void _onChanged(String _) {
    _timer?.cancel();
    setState(() {
      _preview = null;
      _error = null;
    });
    if (_code.text.isNotEmpty) _timer = Timer(_debounce, _lookup);
  }

  Future<void> _lookup() async {
    _timer?.cancel();
    final code = normalizeShopCode(_code.text);
    if (code.isEmpty) return;
    final joined = ref.read(myShopsProvider).value ?? const [];
    if (hasJoined(joined, code)) {
      setState(() => _error = 'Bạn đã tham gia cửa hàng này.');
      return;
    }
    setState(() => _looking = true);
    try {
      final preview = await ref
          .read(customerShopRepositoryProvider)
          .previewShop(code);
      // Bỏ kết quả cũ nếu khách đã gõ mã khác trong lúc chờ.
      if (!mounted || normalizeShopCode(_code.text) != code) return;
      setState(() => _preview = preview);
    } catch (e) {
      if (!mounted || normalizeShopCode(_code.text) != code) return;
      setState(() => _error = _message(e));
    } finally {
      if (mounted) setState(() => _looking = false);
    }
  }

  Future<void> _join() async {
    final preview = _preview;
    if (preview == null || _joining) return;
    setState(() => _joining = true);
    try {
      final shop = await ref
          .read(customerShopRepositoryProvider)
          .joinShop(preview.code);
      ref.invalidate(myShopsProvider);
      ref.read(selectedShopIdProvider.notifier).select(shop.tenantId);
      if (mounted) Navigator.pop(context, shop);
    } catch (e) {
      if (mounted) setState(() => _error = _message(e));
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  String _message(Object e) =>
      e is ApiException ? e.message : 'Kiểm tra kết nối mạng rồi thử lại.';

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    return SoBottomSheet(
      title: 'Thêm cửa hàng',
      secondary: SoButton.secondary(
        key: const Key('add_shop_cancel'),
        label: 'Hủy',
        onPressed: _joining ? null : () => Navigator.pop(context),
      ),
      primary: SoButton(
        key: const Key('add_shop_join'),
        label: 'Tham gia cửa hàng',
        loading: _joining,
        onPressed: preview == null ? null : _join,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SoTextField(
            key: const Key('add_shop_code'),
            label: 'Mã cửa hàng',
            controller: _code,
            hint: 'Vd: SHOPDEMO',
            mono: true,
            inputFormatters: shopCodeFormatters,
            textInputAction: TextInputAction.search,
            onChanged: _onChanged,
            onSubmitted: (_) => _lookup(),
            errorText: _error,
            errorKey: const Key('add_shop_error'),
            // Toast trong sheet bị lớp phủ che, nên báo ngay dưới ô.
            helper: _qrTapped
                ? 'Quét mã QR sắp có, hãy nhập mã cửa hàng.'
                : null,
            suffix: IconButton(
              key: const Key('add_shop_qr'),
              tooltip: 'Quét mã QR',
              icon: Icon(LucideIcons.scanLine, color: context.soColors.ink2),
              // Dòng lỗi che mất dòng hướng dẫn, nên xóa lỗi cũ để thấy báo.
              onPressed: () => setState(() {
                _qrTapped = true;
                _error = null;
              }),
            ),
          ),
          const SizedBox(height: SoSpace.s16),
          if (_looking)
            const SoSkeleton(height: 72, radius: SoRadius.lg)
          else if (preview != null)
            _PreviewCard(preview: preview),
        ],
      ),
    );
  }
}

/// Thẻ kết quả tra mã: logo tròn, tên, mã.
class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.preview});

  final ShopPreview preview;

  @override
  Widget build(BuildContext context) {
    final c = context.soColors;
    return Container(
      key: const Key('add_shop_preview'),
      padding: SoSpace.card,
      decoration: SoShape.card(c),
      child: Row(
        children: [
          SoShopLogo(name: preview.name),
          const SizedBox(width: SoSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Đã tìm thấy',
                  style: context.textTheme.bodySmall?.copyWith(color: c.ink2),
                ),
                Text(
                  preview.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.titleMedium,
                ),
              ],
            ),
          ),
          Icon(LucideIcons.circleCheck, color: c.success),
        ],
      ),
    );
  }
}

/// Skeleton cùng hình hai thẻ cửa hàng.
class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    Widget card() => Container(
      padding: SoSpace.card,
      decoration: SoShape.card(context.soColors),
      child: const Row(
        children: [
          SoSkeleton(width: 40, height: 40, radius: 20),
          SizedBox(width: SoSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SoSkeleton(width: 160, height: 18),
                SizedBox(height: SoSpace.s8),
                SoSkeleton(width: 110, height: 20),
              ],
            ),
          ),
        ],
      ),
    );
    return SliverList.list(
      children: [
        const SoSkeleton(height: 36, radius: SoRadius.capsule),
        const SizedBox(height: SoSpace.s16),
        card(),
        const SizedBox(height: SoSpace.cardGap),
        card(),
      ],
    );
  }
}
