import 'package:flutter/material.dart';

import 'so_text.dart';
import 'so_tokens.dart';

enum SoButtonVariant { primary, secondary, ghost, danger }

enum SoButtonSize {
  /// Cao 48: nút chính của màn, thanh hành động dưới.
  regular,

  /// Cao 36: nút trong thẻ, hàng danh sách.
  small,
}

/// Nút của SmartOmni. Vô hiệu khi [onPressed] là `null` hoặc đang [loading].
class SoButton extends StatelessWidget {
  const SoButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = SoButtonVariant.primary,
    this.size = SoButtonSize.regular,
    this.icon,
    this.loading = false,
    this.expand = false,
  });

  const SoButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = SoButtonSize.regular,
    this.icon,
    this.loading = false,
    this.expand = false,
  }) : variant = SoButtonVariant.secondary;

  const SoButton.ghost({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = SoButtonSize.regular,
    this.icon,
    this.loading = false,
    this.expand = false,
  }) : variant = SoButtonVariant.ghost;

  const SoButton.danger({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = SoButtonSize.regular,
    this.icon,
    this.loading = false,
    this.expand = false,
  }) : variant = SoButtonVariant.danger;

  final String label;
  final VoidCallback? onPressed;
  final SoButtonVariant variant;
  final SoButtonSize size;
  final IconData? icon;
  final bool loading;

  /// `true`: chiếm hết chiều ngang.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final c = context.soColors;
    final small = size == SoButtonSize.small;
    final height = small ? SoSize.controlSmall : SoSize.control;

    final (Color bg, Color bgPressed, Color fg) = switch (variant) {
      SoButtonVariant.primary => (c.brand, c.brandPress, c.onBrand),
      SoButtonVariant.secondary => (c.surface, c.surfaceSunken, c.ink),
      SoButtonVariant.ghost => (Colors.transparent, c.surfaceSunken, c.brand),
      SoButtonVariant.danger => (c.danger, c.danger, c.onDanger),
    };
    final disabledBg = variant == SoButtonVariant.ghost
        ? Colors.transparent
        : c.surfaceSunken;

    final style = ButtonStyle(
      minimumSize: WidgetStatePropertyAll(Size(height, height)),
      maximumSize: WidgetStatePropertyAll(Size(double.infinity, height)),
      padding: WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: small ? SoSpace.s12 : SoSpace.s16),
      ),
      tapTargetSize: MaterialTapTargetSize.padded,
      shape: const WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: SoRadius.smAll),
      ),
      textStyle: WidgetStatePropertyAll(
        small ? context.textTheme.labelLarge : context.soText.bodyStrong,
      ),
      elevation: const WidgetStatePropertyAll(0),
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      backgroundColor: WidgetStateProperty.resolveWith((s) {
        if (s.contains(WidgetState.disabled)) return disabledBg;
        if (s.contains(WidgetState.pressed)) return bgPressed;
        return bg;
      }),
      foregroundColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.disabled) ? c.muted : fg,
      ),
      side: WidgetStateProperty.resolveWith(
        (s) => variant == SoButtonVariant.secondary
            ? BorderSide(
                color: s.contains(WidgetState.disabled)
                    ? c.line
                    : c.lineControl,
              )
            : BorderSide.none,
      ),
    );

    final Widget child = loading
        ? SizedBox.square(
            dimension: SoSize.iconSmall,
            child: CircularProgressIndicator(strokeWidth: 2, color: c.muted),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: SoSize.iconSmall),
                const SizedBox(width: SoSpace.s8),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          );

    final button = TextButton(
      onPressed: loading ? null : onPressed,
      style: style,
      child: child,
    );
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}
