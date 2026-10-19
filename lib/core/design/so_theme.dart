import 'package:flutter/material.dart';

import 'so_colors.dart';
import 'so_text.dart';
import 'so_tokens.dart';

/// [ThemeData] của SmartOmni dựng từ token. Thay cho `AppTheme` tạm thời.
///
/// Đợt 1 chỉ có giao diện sáng. Muốn thêm bản tối: tạo `SoColors.dark`
/// rồi gọi `SoTheme.build(SoColors.dark, Brightness.dark)`.
abstract final class SoTheme {
  static ThemeData light() => build(SoColors.light, Brightness.light);

  static ThemeData build(SoColors c, Brightness brightness) {
    final text = SoText.textTheme(c);
    final so = SoText.build(c);

    final scheme = ColorScheme(
      brightness: brightness,
      primary: c.brand,
      onPrimary: c.onBrand,
      primaryContainer: c.brandTint,
      onPrimaryContainer: c.brand,
      secondary: c.ink2,
      onSecondary: c.surface,
      secondaryContainer: c.fill,
      onSecondaryContainer: c.ink,
      tertiary: c.info,
      onTertiary: c.surface,
      tertiaryContainer: c.infoTint,
      onTertiaryContainer: c.info,
      error: c.danger,
      onError: c.onDanger,
      errorContainer: c.dangerTint,
      onErrorContainer: c.danger,
      surface: c.surface,
      onSurface: c.ink,
      onSurfaceVariant: c.ink2,
      surfaceContainerLowest: c.surface,
      surfaceContainerLow: c.surface,
      surfaceContainer: c.surface,
      surfaceContainerHigh: c.surface,
      surfaceContainerHighest: c.fill,
      surfaceTint: c.surface,
      outline: c.fillStrong,
      outlineVariant: c.fill,
      shadow: c.shadowTint,
      scrim: c.scrim,
      inverseSurface: c.ink,
      onInverseSurface: c.surface,
      inversePrimary: c.brandTint,
    );

    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
      borderRadius: SoRadius.mdAll,
      borderSide: BorderSide(color: color, width: width),
    );

