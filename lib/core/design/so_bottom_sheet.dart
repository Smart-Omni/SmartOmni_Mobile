import 'package:flutter/material.dart';

import 'so_text.dart';
import 'so_tokens.dart';

/// Mở [SoBottomSheet] dạng modal (lớp phủ scrim, không blur).
Future<T?> showSoBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    builder: builder,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: context.soColors.scrim,
    elevation: 0,
  );
}

/// Sheet thao tác nhanh: tay kéo, tiêu đề, nội dung, thanh nút dưới
/// (nút phụ chiếm 1 phần, nút chính 2 phần).
class SoBottomSheet extends StatelessWidget {
  const SoBottomSheet({
    super.key,
    required this.title,
    required this.child,
    this.primary,
    this.secondary,
  });

  final String title;
  final Widget child;

  /// Thường là `SoButton`.
  final Widget? primary;

  /// Thường là `SoButton.secondary` ("Hủy").
  final Widget? secondary;

  @override
  Widget build(BuildContext context) {
    final c = context.soColors;
    final insets = MediaQuery.viewInsetsOf(context).bottom;
    final hasActions = primary != null || secondary != null;

    return Padding(
      padding: EdgeInsets.only(bottom: insets),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: SoRadius.sheetTop,
          boxShadow: [
            BoxShadow(
              color: c.shadowSheet,
              offset: const Offset(0, -6),
              blurRadius: 24,
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: SoSpace.s8),
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: c.lineControl,
                    borderRadius: const BorderRadius.all(Radius.circular(2)),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  SoSpace.s16,
                  SoSpace.s12,
                  SoSpace.s16,
                  SoSpace.s12,
                ),
                child: Text(title, style: context.textTheme.titleMedium),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: SoSpace.s16),
                  child: child,
                ),
              ),
              if (hasActions)
                Padding(
                  padding: const EdgeInsets.all(SoSpace.s16),
                  child: Row(
                    children: [
                      if (secondary != null) Expanded(child: secondary!),
                      if (secondary != null && primary != null)
                        const SizedBox(width: SoSpace.s12),
                      if (primary != null) Expanded(flex: 2, child: primary!),
                    ],
                  ),
                )
              else
                const SizedBox(height: SoSpace.s16),
            ],
          ),
        ),
      ),
    );
  }
}
