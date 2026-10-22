import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/config/app_config.dart';
import '../../../core/design/design.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../account/presentation/account_widgets.dart';
import '../../inventory/domain/inventory_item.dart';
import '../../inventory/presentation/inventory_providers.dart';
import '../../inventory/presentation/stock_ui.dart';
import '../data/ai_repositories.dart';
import '../domain/demand_forecast.dart';

final aiRepositoryProvider = Provider<AiRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  return config.useMock
      ? AiMockRepository()
      : AiRemoteRepository(ref.watch(dioProvider));
});

final skuForecastProvider = FutureProvider.autoDispose
    .family<List<DemandForecast>, int>(
      (ref, skuId) => ref.watch(aiRepositoryProvider).forecastForSku(skuId),
    );

/// M-51 Dự báo nhu cầu 7 ngày tới của một SKU (DESIGN.md mục 8b).
///
/// Vào từ M-31 thì đã có [skuId]; vào từ M-50 thì chưa, màn tự mở sheet
/// "Chọn SKU". Danh sách SKU và số "có thể bán" lấy từ tồn kho (dữ liệu mẫu,
/// backend chưa có API danh sách tồn).
class SkuForecastScreen extends ConsumerStatefulWidget {
  const SkuForecastScreen({super.key, this.skuId});

  final int? skuId;

  @override
  ConsumerState<SkuForecastScreen> createState() => _SkuForecastScreenState();
}

class _SkuForecastScreenState extends ConsumerState<SkuForecastScreen> {
  late int? _skuId = widget.skuId;

  @override
  void initState() {
    super.initState();
    if (_skuId == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _pickSku();
      });
    }
  }

  Future<void> _pickSku() async {
    final picked = await showSoBottomSheet<int>(
      context: context,
      builder: (_) => _SkuPickerSheet(selected: _skuId),
    );
    if (picked != null && mounted) setState(() => _skuId = picked);
  }

  @override
  Widget build(BuildContext context) {
    final skuId = _skuId;
    final useMock = ref.watch(appConfigProvider).useMock;
    final stock = ref.watch(inventoryListProvider);
    final item = stock.value?.where((i) => i.skuId == skuId).firstOrNull;

    return SoScaffold(
      appBar: const SoAppBar(
        title: 'Dự báo nhu cầu',
        actions: [
          Padding(
            padding: EdgeInsets.only(right: SoSpace.s12),
            child: Center(child: SoAiLabel()),
          ),
        ],
      ),
      slivers: [
        SliverPadding(
          padding: SoSpace.page,
          sliver: SliverList.list(
            children: [
              SoMockBanner(
                message: useMock
                    ? 'Dự báo, danh sách SKU và số tồn đang là dữ liệu mẫu.'
                    : 'Danh sách SKU và số tồn là dữ liệu mẫu, backend chưa '
                          'có API.',
              ),
              const SizedBox(height: SoSpace.s16),
              _SkuCard(
                skuId: skuId,
                item: item,
                loading: stock.isLoading && item == null,
                onChange: _pickSku,
              ),
              if (skuId != null)
                _ForecastSection(
                  skuId: skuId,
                  // Tồn chưa tải xong hoặc SKU không có trong dữ liệu mẫu: "—".
                  available: item?.available,
                  onChangeSku: _pickSku,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Thẻ SKU đang xem: tên · phân loại, mã, mức tồn, nút "Đổi SKU".
class _SkuCard extends StatelessWidget {
  const _SkuCard({
    required this.skuId,
    required this.item,
    required this.loading,
    required this.onChange,
  });

  final int? skuId;
  final InventoryItem? item;
  final bool loading;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final c = context.soColors;
    final item = this.item;
    final secondary = context.textTheme.bodyMedium?.copyWith(color: c.ink2);

    final Widget info;
    if (skuId == null) {
      info = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Chưa chọn SKU', style: context.textTheme.titleMedium),
          const SizedBox(height: SoSpace.s4),
          Text('Chọn một SKU để xem dự báo 7 ngày tới.', style: secondary),
        ],
      );
    } else if (item != null) {
      info = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.productName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.textTheme.titleMedium,
          ),
          if (item.variantName != null)
            Text(item.variantName!, style: secondary),
          const SizedBox(height: SoSpace.s8),
          Wrap(
            spacing: SoSpace.s8,
            runSpacing: SoSpace.s4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SoCodeTag(item.skuCode),
              StockLevelTag(level: item.level),
            ],
          ),
        ],
      );
    } else if (loading) {
      info = const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SoSkeleton(width: 180, height: 20),
          SizedBox(height: SoSpace.s8),
          SoSkeleton(width: 120, height: 24),
        ],
      );
    } else {
      info = Text('Không tìm thấy thông tin SKU này.', style: secondary);
    }

    return Container(
      key: const Key('forecast_sku_card'),
      padding: SoSpace.card,
      decoration: SoShape.card(c),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: info),
          const SizedBox(width: SoSpace.s8),
          SoButton.ghost(
            key: const Key('forecast_change_sku'),
            label: skuId == null ? 'Chọn SKU' : 'Đổi SKU',
            size: SoButtonSize.small,
            onPressed: onChange,
          ),
        ],
      ),
    );
  }
}

