import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'so_colors.dart';

/// Thang chữ của SmartOmni (docs/DESIGN.md bản 2, mục 3).
///
/// Mọi chữ dùng Inter; JetBrains Mono chỉ cho mã đơn, SKU, mã cửa hàng.
/// Các style chuẩn nằm trong [TextTheme] (xem [textTheme]), ánh xạ:
/// largeTitle → headlineLarge, title1 → headlineMedium, title2 → titleLarge,
/// title3 → headlineSmall, headline → titleMedium, body → bodyLarge,
/// callout → bodyMedium, subhead → labelLarge, footnote → bodySmall,
/// caption → labelSmall.
///
/// Các style riêng (số lớn, tiền, mã) nằm ở extension này, lấy qua
/// `SoText.of(context)` hoặc `context.soText`.
@immutable
class SoText extends ThemeExtension<SoText> {
  const SoText({
    required this.metric,
    required this.metricSm,
    required this.money,
    required this.code,
    required this.title3,
  });

  /// Số lớn (điểm, doanh thu): Inter 34/40, 700, số đều cột.
  final TextStyle metric;

  /// Số trên ô chỉ số: Inter 22/28, 600, số đều cột.
  final TextStyle metricSm;

  /// Giá trong hàng danh sách: Inter 16/22, 600, số đều cột.
  final TextStyle money;

  /// Mã đơn, SKU: JetBrains Mono 13/18, 500.
  final TextStyle code;

  /// Tiêu đề nhóm (section): Inter 20/26, 600. Viết hoa chữ đầu, không viết
  /// hoa cả dòng. Trùng với `textTheme.headlineSmall`.
  final TextStyle title3;

  static const _tabular = [FontFeature.tabularFigures()];

  static TextStyle _inter(
    double size,
    double lineHeight,
    FontWeight weight,
    Color color, {
    double letterSpacing = 0,
    bool tabular = false,
  }) => GoogleFonts.inter(
    fontSize: size,
    height: lineHeight / size,
    fontWeight: weight,
    color: color,
    letterSpacing: letterSpacing,
    fontFeatures: tabular ? _tabular : null,
  );

  static TextStyle _mono(double size, double lineHeight, Color color) =>
      GoogleFonts.jetBrainsMono(
        fontSize: size,
        height: lineHeight / size,
        fontWeight: FontWeight.w500,
        color: color,
      );

  static TextStyle _title3(Color ink) =>
      _inter(20, 26, FontWeight.w600, ink, letterSpacing: -0.1);

  static SoText build(SoColors c) => SoText(
    metric: _inter(
      34,
      40,
      FontWeight.w700,
      c.ink,
      letterSpacing: -0.6,
      tabular: true,
    ),
    metricSm: _inter(
      22,
      28,
      FontWeight.w600,
      c.ink,
      letterSpacing: -0.2,
      tabular: true,
    ),
    money: _inter(16, 22, FontWeight.w600, c.ink, tabular: true),
    code: _mono(13, 18, c.ink),
    title3: _title3(c.ink),
  );

  /// [TextTheme] cho [ThemeData]. Style Material không có trong thang được
  /// gán style gần nhất của thang để không lẫn cỡ ngoài thang.
  static TextTheme textTheme(SoColors c) {
    final largeTitle = _inter(
      34,
      40,
      FontWeight.w700,
      c.ink,
      letterSpacing: -0.4,
    );
    final subhead = _inter(14, 20, FontWeight.w500, c.ink);
    return TextTheme(
      displayLarge: largeTitle,
      displayMedium: largeTitle,
      displaySmall: largeTitle,
      headlineLarge: largeTitle,
      headlineMedium: _inter(
        28,
        34,
        FontWeight.w700,
        c.ink,
        letterSpacing: -0.3,
      ),
      headlineSmall: _title3(c.ink),
      titleLarge: _inter(22, 28, FontWeight.w700, c.ink, letterSpacing: -0.2),
      titleMedium: _inter(17, 22, FontWeight.w600, c.ink),
      titleSmall: _inter(15, 20, FontWeight.w600, c.ink),
      bodyLarge: _inter(16, 22, FontWeight.w400, c.ink),
      bodyMedium: _inter(15, 20, FontWeight.w400, c.ink),
      bodySmall: _inter(13, 18, FontWeight.w400, c.muted),
      labelLarge: subhead,
      labelMedium: subhead,
      labelSmall: _inter(12, 16, FontWeight.w500, c.ink),
    );
  }

  static SoText of(BuildContext context) =>
      Theme.of(context).extension<SoText>() ?? build(SoColors.light);

  @override
  SoText copyWith() => this;

  @override
  SoText lerp(SoText? other, double t) {
    if (other == null) return this;
    return SoText(
      metric: TextStyle.lerp(metric, other.metric, t)!,
      metricSm: TextStyle.lerp(metricSm, other.metricSm, t)!,
      money: TextStyle.lerp(money, other.money, t)!,
      code: TextStyle.lerp(code, other.code, t)!,
      title3: TextStyle.lerp(title3, other.title3, t)!,
    );
  }
}

/// Lối tắt: `context.soColors.brand`, `context.soText.code`.
extension SoThemeContext on BuildContext {
  SoColors get soColors => SoColors.of(this);
  SoText get soText => SoText.of(this);
  TextTheme get textTheme => Theme.of(this).textTheme;
}
