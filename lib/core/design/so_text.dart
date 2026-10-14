import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'so_colors.dart';

/// Thang chữ của SmartOmni (docs/DESIGN.md mục 3).
///
/// Các style chuẩn của Material nằm trong [TextTheme] (xem [textTheme]).
/// Các style riêng (chữ mono, overline, số lớn…) nằm ở extension này,
/// lấy qua `SoText.of(context)` hoặc `context.soText`.
@immutable
class SoText extends ThemeExtension<SoText> {
  const SoText({
    required this.code,
    required this.numeral,
    required this.overline,
    required this.bodyStrong,
    required this.stat,
    required this.navLabel,
  });

  /// Mã SKU, mã đơn: Plex Mono 13/18, 500, +0.02em.
  final TextStyle code;

  /// Tiền, số lượng: Plex Mono 15/20, 500, số đều cột.
  final TextStyle numeral;

  /// Tiêu đề nhóm: Plex Mono 11/14, 600, +0.08em. Nhớ viết hoa chuỗi.
  final TextStyle overline;

  /// Tiêu đề hàng danh sách, nhãn nút: Plex Sans 15/22, 600.
  final TextStyle bodyStrong;

  /// Số trên ô chỉ số (SoStatTile): Archivo 28/32, 700.
  final TextStyle stat;

  /// Nhãn BottomNav: Plex Sans 11/14, 600.
  final TextStyle navLabel;

  static const _tabular = [FontFeature.tabularFigures()];
  static const _wide = [FontVariation('wdth', 112)];

  static TextStyle _archivo(double size, double lineHeight, Color color) =>
      GoogleFonts.archivo(
        fontSize: size,
        height: lineHeight / size,
        fontWeight: FontWeight.w700,
        color: color,
      ).copyWith(fontVariations: _wide);

  static TextStyle _sans(
    double size,
    double lineHeight,
    FontWeight weight,
    Color color,
  ) => GoogleFonts.ibmPlexSans(
    fontSize: size,
    height: lineHeight / size,
    fontWeight: weight,
    color: color,
  );

  static TextStyle _mono(
    double size,
    double lineHeight,
    FontWeight weight,
    Color color, {
    double letterSpacingEm = 0,
  }) => GoogleFonts.ibmPlexMono(
    fontSize: size,
    height: lineHeight / size,
    fontWeight: weight,
    color: color,
    letterSpacing: size * letterSpacingEm,
    fontFeatures: _tabular,
  );

  static SoText build(SoColors c) => SoText(
    code: _mono(13, 18, FontWeight.w500, c.ink, letterSpacingEm: 0.02),
    numeral: _mono(15, 20, FontWeight.w500, c.ink),
    overline: _mono(11, 14, FontWeight.w600, c.muted, letterSpacingEm: 0.08),
    bodyStrong: _sans(15, 22, FontWeight.w600, c.ink),
    stat: _archivo(28, 32, c.ink),
    navLabel: _sans(11, 14, FontWeight.w600, c.ink2),
  );

  /// [TextTheme] cho [ThemeData]. Style không có trong thang được giữ nguyên
  /// cỡ của Material nhưng đổi sang Plex Sans để không lẫn font hệ thống.
  static TextTheme textTheme(SoColors c) {
    final body = _sans(15, 22, FontWeight.w400, c.ink);
    final label = _sans(13, 18, FontWeight.w600, c.ink);
    return TextTheme(
      displayLarge: _archivo(32, 36, c.ink),
      displayMedium: _archivo(32, 36, c.ink),
      displaySmall: _archivo(32, 36, c.ink),
      headlineLarge: _archivo(32, 36, c.ink),
      headlineMedium: _archivo(32, 36, c.ink),
      headlineSmall: _archivo(24, 30, c.ink),
      titleLarge: _archivo(24, 30, c.ink),
      titleMedium: _archivo(18, 24, c.ink),
      titleSmall: _sans(15, 22, FontWeight.w600, c.ink),
      bodyLarge: _sans(16, 24, FontWeight.w400, c.ink),
      bodyMedium: body,
      bodySmall: _sans(12, 16, FontWeight.w400, c.muted),
      labelLarge: label,
      labelMedium: label,
      labelSmall: _sans(12, 16, FontWeight.w600, c.ink),
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
      code: TextStyle.lerp(code, other.code, t)!,
      numeral: TextStyle.lerp(numeral, other.numeral, t)!,
      overline: TextStyle.lerp(overline, other.overline, t)!,
      bodyStrong: TextStyle.lerp(bodyStrong, other.bodyStrong, t)!,
      stat: TextStyle.lerp(stat, other.stat, t)!,
      navLabel: TextStyle.lerp(navLabel, other.navLabel, t)!,
    );
  }
}

/// Lối tắt: `context.soColors.brand`, `context.soText.code`.
extension SoThemeContext on BuildContext {
  SoColors get soColors => SoColors.of(this);
  SoText get soText => SoText.of(this);
  TextTheme get textTheme => Theme.of(this).textTheme;
}
