import 'package:flutter/material.dart';

import '../models/app_settings.dart';

@immutable
class PassRootColors extends ThemeExtension<PassRootColors> {
  const PassRootColors({
    required this.canvasGradientTop,
    required this.canvasGradientBottom,
    required this.panelSurface,
    required this.panelBorder,
    required this.panelShadow,
    required this.softFill,
    required this.softFillAlt,
    required this.accentSoft,
    required this.warningSoft,
    required this.dangerSoft,
    required this.textMuted,
    required this.iconMuted,
    required this.heroGradientStart,
    required this.heroGradientEnd,
    required this.lockOverlay,
  });

  final Color canvasGradientTop;
  final Color canvasGradientBottom;
  final Color panelSurface;
  final Color panelBorder;
  final Color panelShadow;
  final Color softFill;
  final Color softFillAlt;
  final Color accentSoft;
  final Color warningSoft;
  final Color dangerSoft;
  final Color textMuted;
  final Color iconMuted;
  final Color heroGradientStart;
  final Color heroGradientEnd;
  final Color lockOverlay;

  factory PassRootColors.light(ColorScheme scheme) {
    return PassRootColors(
      canvasGradientTop: Color.lerp(
        const Color(0xFFF4F8FD),
        scheme.primary.withValues(alpha: 0.1),
        0.16,
      )!,
      canvasGradientBottom: Color.lerp(
        const Color(0xFFEFF7F7),
        scheme.primary.withValues(alpha: 0.12),
        0.22,
      )!,
      panelSurface: Colors.white,
      panelBorder: const Color(0xFFE1E9F2),
      panelShadow: const Color(0x15465C72),
      softFill: const Color(0xFFF5F9FE),
      softFillAlt: const Color(0xFFEAF3FD),
      accentSoft: Color.alphaBlend(
        scheme.primary.withValues(alpha: 0.1),
        const Color(0xFFE4F4F3),
      ),
      warningSoft: const Color(0xFFFFF7E8),
      dangerSoft: const Color(0xFFFEF2F2),
      textMuted: const Color(0xFF667D92),
      iconMuted: const Color(0xFF6F8599),
      heroGradientStart: Color.lerp(
        const Color(0xFF0F2740),
        scheme.primary,
        0.32,
      )!,
      heroGradientEnd: Color.lerp(
        const Color(0xFF164E63),
        scheme.primary.withValues(alpha: 0.94),
        0.38,
      )!,
      lockOverlay: const Color(0xFFF3F8FF),
    );
  }

  factory PassRootColors.dark(ColorScheme scheme) {
    return PassRootColors(
      canvasGradientTop: Color.lerp(
        const Color(0xFF0D1621),
        scheme.primary.withValues(alpha: 0.18),
        0.24,
      )!,
      canvasGradientBottom: Color.lerp(
        const Color(0xFF101D2C),
        scheme.primary.withValues(alpha: 0.24),
        0.3,
      )!,
      panelSurface: const Color(0xFF182433),
      panelBorder: const Color(0xFF2A3A4E),
      panelShadow: const Color(0x4D05090F),
      softFill: const Color(0xFF1D2A3B),
      softFillAlt: const Color(0xFF223347),
      accentSoft: Color.alphaBlend(
        scheme.primary.withValues(alpha: 0.22),
        const Color(0xFF1C3A43),
      ),
      warningSoft: const Color(0xFF3B321E),
      dangerSoft: const Color(0xFF3B2428),
      textMuted: const Color(0xFFA2B6C9),
      iconMuted: const Color(0xFF9FB2C5),
      heroGradientStart: Color.lerp(
        const Color(0xFF17314D),
        scheme.primary.withValues(alpha: 0.8),
        0.45,
      )!,
      heroGradientEnd: Color.lerp(
        const Color(0xFF1E5A6B),
        scheme.primary,
        0.48,
      )!,
      lockOverlay: const Color(0xFF0A131E),
    );
  }

  @override
  PassRootColors copyWith({
    Color? canvasGradientTop,
    Color? canvasGradientBottom,
    Color? panelSurface,
    Color? panelBorder,
    Color? panelShadow,
    Color? softFill,
    Color? softFillAlt,
    Color? accentSoft,
    Color? warningSoft,
    Color? dangerSoft,
    Color? textMuted,
    Color? iconMuted,
    Color? heroGradientStart,
    Color? heroGradientEnd,
    Color? lockOverlay,
  }) {
    return PassRootColors(
      canvasGradientTop: canvasGradientTop ?? this.canvasGradientTop,
      canvasGradientBottom: canvasGradientBottom ?? this.canvasGradientBottom,
      panelSurface: panelSurface ?? this.panelSurface,
      panelBorder: panelBorder ?? this.panelBorder,
      panelShadow: panelShadow ?? this.panelShadow,
      softFill: softFill ?? this.softFill,
      softFillAlt: softFillAlt ?? this.softFillAlt,
      accentSoft: accentSoft ?? this.accentSoft,
      warningSoft: warningSoft ?? this.warningSoft,
      dangerSoft: dangerSoft ?? this.dangerSoft,
      textMuted: textMuted ?? this.textMuted,
      iconMuted: iconMuted ?? this.iconMuted,
      heroGradientStart: heroGradientStart ?? this.heroGradientStart,
      heroGradientEnd: heroGradientEnd ?? this.heroGradientEnd,
      lockOverlay: lockOverlay ?? this.lockOverlay,
    );
  }

