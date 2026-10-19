import 'package:flutter/material.dart';

/// Token màu của SmartOmni (docs/DESIGN.md bản 2 – Glass, mục 2).
///
/// Là một [ThemeExtension] để sau này thêm bản tối chỉ bằng một bộ giá trị
/// mới. Widget lấy màu qua `SoColors.of(context)` hoặc `context.soColors`,
/// không gõ mã màu trực tiếp.
@immutable
class SoColors extends ThemeExtension<SoColors> {
  const SoColors({
    required this.ground,
    required this.ambientTeal,
    required this.ambientSky,
    required this.ambientSand,
    required this.surface,
    required this.fill,
    required this.fillStrong,
    required this.glassThin,
    required this.glassRegular,
    required this.glassThick,
    required this.glassStroke,
    required this.ink,
    required this.ink2,
    required this.muted,
    required this.brand,
    required this.brandPress,
    required this.brandTint,
    required this.onBrand,
    required this.info,
    required this.infoTint,
    required this.success,
    required this.successTint,
    required this.warning,
    required this.warningTint,
    required this.danger,
    required this.dangerTint,
    required this.onDanger,
    required this.held,
    required this.shopee,
    required this.tiktok,
    required this.scrim,
    required this.shadowTint,
    required this.tierStandardBg,
    required this.tierStandardInk,
    required this.tierSilverBg,
    required this.tierSilverInk,
    required this.tierPlatinumBg,
    required this.tierPlatinumInk,
    required this.tierDiamondBg,
    required this.tierDiamondInk,
  });

  /// Nền màn hình (Scaffold), nằm dưới `SoAmbientBackground`.
  final Color ground;

  /// Ba mảng màu loang của nền. Chỉ dùng trong `SoAmbientBackground`.
  final Color ambientTeal;
  final Color ambientSky;
  final Color ambientSand;

  /// Thẻ đặc, nhóm danh sách, ô nhập.
  final Color surface;

  /// Nền chip chưa chọn, CodeTag, rãnh segmented, skeleton.
  final Color fill;

  /// Nút vô hiệu, tay kéo sheet, đường chia, viền ô nhập.
  final Color fillStrong;

  /// Kính mỏng: AppBar khi cuộn, toast.
  final Color glassThin;

  /// Kính thường: thanh tab nổi, thẻ nổi bật.
  final Color glassRegular;

  /// Kính dày: bottom sheet.
  final Color glassThick;

  /// Viền trong 1px của mọi tấm kính.
  final Color glassStroke;

  /// Chữ chính, chip đang chọn.
  final Color ink;

  /// Chữ phụ, nhãn ô nhập.
  final Color ink2;

  /// Chú thích, thời gian, placeholder. Chỉ trên nền đặc hoặc kính dày.
  final Color muted;

  /// Xanh dầu: nút chính, tab đang chọn, liên kết, focus.
  final Color brand;

  /// Nút chính khi nhấn; màu của logo.
  final Color brandPress;

  /// Nền thông tin, nhãn AI, dải "Dữ liệu mẫu".
  final Color brandTint;
  final Color onBrand;

  /// Đơn đang vận chuyển.
  final Color info;
  final Color infoTint;

  final Color success;
  final Color successTint;
  final Color warning;
  final Color warningTint;
  final Color danger;
  final Color dangerTint;
  final Color onDanger;

  /// Phần hàng đang giữ chỗ trên thanh tồn kho. Không dùng làm màu chữ.
  final Color held;

  /// Chỉ dùng cho chấm tròn 8px cạnh chữ "Shopee".
  final Color shopee;

  /// Chỉ dùng cho chấm tròn 8px cạnh chữ "TikTok Shop".
  final Color tiktok;

  /// Lớp phủ sau sheet, kèm làm mờ nền.
  final Color scrim;

  /// Màu gốc của mọi bóng (xem `SoShadow`).
  final Color shadowTint;

  final Color tierStandardBg;
  final Color tierStandardInk;
  final Color tierSilverBg;
  final Color tierSilverInk;
  final Color tierPlatinumBg;
  final Color tierPlatinumInk;
  final Color tierDiamondBg;
  final Color tierDiamondInk;

