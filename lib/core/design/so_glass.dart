import 'dart:ui' show ImageFilter;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'so_text.dart';
import 'so_tokens.dart';

/// Độ dày của kính (docs/DESIGN.md bản 2, mục 4 "Vật liệu kính").
enum SoGlassLevel {
  /// AppBar khi cuộn, toast. σ 20.
  thin(20),

  /// Thanh tab nổi, thẻ nổi bật. σ 28.
  regular(28),

  /// Bottom sheet. σ 36.
  thick(36);

  const SoGlassLevel(this.sigma);
  final double sigma;
}

/// Công tắc kính của người dùng (gallery bản dev, sau này ở cài đặt).
/// Mặc định bật. Gốc app chuyển giá trị này xuống qua [SoGlassScope].
class GlassEnabledNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  void set(bool value) => state = value;
}

final glassEnabledProvider = NotifierProvider<GlassEnabledNotifier, bool>(
  GlassEnabledNotifier.new,
);

/// Đưa công tắc kính xuống cây widget để các widget `So…` không phụ thuộc
/// Riverpod (dùng được cả trong test không có `ProviderScope`).
class SoGlassScope extends InheritedWidget {
  const SoGlassScope({super.key, required this.enabled, required super.child});

  final bool enabled;

  /// Kính có được vẽ không: công tắc bật và không ở chế độ tương phản cao.
  static bool enabledOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SoGlassScope>();
    final highContrast = MediaQuery.maybeHighContrastOf(context) ?? false;
    return (scope?.enabled ?? true) && !highContrast;
  }

  @override
  bool updateShouldNotify(SoGlassScope oldWidget) =>
      enabled != oldWidget.enabled;
}

/// Tấm kính: cắt squircle + làm mờ nền + màu `glass*` + viền trong
/// `glassStroke` 1px + bóng kính.
///
/// Chỉ dùng cho khung (thanh tab, AppBar khi cuộn, sheet, toast) và tối đa
/// một thẻ nổi bật mỗi màn. Không đặt kính lên kính, không dùng làm nền cho
/// danh sách dài, ô nhập hay đoạn văn.
///
/// Khi kính tắt ([SoGlassScope.enabledOf] = false), vẽ nền `surface` đặc,
/// giữ nguyên bóng và bo góc.
///
/// Dùng `BackdropFilter.grouped`: nếu có `BackdropGroup` phía trên (AppBar
/// và thanh tab dùng chung) thì chia sẻ một lần chụp nền.
class SoGlass extends StatelessWidget {
  const SoGlass({
    super.key,
    this.level = SoGlassLevel.regular,
    this.borderRadius = SoRadius.lgAll,
    this.padding,
    this.shadow = true,
    required this.child,
  });

  final SoGlassLevel level;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry? padding;

  /// Tắt bóng khi tấm kính dính sát mép màn (vd. AppBar).
  final bool shadow;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.soColors;
    final enabled = SoGlassScope.enabledOf(context);
    final tint = switch (level) {
      SoGlassLevel.thin => c.glassThin,
      SoGlassLevel.regular => c.glassRegular,
      SoGlassLevel.thick => c.glassThick,
    };

    Widget content = DecoratedBox(
      decoration: ShapeDecoration(
        color: enabled ? tint : c.surface,
        shape: RoundedSuperellipseBorder(
          borderRadius: borderRadius,
          side: enabled
              ? BorderSide(
                  color: c.glassStroke,
                  strokeAlign: BorderSide.strokeAlignInside,
                )
              : BorderSide.none,
        ),
      ),
      child: padding == null ? child : Padding(padding: padding!, child: child),
    );

    content = ClipRSuperellipse(
      borderRadius: borderRadius,
      child: enabled
          ? BackdropFilter.grouped(
              filter: ImageFilter.blur(
                sigmaX: level.sigma,
                sigmaY: level.sigma,
              ),
              child: content,
            )
          : content,
    );

    if (!shadow) return content;
    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: RoundedSuperellipseBorder(borderRadius: borderRadius),
        shadows: SoShadow.glass(c.shadowTint),
      ),
      child: content,
    );
  }
}