  @override
  PassRootColors lerp(ThemeExtension<PassRootColors>? other, double t) {
    if (other is! PassRootColors) return this;
    return PassRootColors(
      canvasGradientTop: Color.lerp(
        canvasGradientTop,
        other.canvasGradientTop,
        t,
      )!,
      canvasGradientBottom: Color.lerp(
        canvasGradientBottom,
        other.canvasGradientBottom,
        t,
      )!,
      panelSurface: Color.lerp(panelSurface, other.panelSurface, t)!,
      panelBorder: Color.lerp(panelBorder, other.panelBorder, t)!,
      panelShadow: Color.lerp(panelShadow, other.panelShadow, t)!,
      softFill: Color.lerp(softFill, other.softFill, t)!,
      softFillAlt: Color.lerp(softFillAlt, other.softFillAlt, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      warningSoft: Color.lerp(warningSoft, other.warningSoft, t)!,
      dangerSoft: Color.lerp(dangerSoft, other.dangerSoft, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      iconMuted: Color.lerp(iconMuted, other.iconMuted, t)!,
      heroGradientStart: Color.lerp(
        heroGradientStart,
        other.heroGradientStart,
        t,
      )!,
      heroGradientEnd: Color.lerp(heroGradientEnd, other.heroGradientEnd, t)!,
      lockOverlay: Color.lerp(lockOverlay, other.lockOverlay, t)!,
    );
  }
}

extension PassRootThemeX on BuildContext {
  PassRootColors get pr =>
      Theme.of(this).extension<PassRootColors>() ??
      (Theme.of(this).brightness == Brightness.dark
          ? PassRootColors.dark(Theme.of(this).colorScheme)
          : PassRootColors.light(Theme.of(this).colorScheme));
}

class AppTheme {
  static ThemeData light({required AppThemeAccent accent}) =>
      _build(Brightness.light, accent.seedColor);
  static ThemeData dark({required AppThemeAccent accent}) =>
      _build(Brightness.dark, accent.seedColor);

  static ThemeData _build(Brightness brightness, Color seedColor) {
    final isDark = brightness == Brightness.dark;
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: brightness,
        ).copyWith(
          primary: seedColor,
          secondary: Color.lerp(seedColor, const Color(0xFF67B5D1), 0.35),
          surface: isDark ? const Color(0xFF182433) : Colors.white,
        );
    final pr = isDark
        ? PassRootColors.dark(colorScheme)
        : PassRootColors.light(colorScheme);
    final textTheme = _buildTextTheme(
      brightness: brightness,
      colorScheme: colorScheme,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      typography: Typography.material2021(),
      textTheme: textTheme,
      scaffoldBackgroundColor: isDark
          ? const Color(0xFF101925)
          : const Color(0xFFF5F9FD),
      extensions: <ThemeExtension<dynamic>>[pr],
      appBarTheme: AppBarTheme(
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        backgroundColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: pr.panelSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      dividerColor: pr.panelBorder,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: pr.softFill,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: pr.panelBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.3),
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(
          color: pr.textMuted,
          fontWeight: FontWeight.w600,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: pr.textMuted.withValues(alpha: 0.92),
          fontWeight: FontWeight.w500,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: pr.panelSurface,
        indicatorColor: colorScheme.primary.withValues(
          alpha: isDark ? 0.3 : 0.16,
        ),
        labelTextStyle: WidgetStateProperty.all(
          textTheme.labelMedium!.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: pr.softFillAlt,
        selectedColor: colorScheme.primary.withValues(
          alpha: isDark ? 0.36 : 0.22,
        ),
        side: BorderSide(color: pr.panelBorder),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        labelStyle: textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: pr.panelSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: textTheme.titleMedium?.copyWith(
          color: colorScheme.onSurface,
        ),
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: pr.panelSurface,
        modalBackgroundColor: pr.panelSurface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: pr.panelSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.onSurface,
          side: BorderSide(color: pr.panelBorder),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: colorScheme.onSurfaceVariant,
        textColor: colorScheme.onSurface,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark
            ? const Color(0xFF203245)
            : const Color(0xFF13314F),
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static TextTheme _buildTextTheme({
    required Brightness brightness,
    required ColorScheme colorScheme,
  }) {
    final base = brightness == Brightness.dark
        ? Typography.material2021().white
        : Typography.material2021().black;

    final themed = base.copyWith(
      displayLarge: base.displayLarge?.copyWith(
        fontSize: 52,
        fontWeight: FontWeight.w700,
        height: 1.08,
        letterSpacing: -0.4,
      ),
      displayMedium: base.displayMedium?.copyWith(
        fontSize: 44,
        fontWeight: FontWeight.w700,
        height: 1.1,
        letterSpacing: -0.3,
      ),
      headlineLarge: base.headlineLarge?.copyWith(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        height: 1.15,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        height: 1.16,
      ),
      headlineSmall: base.headlineSmall?.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        height: 1.18,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontSize: 21,
        fontWeight: FontWeight.w700,
        height: 1.22,
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        height: 1.24,
      ),
      titleSmall: base.titleSmall?.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        height: 1.24,
      ),
      bodyLarge: base.bodyLarge?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        height: 1.45,
      ),
      bodyMedium: base.bodyMedium?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 1.42,
      ),
      bodySmall: base.bodySmall?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1.35,
      ),
      labelLarge: base.labelLarge?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.2,
      ),
      labelMedium: base.labelMedium?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        height: 1.2,
      ),
      labelSmall: base.labelSmall?.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        height: 1.2,
      ),
    );

    return themed.apply(
      bodyColor: colorScheme.onSurface,
      displayColor: colorScheme.onSurface,
    );
  }
}
