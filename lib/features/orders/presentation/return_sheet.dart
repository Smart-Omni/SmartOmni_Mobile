import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/design.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/l10n.dart';
import '../domain/order.dart';
import '../domain/order_rules.dart';
import 'order_ui.dart';
import 'orders_providers.dart';

/// Mở sheet "Ghi nhận hoàn/trả". Trả `true` nếu đã ghi nhận thành công.
Future<bool> showReturnSheet(BuildContext context, Order order) async {
  final ok = await showSoBottomSheet<bool>(
    context: context,
    builder: (_) => ReturnSheet(order: order),
  );
  return ok ?? false;
}

/// M-21 sheet: chọn lý do + ghi chú bắt buộc -> `POST /api/returns`
/// với `reason = "<lý do>: <ghi chú>"`. Không đổi trạng thái đơn trên sàn.
class ReturnSheet extends ConsumerStatefulWidget {
  const ReturnSheet({super.key, required this.order});

  final Order order;

  @override
  ConsumerState<ReturnSheet> createState() => _ReturnSheetState();
}

class _ReturnSheetState extends ConsumerState<ReturnSheet> {
  final _formKey = GlobalKey<FormState>();
  final _noteCtrl = TextEditingController();
  ReturnReason? _reason;
  bool _reasonMissing = false;
  bool _busy = false;
  bool _submitted = false;
  String? _error;

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final noteOk = _formKey.currentState!.validate();
    setState(() {
      _submitted = true;
      _reasonMissing = _reason == null;
    });
    if (!noteOk || _reason == null) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(ordersRepositoryProvider)
          .createReturn(
            orderId: widget.order.id,
            reason: _reason!.compose(_noteCtrl.text),
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = AsyncValueView.errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    final c = context.soColors;
    return SoBottomSheet(
      title: 'Ghi nhận hoàn/trả',
      secondary: SoButton.secondary(
        label: context.l10n.cancel,
        onPressed: _busy ? null : () => Navigator.of(context).pop(false),
      ),
      primary: SoButton(
        key: const Key('return_submit'),
        label: 'Ghi nhận',
        loading: _busy,
        onPressed: _submit,
      ),
      child: Form(
        key: _formKey,
        // Sau lần bấm Ghi nhận đầu tiên: kiểm tra lại khi gõ để lỗi tự mất.
        autovalidateMode: _submitted
            ? AutovalidateMode.onUserInteraction
            : AutovalidateMode.disabled,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: SoSpace.s8,
              runSpacing: SoSpace.s8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SoChannelTag(platform: o.platform),
                SoCodeTag(o.platformOrderId),
                SoStatusTag(label: o.status.label, status: o.status.soStatus),
              ],
            ),
            const SizedBox(height: SoSpace.s16),
            Text(
              'Lý do',
              style: context.textTheme.labelLarge?.copyWith(color: c.ink2),
            ),
            const SizedBox(height: SoSpace.s8),
            Wrap(
              spacing: SoSpace.s8,
              runSpacing: SoSpace.s8,
              children: [
                for (final r in ReturnReason.values)
                  SoFilterChip(
                    key: Key('reason_${r.name}'),
                    label: r.label,
                    selected: _reason == r,
                    onSelected: () => setState(() {
                      _reason = r;
                      _reasonMissing = false;
                    }),
                  ),
              ],
            ),
            if (_reasonMissing) ...[
              const SizedBox(height: SoSpace.s4),
              Text(
                'Chọn một lý do',
                key: const Key('return_reason_error'),
                style: context.textTheme.bodySmall?.copyWith(color: c.danger),
              ),
            ],
            const SizedBox(height: SoSpace.s16),
            SoTextField(
              key: const Key('return_note'),
              label: 'Ghi chú',
              controller: _noteCtrl,
              hint: 'Vd. khách báo áo bị rách đường may',
              maxLines: 3,
              validator: (v) => v == null || v.trim().isEmpty
                  ? 'Nhập ghi chú để đối chiếu sau này'
                  : null,
            ),
            const SizedBox(height: SoSpace.s16),
            const SoBanner(
              tone: SoBannerTone.info,
              title: 'Đây là ghi nhận nội bộ',
              message:
                  'Trạng thái đơn trên sàn không đổi. Shopee / TikTok Shop '
                  'tự cập nhật khi đơn được trả.',
            ),
            if (_error != null) ...[
              const SizedBox(height: SoSpace.s12),
              SoBanner(
                tone: SoBannerTone.danger,
                title: 'Chưa ghi nhận được',
                message: _error,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
