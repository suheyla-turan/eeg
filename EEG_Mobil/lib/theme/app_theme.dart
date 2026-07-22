import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_spacing.dart';

abstract final class AppTheme {
  static const _fontFamily = 'Roboto';

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
      primary: AppColors.primary,
      secondary: AppColors.secondaryTone,
      tertiary: AppColors.accent,
      error: AppColors.danger,
      surface: AppColors.surface,
    ).copyWith(
      onSurface: AppColors.text,
      onSurfaceVariant: AppColors.textSecondary,
      outline: AppColors.border,
      outlineVariant: AppColors.border,
      primaryContainer: AppColors.primarySoft,
      onPrimaryContainer: AppColors.primary,
    );

    return _base(scheme: scheme, scaffoldBg: AppColors.bg, isDark: false);
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.dark,
    ).copyWith(
      surface: AppColors.darkSurface,
      onSurface: AppColors.darkText,
      onSurfaceVariant: AppColors.darkTextSecondary,
      outline: AppColors.darkBorder,
      outlineVariant: AppColors.darkBorder,
      primary: const Color(0xFF4DB6AC),
      onPrimary: const Color(0xFF003732),
      secondary: const Color(0xFF90A4AE),
      tertiary: AppColors.accent,
      error: const Color(0xFFFF8A80),
      primaryContainer: AppColors.darkPrimarySoft,
      onPrimaryContainer: const Color(0xFF4DB6AC),
    );

    return _base(scheme: scheme, scaffoldBg: AppColors.darkBg, isDark: true);
  }

  static ThemeData _base({
    required ColorScheme scheme,
    required Color scaffoldBg,
    required bool isDark,
  }) {
    final radius = BorderRadius.circular(AppSpacing.buttonRadius);
    final cardRadius = BorderRadius.circular(AppSpacing.cardRadius);

    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffoldBg,
      fontFamily: _fontFamily,
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
        foregroundColor: isDark ? AppColors.darkText : AppColors.text,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: isDark ? AppColors.darkText : AppColors.text,
        ),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        ),
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
      ),
      cardTheme: CardThemeData(
        color: isDark ? AppColors.darkSurface : AppColors.surface,
        elevation: 0,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: cardRadius,
          side: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.border,
          ),
        ),
        margin: EdgeInsets.zero,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
        textColor: isDark ? AppColors.darkText : AppColors.text,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
      dividerTheme: DividerThemeData(
        color: isDark ? AppColors.darkBorder : AppColors.border,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: cardRadius),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        showDragHandle: true,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? AppColors.darkSurfaceMuted : AppColors.surfaceMuted,
        hintStyle: TextStyle(
          color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
        ),
        labelStyle: TextStyle(
          color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
          borderSide: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.border,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
          borderSide: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.border,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52),
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: radius),
          textStyle: const TextStyle(
            fontFamily: _fontFamily,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(48, 52),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: radius),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 52),
          foregroundColor: scheme.primary,
          side: BorderSide(color: scheme.primary.withValues(alpha: 0.45)),
          shape: RoundedRectangleBorder(borderRadius: radius),
          textStyle: const TextStyle(
            fontFamily: _fontFamily,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          shape: RoundedRectangleBorder(borderRadius: radius),
          textStyle: const TextStyle(
            fontFamily: _fontFamily,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
        indicatorColor: isDark
            ? scheme.primary.withValues(alpha: 0.28)
            : AppColors.primarySoft,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: scheme.primary,
            );
          }
          return TextStyle(
            fontSize: 12,
            color: isDark ? AppColors.darkTextMuted : AppColors.tabInactive,
          );
        }),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
      textTheme: isDark
          ? const TextTheme(
              displayLarge: TextStyle(color: AppColors.darkText),
              displayMedium: TextStyle(color: AppColors.darkText),
              displaySmall: TextStyle(color: AppColors.darkText),
              headlineLarge: TextStyle(color: AppColors.darkText),
              headlineMedium: TextStyle(color: AppColors.darkText),
              headlineSmall: TextStyle(color: AppColors.darkText),
              titleLarge: TextStyle(color: AppColors.darkText),
              titleMedium: TextStyle(color: AppColors.darkText),
              titleSmall: TextStyle(color: AppColors.darkText),
              bodyLarge: TextStyle(color: AppColors.darkText),
              bodyMedium: TextStyle(color: AppColors.darkText),
              bodySmall: TextStyle(color: AppColors.darkTextSecondary),
              labelLarge: TextStyle(color: AppColors.darkText),
              labelMedium: TextStyle(color: AppColors.darkTextSecondary),
              labelSmall: TextStyle(color: AppColors.darkTextMuted),
            )
          : null,
    );
  }
}