    // Nút: capsule squircle cao 50 (DESIGN.md mục 4).
    final buttonShape = WidgetStatePropertyAll<OutlinedBorder>(
      SoShape.squircle(SoRadius.capsuleAll),
    );
    final buttonText = WidgetStatePropertyAll(text.titleMedium);
    const buttonSize = WidgetStatePropertyAll(Size(64, SoSize.control));
    const buttonPadding = WidgetStatePropertyAll(
      EdgeInsets.symmetric(horizontal: SoSpace.s20),
    );
    // Nút phụ (Elevated/Outlined của Material): nền fill, không viền.
    final secondaryButton = ButtonStyle(
      minimumSize: buttonSize,
      padding: buttonPadding,
      shape: buttonShape,
      textStyle: buttonText,
      elevation: const WidgetStatePropertyAll(0),
      side: const WidgetStatePropertyAll(BorderSide.none),
      backgroundColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.disabled)
            ? c.fillStrong
            : s.contains(WidgetState.pressed)
            ? c.fillStrong
            : c.fill,
      ),
      foregroundColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.disabled) ? c.muted : c.ink,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.ground,
      canvasColor: c.surface,
      dividerColor: c.fillStrong,
      textTheme: text,
      primaryTextTheme: text,
      extensions: [c, so],
      iconTheme: IconThemeData(color: c.ink, size: SoSize.icon),
      // AppBar Material (màn chưa chuyển sang SoAppBar): trong suốt, không
      // viền, không đổ bóng khi cuộn.
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: c.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        toolbarHeight: SoSize.appBar,
        titleTextStyle: text.titleMedium,
        iconTheme: IconThemeData(color: c.ink, size: SoSize.icon),
      ),
      dividerTheme: DividerThemeData(
        color: c.fillStrong,
        thickness: 1,
        space: 1,
      ),
      // Card Material: squircle bo 22, không viền. Bóng thẻ chuẩn chỉ có ở
      // SoShape.card (Material không vẽ được bóng hai lớp).
      cardTheme: CardThemeData(
        color: c.surface,
        surfaceTintColor: c.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: SoShape.squircle(SoRadius.lgAll),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface,
        // Ô cao 52: chữ 22 + 15 mỗi bên.
        contentPadding: const EdgeInsets.symmetric(
          horizontal: SoSpace.s16,
          vertical: 15,
        ),
        labelStyle: text.labelLarge?.copyWith(color: c.ink2),
        floatingLabelStyle: text.labelLarge?.copyWith(color: c.brand),
        hintStyle: text.bodyMedium?.copyWith(color: c.muted),
        helperStyle: text.bodySmall?.copyWith(color: c.muted),
        errorStyle: text.bodySmall?.copyWith(color: c.danger),
        helperMaxLines: 3,
        errorMaxLines: 3,
        border: border(c.fillStrong, 1),
        enabledBorder: border(c.fillStrong, 1),
        focusedBorder: border(c.brand, 2),
        errorBorder: border(c.danger, 2),
        focusedErrorBorder: border(c.danger, 2),
        disabledBorder: border(c.fillStrong, 1),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          minimumSize: buttonSize,
          padding: buttonPadding,
          shape: buttonShape,
          textStyle: buttonText,
          elevation: const WidgetStatePropertyAll(0),
          backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.disabled)
                ? c.fillStrong
                : s.contains(WidgetState.pressed)
                ? c.brandPress
                : c.brand,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.disabled) ? c.muted : c.onBrand,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(style: secondaryButton),
      outlinedButtonTheme: OutlinedButtonThemeData(style: secondaryButton),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          minimumSize: buttonSize,
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: SoSpace.s12),
          ),
          overlayColor: WidgetStatePropertyAll(c.fill),
          shape: buttonShape,
          textStyle: buttonText,
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.disabled) ? c.muted : c.brand,
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size.square(SoSize.touch)),
          shape: buttonShape,
          foregroundColor: WidgetStatePropertyAll(c.ink),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: c.ink2,
        textColor: c.ink,
        tileColor: c.surface,
        minTileHeight: SoSize.touch,
        titleTextStyle: text.titleMedium,
        subtitleTextStyle: text.bodySmall,
        contentPadding: const EdgeInsets.symmetric(horizontal: SoSpace.s16),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: SoSize.bottomNav,
        backgroundColor: c.surface,
        surfaceTintColor: c.surface,
        elevation: 0,
        indicatorColor: c.brandTint,
        indicatorShape: SoShape.squircle(SoRadius.capsuleAll),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => text.labelSmall?.copyWith(
            color: s.contains(WidgetState.selected) ? c.brand : c.ink2,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            size: SoSize.iconNav,
            color: s.contains(WidgetState.selected) ? c.brand : c.ink2,
          ),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        // Nền + bóng do SoBottomSheet tự vẽ (bóng hướng lên trên).
        backgroundColor: c.surface,
        surfaceTintColor: c.surface,
        modalBackgroundColor: c.surface,
        modalBarrierColor: c.scrim,
        elevation: 0,
        modalElevation: 0,
        shape: SoShape.squircle(SoRadius.sheetTop),
        showDragHandle: false,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: c.surface,
        barrierColor: c.scrim,
        elevation: 0,
        shape: SoShape.squircle(SoRadius.lgAll),
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyMedium,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.ink,
        contentTextStyle: text.bodyMedium?.copyWith(color: c.surface),
        actionTextColor: c.brandTint,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: SoShape.squircle(SoRadius.capsuleAll),
      ),
      // Chip: capsule 34, chưa chọn nền fill, đang chọn nền ink.
      chipTheme: ChipThemeData(
        backgroundColor: c.fill,
        selectedColor: c.ink,
        labelStyle: text.labelLarge?.copyWith(color: c.ink2),
        secondaryLabelStyle: text.labelLarge?.copyWith(color: c.surface),
        side: BorderSide.none,
        shape: SoShape.squircle(SoRadius.capsuleAll),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStatePropertyAll(c.surface),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.brand : c.fillStrong,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.brand,
        linearTrackColor: c.fill,
        circularTrackColor: Colors.transparent,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: c.brand,
        selectionColor: c.brandTint,
        selectionHandleColor: c.brand,
      ),
    );
  }
}
