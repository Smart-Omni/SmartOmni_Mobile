import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../utils/formatters.dart';
import 'so_text.dart';
import 'so_tokens.dart';

/// Thanh tồn kho: phần đang giữ (kraft) + phần có thể bán (brand).
///
/// Có thể bán = tồn − giữ chỗ (đã tính sẵn trong `InventoryItem.available`).
class SoStockMeter extends StatelessWidget {
  const SoStockMeter({
    super.key,
    required this.onHand,
    required this.reserved,
    this.showLegend = true,
  });

  /// Bản thu nhỏ cho hàng danh sách: thanh 4px, không chú giải.
  const SoStockMeter.mini({
    super.key,
    required this.onHand,
    required this.reserved,
  }) : showLegend = false;

  final int onHand;
  final int reserved;
  final bool showLegend;

  int get sellable => onHand - reserved;

  @override
  Widget build(BuildContext context) {
    final c = context.soColors;
    final heldPart = reserved.clamp(0, onHand < 0 ? 0 : onHand);
    final sellPart = sellable < 0 ? 0 : sellable;
    final barHeight = showLegend ? 10.0 : 4.0;

    final bar = ClipRRect(
      borderRadius: const BorderRadius.all(Radius.circular(2)),
      child: SizedBox(
        height: barHeight,
        child: ColoredBox(
          color: c.surfaceSunken,
          child: Row(
            children: [
              if (heldPart > 0)
                Expanded(
                  flex: heldPart,
                  child: ColoredBox(color: c.kraft),
                ),
              if (sellPart > 0)
                Expanded(
                  flex: sellPart,
                  child: ColoredBox(color: c.brand),
                ),
            ],
          ),
        ),
      ),
    );
    if (!showLegend) return bar;

    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        bar,
        const SizedBox(height: SoSpace.s12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _Legend(label: l10n.stockOnHand, value: onHand),
            ),
            Expanded(
              child: _Legend(
                label: l10n.stockReserved,
                value: reserved,
                swatch: c.kraft,
              ),
            ),
            Expanded(
              child: _Legend(
                label: l10n.stockSellable,
                value: sellable,
                swatch: c.brand,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.label, required this.value, this.swatch});

  final String label;
  final int value;
  final Color? swatch;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (swatch != null) ...[
              Container(width: 8, height: 8, color: swatch),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textTheme.bodySmall,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(Formatters.number(value), style: context.soText.numeral),
      ],
    );
  }
}
