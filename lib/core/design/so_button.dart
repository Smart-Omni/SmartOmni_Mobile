import 'package:flutter/material.dart';

import 'so_text.dart';
import 'so_tokens.dart';

enum SoButtonVariant { primary, secondary, ghost, danger }

enum SoButtonSize {
  /// Cao 50: nút chính của màn, thanh hành động dưới.
  regular,

  /// Cao 36: nút trong thẻ, hàng danh sách.
  small,
}

/// Nút của SmartOmni: capsule squircle, thu nhỏ còn 0.97 khi nhấn.
/// Vô hiệu khi [onPressed] là `null` hoặc đang [loading].
class SoButton extends StatefulWidget {
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
  State<SoButton> createState() => _SoButtonState();
}

class _SoButtonState extends State<SoButton> {
  final _states = WidgetStatesController();
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _states.addListener(_onStates);
  }

  void _onStates() {
    final pressed = _states.value.contains(WidgetState.pressed);
    if (pressed != _pressed) setState(() => _pressed = pressed);
  }

  @override
  void dispose() {
    _states.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.soColors;
    final variant = widget.variant;
    final icon = widget.icon;
    final small = widget.size == SoButtonSize.small;
    final height = small ? SoSize.controlSmall : SoSize.control;

    final (Color bg, Color bgPressed, Color fg) = switch (variant) {
      SoButtonVariant.primary => (c.brand, c.brandPress, c.onBrand),
      SoButtonVariant.secondary => (c.fill, c.fillStrong, c.ink),
      SoButtonVariant.ghost => (Colors.transparent, c.fill, c.brand),
      SoButtonVariant.danger => (c.danger, c.danger, c.onDanger),
    };
    final disabledBg = variant == SoButtonVariant.ghost
        ? Colors.transparent
        : c.fillStrong;

    final style = ButtonStyle(
      minimumSize: WidgetStatePropertyAll(Size(height, height)),
      maximumSize: WidgetStatePropertyAll(Size(double.infinity, height)),
      padding: WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: small ? SoSpace.s16 : SoSpace.s20),
      ),
      tapTargetSize: MaterialTapTargetSize.padded,
      shape: WidgetStatePropertyAll(SoShape.squircle(SoRadius.capsuleAll)),
      textStyle: WidgetStatePropertyAll(
        small ? context.textTheme.labelLarge : context.textTheme.titleMedium,
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
    );

    final Widget child = widget.loading
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
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          );

    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final button = AnimatedScale(
      scale: _pressed && !reduceMotion ? SoMotion.pressScale : 1,
      duration: SoMotion.fast,
      curve: SoMotion.curve,
      child: TextButton(
        onPressed: widget.loading ? null : widget.onPressed,
        statesController: _states,
        style: style,
        child: child,
      ),
    );
    return widget.expand
        ? SizedBox(width: double.infinity, child: button)
        : button;
  }
}