/// Phần dưới thẻ SKU: thẻ kính số liệu + nhóm "Theo ngày", kèm các trạng
/// thái tải / rỗng / lỗi.
class _ForecastSection extends ConsumerWidget {
  const _ForecastSection({
    required this.skuId,
    required this.available,
    required this.onChangeSku,
  });

  final int skuId;
  final int? available;
  final VoidCallback onChangeSku;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (ref.watch(skuForecastProvider(skuId))) {
      AsyncData(:final value) when value.isEmpty => SoEmptyState(
        key: const Key('forecast_empty'),
        icon: LucideIcons.chartLine,
        title: 'Chưa có dự báo cho SKU này',
        message: 'Dự báo cần thêm dữ liệu bán hàng. Hãy quay lại sau.',
        actionLabel: 'Đổi SKU',
        onAction: onChangeSku,
      ),
      AsyncData(:final value) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: SoSpace.cardGap),
          _SummaryCard(days: value, available: available),
          const GroupTitle('Theo ngày'),
          _DaysCard(days: value),
          const SizedBox(height: SoSpace.s12),
          Text(
            'Dự báo chỉ để tham khảo.',
            style: context.textTheme.bodySmall?.copyWith(
              color: context.soColors.ink2,
            ),
          ),
        ],
      ),
      AsyncError(:final error) => SoEmptyState.error(
        title: 'Không tải được dự báo',
        message: error is ApiException ? error.message : null,
        onAction: () => ref.invalidate(skuForecastProvider(skuId)),
      ),
      _ => const _ForecastSkeleton(),
    };
  }
}

/// Thẻ kính duy nhất của màn: dự kiến bán, nên nhập thêm, có thể bán.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.days, required this.available});

  final List<DemandForecast> days;
  final int? available;

  @override
  Widget build(BuildContext context) {
    final c = context.soColors;
    final s = summarizeForecast(days);
    return SoGlass(
      key: const Key('forecast_summary'),
      padding: SoSpace.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _Metric(
                  key: const Key('forecast_predicted'),
                  label: 'Dự kiến bán ${days.length} ngày',
                  value: s.predicted,
                ),
              ),
              const SizedBox(width: SoSpace.s16),
              Expanded(
                child: _Metric(
                  key: const Key('forecast_reorder'),
                  label: 'Nên nhập thêm',
                  value: s.reorder,
                  note: s.reorder == 0 ? 'Chưa cần' : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: SoSpace.s12),
          Divider(height: 1, color: c.fillStrong),
          const SizedBox(height: SoSpace.s12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Có thể bán hiện tại',
                  style: context.textTheme.bodyMedium?.copyWith(color: c.ink2),
                ),
              ),
              Text(
                available == null ? '—' : '${Formatters.number(available)} cái',
                key: const Key('forecast_available'),
                style: context.soText.money,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Nhãn footnote + số metricSm + đơn vị "cái" (+ ghi chú).
class _Metric extends StatelessWidget {
  const _Metric({
    super.key,
    required this.label,
    required this.value,
    this.note,
  });

  final String label;
  final int value;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final c = context.soColors;
    final small = context.textTheme.bodySmall?.copyWith(color: c.ink2);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: small),
        const SizedBox(height: SoSpace.s4),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: Formatters.number(value),
                style: context.soText.metricSm,
              ),
              TextSpan(
                text: ' cái',
                style: context.textTheme.bodyMedium?.copyWith(color: c.ink2),
              ),
            ],
          ),
        ),
        if (note != null) Text(note!, style: small),
      ],
    );
  }
}

