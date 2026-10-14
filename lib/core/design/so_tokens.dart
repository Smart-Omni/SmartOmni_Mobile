import 'package:flutter/widgets.dart';

/// Khoảng cách theo lưới 4px (docs/DESIGN.md mục 4).
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

  /// Padding trong thẻ: ngang 16, dọc 12.
  static const EdgeInsets card = EdgeInsets.symmetric(
    horizontal: s16,
    vertical: s12,
  );

  /// Khoảng cách giữa các nhóm nội dung.
  static const double group = s24;

  /// Khoảng cách giữa các thẻ trong cùng nhóm.
  static const double cardGap = s12;
}

/// Bo góc. Chỉ switch được bo tròn hẳn.
abstract final class SoRadius {
  /// Nhãn, CodeTag.
  static const double xs = 4;

  /// Nút, ô nhập, chip.
  static const double sm = 8;

  /// Thẻ, nhóm danh sách.
  static const double md = 12;

  /// Hai góc trên của sheet.
  static const double lg = 16;

  static const BorderRadius xsAll = BorderRadius.all(Radius.circular(xs));
  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius sheetTop = BorderRadius.vertical(
    top: Radius.circular(lg),
  );
}

/// Kích thước cố định.
abstract final class SoSize {
  /// Vùng chạm tối thiểu.
  static const double touch = 48;
  static const double appBar = 56;
  static const double bottomNav = 64;

  /// Nút, ô nhập.
  static const double control = 48;

  /// Nút nhỏ, chip.
  static const double controlSmall = 36;

  static const double icon = 24;
  static const double iconSmall = 20;
}