  static const light = SoColors(
    ground: Color(0xFFEEF3F5),
    ambientTeal: Color(0xFF8FD3DB),
    ambientSky: Color(0xFFA9C8F2),
    ambientSand: Color(0xFFF2DDBF),
    surface: Color(0xFFFFFFFF),
    fill: Color(0x0F0B2A33), // α 6%
    fillStrong: Color(0x1A0B2A33), // α 10%
    glassThin: Color(0x94FFFFFF), // α 58%
    glassRegular: Color(0xB8FFFFFF), // α 72%
    glassThick: Color(0xDBFFFFFF), // α 86%
    glassStroke: Color(0xB3FFFFFF), // α 70%
    ink: Color(0xFF0B1A1F),
    ink2: Color(0xFF44555C),
    muted: Color(0xFF5F7078),
    brand: Color(0xFF0F6E80),
    brandPress: Color(0xFF0E5A6B),
    brandTint: Color(0xFFE2F1F3),
    onBrand: Color(0xFFFFFFFF),
    info: Color(0xFF1F64C8),
    infoTint: Color(0xFFE4EEFC),
    success: Color(0xFF1E7B45),
    successTint: Color(0xFFE3F4EA),
    warning: Color(0xFF9A5B00),
    warningTint: Color(0xFFFDF0DA),
    danger: Color(0xFFC4321F),
    dangerTint: Color(0xFFFDE8E5),
    onDanger: Color(0xFFFFFFFF),
    held: Color(0xFFC48A3A),
    shopee: Color(0xFFEE4D2D),
    tiktok: Color(0xFF111111),
    scrim: Color(0x470B1A1F), // α 28%
    shadowTint: Color(0xFF0B2A33),
    tierStandardBg: Color(0xFFE7ECEE),
    tierStandardInk: Color(0xFF44555C),
    tierSilverBg: Color(0xFFD4DCE1),
    tierSilverInk: Color(0xFF0B1A1F),
    tierPlatinumBg: Color(0xFF3E4E55),
    tierPlatinumInk: Color(0xFFFFFFFF),
    tierDiamondBg: Color(0xFF0B1A1F),
    tierDiamondInk: Color(0xFFFFFFFF),
  );

  static SoColors of(BuildContext context) =>
      Theme.of(context).extension<SoColors>() ?? light;

  List<Color> get _values => [
    ground,
    ambientTeal,
    ambientSky,
    ambientSand,
    surface,
    fill,
    fillStrong,
    glassThin,
    glassRegular,
    glassThick,
    glassStroke,
    ink,
    ink2,
    muted,
    brand,
    brandPress,
    brandTint,
    onBrand,
    info,
    infoTint,
    success,
    successTint,
    warning,
    warningTint,
    danger,
    dangerTint,
    onDanger,
    held,
    shopee,
    tiktok,
    scrim,
    shadowTint,
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
    ambientTeal: v[1],
    ambientSky: v[2],
    ambientSand: v[3],
    surface: v[4],
    fill: v[5],
    fillStrong: v[6],
    glassThin: v[7],
    glassRegular: v[8],
    glassThick: v[9],
    glassStroke: v[10],
    ink: v[11],
    ink2: v[12],
    muted: v[13],
    brand: v[14],
    brandPress: v[15],
    brandTint: v[16],
    onBrand: v[17],
    info: v[18],
    infoTint: v[19],
    success: v[20],
    successTint: v[21],
    warning: v[22],
    warningTint: v[23],
    danger: v[24],
    dangerTint: v[25],
    onDanger: v[26],
    held: v[27],
    shopee: v[28],
    tiktok: v[29],
    scrim: v[30],
    shadowTint: v[31],
    tierStandardBg: v[32],
    tierStandardInk: v[33],
    tierSilverBg: v[34],
    tierSilverInk: v[35],
    tierPlatinumBg: v[36],
    tierPlatinumInk: v[37],
    tierDiamondBg: v[38],
    tierDiamondInk: v[39],
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
