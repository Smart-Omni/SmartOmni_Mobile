import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/design/design.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/l10n.dart';
import '../domain/inventory_item.dart';
import 'inventory_providers.dart';

/// Mở sheet "Đặt lại số tồn". Trả số tồn mới nếu đã lưu, `null` nếu hủy.
Future<int?> showStockSheet(BuildContext context, InventoryItem item) =>
    showSoBottomSheet<int>(
      context: context,
      builder: (_) => StockSheet(item: item),
    );

/// M-40 sheet. Backend `POST /api/inventory/{skuId}/adjust?quantity=` đặt
/// số tồn MỚI (số đếm được), không cộng/trừ, nên ô nhập là số tuyệt đối.
class StockSheet extends ConsumerStatefulWidget {
  const StockSheet({super.key, required this.item});

  final InventoryItem item;

  @override
  ConsumerState<StockSheet> createState() => _StockSheetState();
}

class _StockSheetState extends ConsumerState<StockSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _ctrl = TextEditingController(
    text: '${widget.item.quantityOnHand}',
  );
  bool _busy = false;
  bool _submitted = false;
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  int? get _value => int.tryParse(_ctrl.text.trim());

  void _step(int delta) {
    final next = ((_value ?? widget.item.quantityOnHand) + delta).clamp(
      0,
      999999,
    );
    setState(() => _ctrl.text = '$next');
  }

  Future<void> _save() async {
    setState(() => _submitted = true);
    if (!_formKey.currentState!.validate()) return;
    final qty = _value!;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(inventoryRepositoryProvider)
          .setStock(skuId: widget.item.skuId, newQuantity: qty);
      if (mounted) Navigator.of(context).pop(qty);
    } catch (e) {
      if (mounted) setState(() => _error = AsyncValueView.errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final c = context.soColors;
    final value = _value;
    final sellableAfter = value == null ? null : value - item.reservedQuantity;
    final title = [item.productName, ?item.variantName].join(' · ');
    final afterText = switch (sellableAfter) {
      null => '—',
      < 0 => '0 (ít hơn số đang giữ ${item.reservedQuantity})',
      final n => '$n',
    };
    final helper =
        'Nhập số đếm được trong kho, không phải số cộng thêm. '
        'Sau khi lưu: có thể bán $afterText';

    return SoBottomSheet(
      title: 'Đặt lại số tồn',
      secondary: SoButton.secondary(
        label: context.l10n.cancel,
        onPressed: _busy ? null : () => Navigator.of(context).pop(),
      ),
      primary: SoButton(
        key: const Key('stock_save'),
        label: 'Lưu số tồn',
        loading: _busy,
        onPressed: _save,
      ),
      child: Form(
        key: _formKey,
        // Sau lần bấm Lưu đầu tiên: kiểm tra lại khi gõ để lỗi tự mất.
        autovalidateMode: _submitted
            ? AutovalidateMode.onUserInteraction
            : AutovalidateMode.disabled,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: context.soText.bodyStrong),
            const SizedBox(height: SoSpace.s8),
            Row(children: [Flexible(child: SoCodeTag(item.skuCode))]),
            const SizedBox(height: SoSpace.s16),
            Text('HIỆN TẠI', style: context.soText.overline),
            const SizedBox(height: SoSpace.s8),
            SoStockMeter(
              onHand: item.quantityOnHand,
              reserved: item.reservedQuantity,
            ),
            const SizedBox(height: SoSpace.s16),
            SoTextField(
              key: const Key('stock_input'),
              label: 'Số tồn đếm được',
              controller: _ctrl,
              mono: true,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _save(),
              validator: (v) => Validators.nonNegativeInt(v, field: 'Số tồn'),
              helper: helper,
              prefix: IconButton(
                key: const Key('stock_minus'),
                tooltip: 'Bớt 1',
                icon: Icon(LucideIcons.minus, color: c.ink2),
                onPressed: (value ?? 0) > 0 ? () => _step(-1) : null,
              ),
              suffix: IconButton(
                key: const Key('stock_plus'),
                tooltip: 'Thêm 1',
                icon: Icon(LucideIcons.plus, color: c.ink2),
                onPressed: () => _step(1),
              ),
            ),
            const SizedBox(height: SoSpace.s16),
            const SoBanner(
              tone: SoBannerTone.info,
              title: 'Đồng bộ lên sàn',
              message:
                  'Sau khi lưu, số có thể bán được cập nhật lên Shopee và '
                  'TikTok Shop.',
            ),
            if (_error != null) ...[
              const SizedBox(height: SoSpace.s12),
              SoBanner(
                tone: SoBannerTone.danger,
                title: 'Chưa lưu được số tồn',
                message: _error,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
