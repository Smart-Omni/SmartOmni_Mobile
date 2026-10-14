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
      secondaryContainer: c.surfaceSunken,
      onSecondaryContainer: c.ink,
      tertiary: c.kraftInk,
      onTertiary: c.surface,
      tertiaryContainer: c.kraftTint,
      onTertiaryContainer: c.kraftInk,
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
      surfaceContainerHighest: c.surfaceSunken,
      surfaceTint: c.surface,
      outline: c.lineControl,
      outlineVariant: c.line,
      shadow: c.ink,
      scrim: c.scrim,
      inverseSurface: c.ink,
      onInverseSurface: c.surface,
      inversePrimary: c.brandTint,
    );

    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
      borderRadius: SoRadius.smAll,
      borderSide: BorderSide(color: color, width: width),
    );

    const buttonShape = WidgetStatePropertyAll<OutlinedBorder>(
      RoundedRectangleBorder(borderRadius: SoRadius.smAll),
    );
    final buttonText = WidgetStatePropertyAll(so.bodyStrong);
    const buttonSize = WidgetStatePropertyAll(Size(64, SoSize.control));
    const buttonPadding = WidgetStatePropertyAll(
      EdgeInsets.symmetric(horizontal: SoSpace.s16),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.ground,
      canvasColor: c.surface,
      dividerColor: c.line,
      textTheme: text,
      primaryTextTheme: text,
      extensions: [c, so],
      iconTheme: IconThemeData(color: c.ink, size: SoSize.icon),
      appBarTheme: AppBarTheme(
        backgroundColor: c.surface,
        foregroundColor: c.ink,
        surfaceTintColor: c.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        toolbarHeight: SoSize.appBar,
        titleTextStyle: text.titleMedium,
        shape: Border(bottom: BorderSide(color: c.line)),
        iconTheme: IconThemeData(color: c.ink, size: SoSize.icon),
      ),
      dividerTheme: DividerThemeData(color: c.line, thickness: 1, space: 1),
      cardTheme: CardThemeData(
        color: c.surface,
        surfaceTintColor: c.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: SoRadius.mdAll,
          side: BorderSide(color: c.line),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: SoSpace.s16,
          vertical: SoSpace.s12,
        ),
        labelStyle: text.labelLarge?.copyWith(color: c.ink2),
        floatingLabelStyle: text.labelLarge?.copyWith(color: c.brand),
        hintStyle: text.bodyMedium?.copyWith(color: c.muted),
        helperStyle: text.bodySmall?.copyWith(color: c.muted),
        errorStyle: text.bodySmall?.copyWith(color: c.danger),
        helperMaxLines: 3,
        errorMaxLines: 3,
        border: border(c.lineControl, 1),
        enabledBorder: border(c.lineControl, 1),
        focusedBorder: border(c.brand, 2),
        errorBorder: border(c.danger, 2),
        focusedErrorBorder: border(c.danger, 2),
        disabledBorder: border(c.line, 1),
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
                ? c.surfaceSunken
                : s.contains(WidgetState.pressed)
                ? c.brandPress
                : c.brand,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.disabled) ? c.muted : c.onBrand,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          minimumSize: buttonSize,
          padding: buttonPadding,
          shape: buttonShape,
          textStyle: buttonText,
          elevation: const WidgetStatePropertyAll(0),
          backgroundColor: WidgetStatePropertyAll(c.surface),
          foregroundColor: WidgetStatePropertyAll(c.ink),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          minimumSize: buttonSize,
          padding: buttonPadding,
          shape: buttonShape,
          textStyle: buttonText,
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.disabled) ? c.muted : c.ink,
          ),
          side: WidgetStateProperty.resolveWith(
            (s) => BorderSide(
              color: s.contains(WidgetState.disabled) ? c.line : c.lineControl,
            ),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          minimumSize: buttonSize,
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: SoSpace.s12),
          ),
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
        titleTextStyle: so.bodyStrong,
        subtitleTextStyle: text.bodySmall,
        contentPadding: const EdgeInsets.symmetric(horizontal: SoSpace.s16),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: SoSize.bottomNav,
        backgroundColor: c.surface,
        surfaceTintColor: c.surface,
        elevation: 0,
        indicatorColor: c.brandTint,
        indicatorShape: const RoundedRectangleBorder(
          borderRadius: SoRadius.smAll,
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => so.navLabel.copyWith(
            color: s.contains(WidgetState.selected) ? c.brand : c.ink2,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            size: SoSize.icon,
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
        shape: const RoundedRectangleBorder(borderRadius: SoRadius.sheetTop),
        showDragHandle: false,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: c.surface,
        barrierColor: c.scrim,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: SoRadius.mdAll),
        titleTextStyle: text.titleMedium,
        contentTextStyle: text.bodyMedium,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.ink,
        contentTextStyle: text.bodyMedium?.copyWith(color: c.surface),
        actionTextColor: c.brandTint,
        behavior: SnackBarBehavior.floating,
        elevation: 2,
        shape: const RoundedRectangleBorder(borderRadius: SoRadius.smAll),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.surface,
        selectedColor: c.ink,
        labelStyle: text.labelLarge,
        side: BorderSide(color: c.line),
        shape: const RoundedRectangleBorder(borderRadius: SoRadius.smAll),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStatePropertyAll(c.surface),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.brand : c.lineControl,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.brand,
        linearTrackColor: c.surfaceSunken,
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