/// Nhóm "Theo ngày": mỗi ngày một hàng, thứ + ngày bên trái, số cái bên phải.
class _DaysCard extends StatelessWidget {
  const _DaysCard({required this.days});

  final List<DemandForecast> days;

  @override
  Widget build(BuildContext context) {
    return SoListGroup(
      children: [
        for (final d in days)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: SoSpace.s16,
              vertical: SoSpace.s12,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    Formatters.weekdayDate(d.forecastDate),
                    style: context.textTheme.bodyLarge,
                  ),
                ),
                Text(
                  '${Formatters.number(d.predictedQuantity)} cái',
                  style: context.soText.money,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Skeleton cùng hình thẻ số liệu + nhóm "Theo ngày".
class _ForecastSkeleton extends StatelessWidget {
  const _ForecastSkeleton();

  @override
  Widget build(BuildContext context) {
    final c = context.soColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: SoSpace.cardGap),
        Container(
          padding: SoSpace.card,
          decoration: SoShape.card(c),
          child: const Row(
            children: [
              Expanded(child: SoSkeleton(height: 48)),
              SizedBox(width: SoSpace.s16),
              Expanded(child: SoSkeleton(height: 48)),
            ],
          ),
        ),
        const SizedBox(height: SoSpace.group + 26 + SoSpace.s8),
        const SoListGroup(children: [SoSkeletonList(count: 3)]),
      ],
    );
  }
}

/// Sheet "Chọn SKU": danh sách SKU (thẻ trắng trên kính dày), chạm để chọn.
class _SkuPickerSheet extends ConsumerWidget {
  const _SkuPickerSheet({required this.selected});

  final int? selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SoBottomSheet(
      title: 'Chọn SKU',
      child: switch (ref.watch(inventoryListProvider)) {
        AsyncData(:final value) when value.isEmpty => const SoEmptyState(
          title: 'Chưa có SKU nào',
          message: 'Thêm sản phẩm ở tab Sản phẩm trước.',
        ),
        AsyncData(:final value) => SoListGroup(
          children: [
            for (final item in value)
              _PickerRow(item: item, selected: item.skuId == selected),
          ],
        ),
        AsyncError() => SoEmptyState.error(
          title: 'Không tải được danh sách SKU',
          onAction: () => ref.invalidate(inventoryListProvider),
        ),
        _ => const SoListGroup(children: [SoSkeletonList(count: 3)]),
      },
    );
  }
}

class _PickerRow extends StatelessWidget {
  const _PickerRow({required this.item, required this.selected});

  final InventoryItem item;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final c = context.soColors;
    final title = [item.productName, ?item.variantName].join(' · ');
    return Material(
      color: c.surface,
      child: InkWell(
        key: Key('pick_sku_${item.skuId}'),
        onTap: () => Navigator.pop(context, item.skuId),
        child: Semantics(
          selected: selected,
          child: Padding(
            padding: SoSpace.card,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
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
                          SoCodeTag(item.skuCode),
                          StockLevelTag(level: item.level),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: SoSpace.s12),
                if (selected)
                  Icon(
                    LucideIcons.check,
                    size: SoSize.iconSmall,
                    color: c.brand,
                    semanticLabel: 'Đang xem',
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        Formatters.number(item.available),
                        style: context.soText.money.copyWith(
                          color: item.level.numberColor(c),
                        ),
                      ),
                      Text('có thể bán', style: context.textTheme.bodySmall),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
