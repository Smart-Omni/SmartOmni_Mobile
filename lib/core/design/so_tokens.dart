import 'package:flutter/widgets.dart';

/// Khoảng cách theo lưới 4px (docs/DESIGN.md bản 2, mục 4).
abstract final class SoSpace {
  static const double s4 = 4;
  static const double s8 = 8;
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s20 = 20;
  static const double s24 = 24;
  static const double s32 = 32;
  static const double s40 = 40;

  /// Lề trái/phải của màn hình.
  static const double screen = s16;

  /// Padding trong thẻ.
  static const EdgeInsets card = EdgeInsets.all(s16);

  /// Khoảng cách giữa các nhóm nội dung.
  static const double group = 28;

  /// Khoảng cách giữa các thẻ trong cùng nhóm.
  static const double cardGap = s12;

  /// Khoảng cách giữa tiêu đề nhóm và thẻ đầu tiên.
  static const double sectionTitle = 10;
}

/// Bo góc. Thẻ, nút và sheet vẽ bằng `RoundedSuperellipseBorder` (squircle).
abstract final class SoRadius {
  /// CodeTag, ảnh nhỏ.
  static const double sm = 10;

  /// Ô nhập, ô icon.
  static const double md = 14;

  /// Thẻ, nhóm danh sách.
  static const double lg = 22;

  /// Hai góc trên của sheet.
  static const double xl = 28;

  /// Tròn hết: chip, nhãn trạng thái, nút, thanh tab nổi.
  static const double capsule = 999;

  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius capsuleAll = BorderRadius.all(
    Radius.circular(capsule),
  );
  static const BorderRadius sheetTop = BorderRadius.vertical(
    top: Radius.circular(xl),
  );
}

/// Kích thước cố định.
abstract final class SoSize {
  /// Vùng chạm tối thiểu.
  static const double touch = 48;

  /// AppBar màn con (và thanh kính khi tiêu đề lớn đã thu lại).
  static const double appBar = 52;

  /// Chiều cao thanh tab nổi.
  static const double bottomNav = 64;

  /// Nút.
  static const double control = 50;

  /// Nút nhỏ, nút back tròn.
  static const double controlSmall = 36;

  /// Ô nhập.
  static const double input = 52;

  /// Chip lọc.
  static const double chip = 34;

  static const double icon = 24;

  /// Icon trên thanh tab.
  static const double iconNav = 22;
  static const double iconSmall = 20;
}

/// Bóng, màu gốc là `SoColors.shadowTint`. Không dùng bóng nào khác.
abstract final class SoShadow {
  /// Thẻ đặc: `0 1 2 α4%` + `0 6 20 α6%`.
  static List<BoxShadow> card(Color tint) => [
    BoxShadow(
      color: tint.withValues(alpha: 0.04),
      offset: const Offset(0, 1),
      blurRadius: 2,
    ),
    BoxShadow(
      color: tint.withValues(alpha: 0.06),
      offset: const Offset(0, 6),
      blurRadius: 20,
    ),
  ];

  /// Kính: `0 8 32 α12%`.
  static List<BoxShadow> glass(Color tint) => [
    BoxShadow(
      color: tint.withValues(alpha: 0.12),
      offset: const Offset(0, 8),
      blurRadius: 32,
    ),
  ];
}

/// Chuyển động dạng lò xo, 250–350 ms.
abstract final class SoMotion {
  static const Duration fast = Duration(milliseconds: 250);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 350);
  static const Curve curve = Curves.easeOutCubic;

  /// Thẻ và nút thu nhỏ còn 0.97 khi nhấn.
  static const double pressScale = 0.97;
}
