import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_typography.dart';
import 'dimens.dart';

/// Sestavení [ThemeData] pro světlý a tmavý režim.
///
/// App bar je v obou režimech navy [AppColors.primary] (konstantní, kvůli
/// rychlé orientaci na dílně) - proto se v appce používá vlastní hlavička
/// místo Material AppBaru a `appBarTheme` slouží jen jako fallback.
abstract final class AppTheme {
  static ThemeData light() => _build(Brightness.light, AppPalette.light);

  static ThemeData dark() => _build(Brightness.dark, AppPalette.dark);

  static ThemeData _build(Brightness brightness, AppPalette palette) {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: brightness,
        ).copyWith(
          primary: brightness == Brightness.light
              ? AppColors.primary
              : AppColors.accent,
          secondary: AppColors.accent,
          error: AppColors.danger,
          surface: palette.card,
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: palette.background,
      fontFamily: AppFonts.sans,
      splashFactory: InkSparkle.splashFactory,
      extensions: <ThemeExtension<dynamic>>[palette],
      textTheme: _textTheme(palette),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      dividerTheme: DividerThemeData(
        color: palette.hairline,
        thickness: 1,
        space: 1,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(Sizes.minTouchTarget),
          textStyle: AppTextStyles.buttonLabel,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.button),
          ),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.card,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(Radii.card * 1.4),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.primary,
        contentTextStyle: const TextStyle(
          fontFamily: AppFonts.sans,
          fontSize: 14,
          color: Colors.white,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.button),
        ),
      ),
    );
  }

  static TextTheme _textTheme(AppPalette palette) {
    final base = TextTheme(
      titleLarge: AppTextStyles.appBarTitle(isIOS: true),
      titleMedium: AppTextStyles.sectionTitle,
      bodyLarge: AppTextStyles.cardModel,
      bodyMedium: AppTextStyles.cardBody,
      bodySmall: AppTextStyles.meta,
      labelSmall: AppTextStyles.overline,
    );
    return base.apply(bodyColor: palette.text, displayColor: palette.text);
  }
}

/// Zkratky pro čtení palety a platformy z [BuildContext].
extension AppThemeContext on BuildContext {
  AppPalette get palette => Theme.of(this).extension<AppPalette>()!;

  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;
}
