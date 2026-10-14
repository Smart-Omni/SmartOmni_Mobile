import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../l10n/l10n.dart';
import 'so_button.dart';
import 'so_text.dart';
import 'so_tokens.dart';

enum SoBannerTone { info, warning, danger }

/// Banner trong nội dung màn: icon + tiêu đề + mô tả + liên kết hành động.
class SoBanner extends StatelessWidget {
  const SoBanner({
    super.key,
    required this.tone,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  final SoBannerTone tone;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final c = context.soColors;
    final (bg, fg, icon) = switch (tone) {
      SoBannerTone.info => (c.brandTint, c.brand, LucideIcons.info),
      SoBannerTone.warning => (
        c.warningTint,
        c.warning,
        LucideIcons.triangleAlert,
      ),
      SoBannerTone.danger => (c.dangerTint, c.danger, LucideIcons.circleAlert),
    };
    return Container(
      padding: const EdgeInsets.all(SoSpace.s12),
      decoration: BoxDecoration(color: bg, borderRadius: SoRadius.smAll),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: SoSize.iconSmall, color: fg),
          const SizedBox(width: SoSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.soText.bodyStrong),
                if (message != null) ...[
                  const SizedBox(height: 2),
                  Text(message!, style: context.textTheme.bodyMedium),
                ],
                if (actionLabel != null) ...[
                  const SizedBox(height: SoSpace.s4),
                  InkWell(
                    onTap: onAction,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 32),
                      child: Align(
                        widthFactor: 1,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          actionLabel!,
                          style: context.textTheme.labelLarge?.copyWith(
                            color: c.ink,
                            decoration: TextDecoration.underline,
                            decorationColor: c.ink,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Toast: nền ink, chữ trắng, nút hành động brandTint.
///
/// Thường không dựng trực tiếp mà gọi [showSoToast].
class SoToast extends StatelessWidget {
  const SoToast({
    super.key,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final c = context.soColors;
    return Container(
      constraints: const BoxConstraints(minHeight: SoSize.control),
      padding: const EdgeInsets.only(left: SoSpace.s16, right: SoSpace.s4),
      decoration: BoxDecoration(
        color: c.ink,
        borderRadius: SoRadius.smAll,
        boxShadow: [
          BoxShadow(
            color: c.shadowToast,
            offset: const Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: SoSpace.s12),
              child: Text(
                message,
                style: context.textTheme.bodyMedium?.copyWith(color: c.surface),
              ),
            ),
          ),
          if (actionLabel != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(foregroundColor: c.brandTint),
              child: Text(actionLabel!),
            )
          else
            const SizedBox(width: SoSpace.s12),
        ],
      ),
    );
  }
}

/// Hiện [SoToast] ở đáy màn qua `ScaffoldMessenger`.
void showSoToast(
  BuildContext context,
  String message, {
  String? actionLabel,
  VoidCallback? onAction,
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        padding: EdgeInsets.zero,
        behavior: SnackBarBehavior.floating,
        content: SoToast(
          message: message,
          actionLabel: actionLabel,
          onAction: onAction == null
              ? null
              : () {
                  messenger.hideCurrentSnackBar();
                  onAction();
                },
        ),
      ),
    );
}

/// Trạng thái rỗng / lỗi: ô icon 56 + tiêu đề + mô tả + nút.
class SoEmptyState extends StatelessWidget {
  const SoEmptyState({
    super.key,
    required this.title,
    this.message,
    this.icon = LucideIcons.inbox,
    this.actionLabel,
    this.onAction,
  }) : isError = false;

  /// Biến thể lỗi: ô icon nền danger-tint, nút mặc định "Thử lại".
  const SoEmptyState.error({
    super.key,
    required this.title,
    this.message,
    this.icon = LucideIcons.circleAlert,
    this.actionLabel,
    this.onAction,
  }) : isError = true;

  final String title;
  final String? message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final c = context.soColors;
    final action = actionLabel ?? (isError ? context.l10n.retry : null);
    return Padding(
      padding: const EdgeInsets.all(SoSpace.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: isError ? c.dangerTint : c.surfaceSunken,
              borderRadius: SoRadius.smAll,
            ),
            child: Icon(icon, color: isError ? c.danger : c.ink2),
          ),
          const SizedBox(height: SoSpace.s16),
          Text(title, style: context.textTheme.titleMedium),
          if (message != null) ...[
            const SizedBox(height: SoSpace.s4),
            Text(
              message!,
              style: context.textTheme.bodyMedium?.copyWith(color: c.ink2),
            ),
          ],
          if (action != null && onAction != null) ...[
            const SizedBox(height: SoSpace.s16),
            SoButton.secondary(label: action, onPressed: onAction),
          ],
        ],
      ),
    );
  }
}

/// Khối chờ tải cùng hình nội dung. Không dùng vòng xoay giữa màn.
class SoSkeleton extends StatelessWidget {
  const SoSkeleton({
    super.key,
    this.width,
    required this.height,
    this.radius = SoRadius.xs,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: context.soColors.surfaceSunken,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Danh sách skeleton có hình giống [SoOrderRow] / hàng danh sách.
class SoSkeletonList extends StatelessWidget {
  const SoSkeletonList({super.key, this.count = 4});

  final int count;

  @override
  Widget build(BuildContext context) {
    final c = context.soColors;
    return Column(
      children: [
        for (var i = 0; i < count; i++)
          Container(
            padding: SoSpace.card,
            decoration: BoxDecoration(
              color: c.surface,
              border: Border(bottom: BorderSide(color: c.line)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SoSkeleton(width: 120, height: 18),
                    Spacer(),
                    SoSkeleton(width: 72, height: 18),
                  ],
                ),
                SizedBox(height: SoSpace.s8),
                SoSkeleton(height: 16),
                SizedBox(height: SoSpace.s8),
                SoSkeleton(width: 140, height: 12),
              ],
            ),
          ),
      ],
    );
  }
}

/// Dải "DỮ LIỆU MẪU" dưới AppBar cho chức năng backend chưa có API.
class SoMockBanner extends StatelessWidget {
  const SoMockBanner({super.key, this.message});

  /// Mặc định: `l10n.mockDataNote`.
  final String? message;

  @override
  Widget build(BuildContext context) {
    final c = context.soColors;
    final l10n = context.l10n;
    return Container(
      width: double.infinity,
      color: c.brandTint,
      padding: const EdgeInsets.symmetric(
        horizontal: SoSpace.screen,
        vertical: SoSpace.s8,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Text(
              l10n.mockDataLabel,
              style: context.soText.overline.copyWith(color: c.brand),
            ),
          ),
          const SizedBox(width: SoSpace.s8),
          Expanded(
            child: Text(
              message ?? l10n.mockDataNote,
              style: context.textTheme.bodySmall?.copyWith(color: c.ink),
            ),
          ),
        ],
      ),
    );
  }
}
