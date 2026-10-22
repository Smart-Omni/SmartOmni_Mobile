import 'package:flutter/material.dart';

import '../models/platform.dart';
import '../utils/formatters.dart';
import 'so_tags.dart';
import 'so_text.dart';
import 'so_tokens.dart';

/// Hàng đơn hàng, lưới 2 cột:
/// [kênh + mã đơn | giá] · [sản phẩm | trạng thái] · [khách · giờ].
///
/// [selected]: hàng đang chọn trong danh sách chọn một (vd. sheet gắn đơn
/// M-61), nền `brandTint`.
class SoOrderRow extends StatelessWidget {
  const SoOrderRow({
    super.key,
    required this.platform,
    required this.orderCode,
    required this.amount,
    required this.productSummary,
    required this.statusLabel,
    required this.status,
    this.meta,
    this.onTap,
    this.selected = false,
  });

  final Platform platform;
  final String orderCode;
  final num amount;

  /// Tên sản phẩm (dài thì cắt "…").
  final String productSummary;
  final String statusLabel;
  final SoStatus status;

  /// Dòng phụ, vd. "Nguyễn Văn A · 09:41".
  final String? meta;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final c = context.soColors;
    return Semantics(
      selected: selected,
      child: Material(
        color: selected ? c.brandTint : c.surface,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: SoSpace.card,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: LayoutBuilder(
                        // Tên sàn lấy đủ bề rộng nó cần (tối đa 70% để không
                        // tràn khi quá chật); mã đơn co lại phần còn lại.
                        builder: (context, box) => Row(
                          children: [
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: box.maxWidth * 0.7,
                              ),
                              child: SoChannelTag(platform: platform),
                            ),
                            const SizedBox(width: SoSpace.s8),
                            Flexible(child: SoCodeTag(orderCode)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: SoSpace.s12),
                    Text(Formatters.vnd(amount), style: context.soText.money),
                  ],
                ),
                const SizedBox(height: SoSpace.s8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        productSummary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.textTheme.bodyMedium,
                      ),
                    ),
                    const SizedBox(width: SoSpace.s12),
                    SoStatusTag(label: statusLabel, status: status),
                  ],
                ),
                if (meta != null) ...[
                  const SizedBox(height: SoSpace.s4),
                  Text(
                    meta!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
