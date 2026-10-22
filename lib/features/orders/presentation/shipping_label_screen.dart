import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/design/design.dart';
import '../../../core/utils/pdf_tools.dart';
import '../domain/order.dart';
import '../domain/shipping_label_repository.dart';
import 'orders_providers.dart';

enum _Action { share, print }

/// M-22 In vận đơn: xem trước tem PDF do sàn tạo, Chia sẻ PDF / In bằng hộp
/// thoại của hệ điều hành. Không chọn khổ giấy (tem của sàn có khổ cố định).
///
/// Chỉ mở từ M-21 khi đơn đã "Chuẩn bị hàng" (`labelAvailability`).
class ShippingLabelScreen extends ConsumerStatefulWidget {
  const ShippingLabelScreen({super.key, required this.order});

  final Order order;

  @override
  ConsumerState<ShippingLabelScreen> createState() =>
      _ShippingLabelScreenState();
}

class _ShippingLabelScreenState extends ConsumerState<ShippingLabelScreen> {
  _Action? _busy;

  /// Đang phóng to tem: khóa cuộn trang để kéo được tem theo mọi hướng.
  bool _zoomed = false;

  Future<void> _run(_Action action, Uint8List pdf) async {
    setState(() => _busy = action);
    final tools = ref.read(pdfToolsProvider);
    final code = widget.order.platformOrderId;
    try {
      switch (action) {
        case _Action.share:
          await tools.share(pdf, 'van-don-$code.pdf');
        case _Action.print:
          await tools.printPdf(pdf, 'Vận đơn $code');
      }
    } catch (_) {
      if (mounted) {
        showSoToast(
          context,
          action == _Action.share
              ? 'Không mở được bảng chia sẻ. Thử lại.'
              : 'Không mở được hộp thoại in. Thử lại.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final provider = shippingLabelProvider(order.id);
    final label = ref.watch(provider);
    final pdf = label.value?.pdf;

    VoidCallback? onTap(_Action action) =>
        pdf == null || _busy != null ? null : () => _run(action, pdf);

    return SoScaffold(
      scrollable: !_zoomed,
      appBar: SoAppBar(title: 'In vận đơn', subtitle: order.platformOrderId),
      bottomBar: SoActionBar(
        secondary: SoButton.secondary(
          key: const Key('label_share'),
          label: 'Chia sẻ PDF',
          loading: _busy == _Action.share,
          onPressed: onTap(_Action.share),
        ),
        primary: SoButton(
          key: const Key('label_print'),
          label: 'In',
          icon: LucideIcons.printer,
          loading: _busy == _Action.print,
          onPressed: onTap(_Action.print),
        ),
      ),
      slivers: [
        SliverPadding(
          padding: SoSpace.page,
          sliver: SliverList.list(
            children: [
              const SoMockBanner(
                message: 'Tem mẫu, chưa phải tem thật của sàn.',
              ),
              const SizedBox(height: SoSpace.s16),
              switch (label) {
                AsyncData(:final value) => _Preview(
                  pages: value.pages,
                  orderCode: order.platformOrderId,
                  onZoomChanged: (z) {
                    if (z != _zoomed) setState(() => _zoomed = z);
                  },
                ),
                AsyncError(error: LabelNotReadyException()) => SoEmptyState(
                  key: const Key('label_not_ready'),
                  icon: LucideIcons.fileClock,
                  title: 'Sàn chưa tạo tem cho đơn này',
                  message: 'Thường mất vài phút sau khi chuẩn bị hàng.',
                  actionLabel: 'Thử lại',
                  onAction: () => ref.invalidate(provider),
                ),
                AsyncError() => SoEmptyState.error(
                  key: const Key('label_error'),
                  title: 'Không tải được tem vận đơn',
                  message: 'Kiểm tra kết nối mạng rồi thử lại.',
                  onAction: () => ref.invalidate(provider),
                ),
                _ => const _Frame(
                  child: AspectRatio(
                    aspectRatio: 2 / 3,
                    child: SoSkeleton(height: double.infinity),
                  ),
                ),
              },
            ],
          ),
        ),
      ],
    );
  }
}

/// Thẻ trắng chứa các trang tem; mỗi trang có viền mảnh để thấy mép tem.
class _Frame extends StatelessWidget {
  const _Frame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('label_preview'),
    padding: SoSpace.card,
    decoration: SoShape.card(context.soColors),
    child: child,
  );
}

class _Preview extends StatefulWidget {
  const _Preview({
    required this.pages,
    required this.orderCode,
    required this.onZoomChanged,
  });

  final List<PdfPageImage> pages;
  final String orderCode;
  final ValueChanged<bool> onZoomChanged;

  @override
  State<_Preview> createState() => _PreviewState();
}

class _PreviewState extends State<_Preview> {
  late final _controllers = [
    for (final _ in widget.pages) TransformationController(),
  ];

  @override
  void initState() {
    super.initState();
    for (final c in _controllers) {
      c.addListener(_reportZoom);
    }
  }

  void _reportZoom() => widget.onZoomChanged(
    _controllers.any((c) => c.value.getMaxScaleOnAxis() > 1.01),
  );

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.soColors;
    final pages = widget.pages;
    return _Frame(
      child: Column(
        children: [
          for (final (i, page) in pages.indexed) ...[
            if (i > 0) const SizedBox(height: SoSpace.s12),
            AspectRatio(
              aspectRatio: page.width / page.height,
              child: DecoratedBox(
                position: DecorationPosition.foreground,
                decoration: ShapeDecoration(
                  shape: SoShape.squircle(
                    SoRadius.smAll,
                  ).copyWith(side: BorderSide(color: c.fillStrong)),
                ),
                child: ClipRSuperellipse(
                  borderRadius: SoRadius.smAll,
                  child: InteractiveViewer(
                    transformationController: _controllers[i],
                    maxScale: 4,
                    child: Image.memory(
                      page.png,
                      fit: BoxFit.contain,
                      gaplessPlayback: true,
                      semanticLabel: pages.length == 1
                          ? 'Xem trước tem vận đơn ${widget.orderCode}'
                          : 'Xem trước tem vận đơn ${widget.orderCode}, '
                                'trang ${i + 1}/${pages.length}',
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
