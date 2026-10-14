import 'package:flutter/material.dart';

/// Token màu của SmartOmni (docs/DESIGN.md mục 2).
///
/// Là một [ThemeExtension] để sau này thêm bản tối chỉ bằng một bộ giá trị
/// mới. Widget lấy màu qua `SoColors.of(context)` hoặc `context.soColors`,
/// không gõ mã màu trực tiếp.
@immutable
class SoColors extends ThemeExtension<SoColors> {
  const SoColors({
    required this.ground,
    required this.surface,
    required this.surfaceSunken,
    required this.line,
    required this.lineControl,
    required this.ink,
    required this.ink2,
    required this.muted,
    required this.brand,
    required this.brandPress,
    required this.brandTint,
    required this.onBrand,
    required this.kraft,
    required this.kraftTint,
    required this.kraftInk,
    required this.success,
    required this.successTint,
    required this.warning,
    required this.warningTint,
    required this.danger,
    required this.dangerTint,
    required this.onDanger,
    required this.shopee,
    required this.tiktok,
    required this.scrim,
    required this.shadowSheet,
    required this.shadowToast,
    required this.tierStandardBg,
    required this.tierStandardInk,
    required this.tierSilverBg,
    required this.tierSilverInk,
    required this.tierPlatinumBg,
    required this.tierPlatinumInk,
    required this.tierDiamondBg,
    required this.tierDiamondInk,
  });

  /// Nền màn hình (Scaffold).
  final Color ground;

  /// Thẻ, danh sách, sheet, ô nhập.
  final Color surface;

  /// Rãnh segmented, skeleton, nút vô hiệu, khung ảnh chờ.
  final Color surfaceSunken;

  /// Đường chia, viền thẻ.
  final Color line;

  /// Viền ô nhập, nút secondary, tay kéo sheet.
  final Color lineControl;

  /// Chữ chính, nền toast, chip đang chọn.
  final Color ink;

  /// Chữ phụ, nhãn ô nhập.
  final Color ink2;

  /// Chú thích, thời gian, placeholder.
  final Color muted;

  /// Xanh dầu: nút chính, tab đang chọn, liên kết, focus.
  final Color brand;
  final Color brandPress;

  /// Nền thông tin, ô tab đang chọn, nhãn AI, dải "Dữ liệu mẫu".
  final Color brandTint;
  final Color onBrand;

  /// Khối màu hàng đang giữ (thanh tồn kho). Không dùng làm màu chữ.
  final Color kraft;
  final Color kraftTint;
  final Color kraftInk;

  final Color success;
  final Color successTint;
  final Color warning;
  final Color warningTint;
  final Color danger;
  final Color dangerTint;
  final Color onDanger;

  /// Chỉ dùng cho ô vuông 10px cạnh chữ "Shopee".
  final Color shopee;

  /// Chỉ dùng cho ô vuông 10px cạnh chữ "TikTok Shop".
  final Color tiktok;

  /// Lớp phủ sau sheet/dialog, không blur.
  final Color scrim;

  /// Bóng của bottom sheet và toast (chỉ hai chỗ này có bóng).
  final Color shadowSheet;
  final Color shadowToast;

  final Color tierStandardBg;
  final Color tierStandardInk;
  final Color tierSilverBg;
  final Color tierSilverInk;
  final Color tierPlatinumBg;
  final Color tierPlatinumInk;
  final Color tierDiamondBg;
  final Color tierDiamondInk;

  static const light = SoColors(
    ground: Color(0xFFF2F4F5),
    surface: Color(0xFFFFFFFF),
    surfaceSunken: Color(0xFFE9EDEF),
    line: Color(0xFFD5DCE0),
    lineControl: Color(0xFF7F8C93),
    ink: Color(0xFF12191C),
    ink2: Color(0xFF3F4B52),
    muted: Color(0xFF5E6B72),
    brand: Color(0xFF0E5A6B),
    brandPress: Color(0xFF0A4552),
    brandTint: Color(0xFFE1EEF1),
    onBrand: Color(0xFFFFFFFF),
    kraft: Color(0xFFA8743F),
    kraftTint: Color(0xFFF3E8DC),
    kraftInk: Color(0xFF8A5A2B),
    success: Color(0xFF1F7A3F),
    successTint: Color(0xFFE5F3E9),
    warning: Color(0xFFA65A00),
    warningTint: Color(0xFFFDF1DC),
    danger: Color(0xFFB42318),
    dangerTint: Color(0xFFFCE8E6),
    onDanger: Color(0xFFFFFFFF),
    shopee: Color(0xFFEE4D2D),
    tiktok: Color(0xFF111111),
    scrim: Color(0x6612191C),
    shadowSheet: Color(0x1F12191C),
    shadowToast: Color(0x1A12191C),
    tierStandardBg: Color(0xFFE9EDEF),
    tierStandardInk: Color(0xFF3F4B52),
    tierSilverBg: Color(0xFFC9D2D7),
    tierSilverInk: Color(0xFF12191C),
    tierPlatinumBg: Color(0xFF4A565C),
    tierPlatinumInk: Color(0xFFFFFFFF),
    tierDiamondBg: Color(0xFF12191C),
    tierDiamondInk: Color(0xFFFFFFFF),
  );

  static SoColors of(BuildContext context) =>
      Theme.of(context).extension<SoColors>() ?? light;

  List<Color> get _values => [
    ground,
    surface,
    surfaceSunken,
    line,
    lineControl,
    ink,
    ink2,
    muted,
    brand,
    brandPress,
    brandTint,
    onBrand,
    kraft,
    kraftTint,
    kraftInk,
    success,
    successTint,
    warning,
    warningTint,
    danger,
    dangerTint,
    onDanger,
    shopee,
    tiktok,
    scrim,
    shadowSheet,
    shadowToast,
    tierStandardBg,
    tierStandardInk,
    tierSilverBg,
    tierSilverInk,
    tierPlatinumBg,
    tierPlatinumInk,
    tierDiamondBg,
    tierDiamondInk,
  ];

  static SoColors _fromValues(List<Color> v) => SoColors(
    ground: v[0],
    surface: v[1],
    surfaceSunken: v[2],
    line: v[3],
    lineControl: v[4],
    ink: v[5],
    ink2: v[6],
    muted: v[7],
    brand: v[8],
    brandPress: v[9],
    brandTint: v[10],
    onBrand: v[11],
    kraft: v[12],
    kraftTint: v[13],
    kraftInk: v[14],
    success: v[15],
    successTint: v[16],
    warning: v[17],
    warningTint: v[18],
    danger: v[19],
    dangerTint: v[20],
    onDanger: v[21],
    shopee: v[22],
    tiktok: v[23],
    scrim: v[24],
    shadowSheet: v[25],
    shadowToast: v[26],
    tierStandardBg: v[27],
    tierStandardInk: v[28],
    tierSilverBg: v[29],
    tierSilverInk: v[30],
    tierPlatinumBg: v[31],
    tierPlatinumInk: v[32],
    tierDiamondBg: v[33],
    tierDiamondInk: v[34],
  );

  /// Bộ token chỉ thay qua bản sáng/tối, nên không cần đổi từng màu.
  @override
  SoColors copyWith() => this;

  @override
  SoColors lerp(SoColors? other, double t) {
    if (other == null) return this;
    final a = _values;
    final b = other._values;
    return _fromValues([
      for (var i = 0; i < a.length; i++) Color.lerp(a[i], b[i], t)!,
    ]);
  }
}
