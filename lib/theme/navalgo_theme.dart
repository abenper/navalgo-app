import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class NavalgoColors {
  static const Color ink = Color(0xFF0B1F2A);
  static const Color deepSea = Color(0xFF103645);
  static const Color tide = Color(0xFF145568);
  static const Color harbor = Color(0xFF1C7282);
  static const Color foam = Color(0xFFF2F7F8);
  static const Color mist = Color(0xFFE3ECEF);
  static const Color shell = Color(0xFFF7FBFC);
  static const Color sand = Color(0xFFE4C78E);
  static const Color coral = Color(0xFFD66D4A);
  static const Color kelp = Color(0xFF3D8F75);
  static const Color storm = Color(0xFF607784);
  static const Color border = Color(0xFFD4E1E6);
  static const Color alert = Color(0xFFB4533F);

  static const LinearGradient heroGradient = LinearGradient(
    colors: [deepSea, tide, harbor],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient pageGradient = LinearGradient(
    colors: [Color(0xFFF7FBFC), Color(0xFFEAF2F4)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient railGradient = LinearGradient(
    colors: [Color(0xFFFBFDFC), Color(0xFFF0F6F8)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}

ThemeData buildNavalgoTheme() {
  final colorScheme =
      ColorScheme.fromSeed(
        seedColor: NavalgoColors.tide,
        brightness: Brightness.light,
      ).copyWith(
        primary: NavalgoColors.tide,
        onPrimary: Colors.white,
        secondary: NavalgoColors.sand,
        onSecondary: NavalgoColors.ink,
        tertiary: NavalgoColors.kelp,
        surface: Colors.white,
        onSurface: NavalgoColors.ink,
        error: NavalgoColors.alert,
        onError: Colors.white,
        outline: NavalgoColors.border,
        shadow: NavalgoColors.deepSea.withValues(alpha: 0.12),
      );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: NavalgoColors.foam,
    canvasColor: Colors.white,
    splashFactory: InkSparkle.splashFactory,
  );

  final textTheme = GoogleFonts.manropeTextTheme(base.textTheme).copyWith(
    displayLarge: GoogleFonts.manrope(
      fontSize: 56,
      fontWeight: FontWeight.w800,
      letterSpacing: -2.4,
      color: NavalgoColors.ink,
    ),
    displayMedium: GoogleFonts.manrope(
      fontSize: 44,
      fontWeight: FontWeight.w800,
      letterSpacing: -1.8,
      color: NavalgoColors.ink,
    ),
    headlineLarge: GoogleFonts.manrope(
      fontSize: 36,
      fontWeight: FontWeight.w800,
      letterSpacing: -1.4,
      color: NavalgoColors.ink,
    ),
    headlineMedium: GoogleFonts.manrope(
      fontSize: 30,
      fontWeight: FontWeight.w800,
      letterSpacing: -1.1,
      color: NavalgoColors.ink,
    ),
    headlineSmall: GoogleFonts.manrope(
      fontSize: 24,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.8,
      color: NavalgoColors.ink,
    ),
    titleLarge: GoogleFonts.manrope(
      fontSize: 20,
      fontWeight: FontWeight.w700,
      color: NavalgoColors.ink,
    ),
    titleMedium: GoogleFonts.manrope(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      color: NavalgoColors.ink,
    ),
    bodyLarge: GoogleFonts.manrope(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      color: NavalgoColors.ink,
      height: 1.45,
    ),
    bodyMedium: GoogleFonts.manrope(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: NavalgoColors.storm,
      height: 1.45,
    ),
    labelLarge: GoogleFonts.manrope(
      fontSize: 14,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.1,
      color: NavalgoColors.ink,
    ),
  );

  return base.copyWith(
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: NavalgoColors.shell,
      foregroundColor: NavalgoColors.ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: textTheme.titleLarge,
      iconTheme: const IconThemeData(color: NavalgoColors.deepSea),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: Colors.white,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: NavalgoColors.border),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      hintStyle: textTheme.bodyMedium,
      labelStyle: textTheme.bodyMedium,
      prefixIconColor: NavalgoColors.harbor,
      suffixIconColor: NavalgoColors.harbor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: NavalgoColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: NavalgoColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: NavalgoColors.harbor, width: 1.4),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: NavalgoColors.tide,
        foregroundColor: Colors.white,
        textStyle: textTheme.labelLarge?.copyWith(color: Colors.white),
        minimumSize: const Size(0, 56),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: NavalgoColors.tide,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 56),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: NavalgoColors.deepSea,
        minimumSize: const Size(0, 56),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
        side: const BorderSide(color: NavalgoColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: NavalgoColors.tide,
      foregroundColor: Colors.white,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      titleTextStyle: textTheme.titleLarge,
      contentTextStyle: textTheme.bodyLarge,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      backgroundColor: NavalgoColors.deepSea,
      contentTextStyle: textTheme.bodyLarge?.copyWith(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    dividerTheme: const DividerThemeData(
      color: NavalgoColors.border,
      thickness: 1,
      space: 1,
    ),
    chipTheme: base.chipTheme.copyWith(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      side: BorderSide.none,
      labelStyle: textTheme.labelLarge?.copyWith(color: NavalgoColors.deepSea),
      backgroundColor: NavalgoColors.mist,
      selectedColor: NavalgoColors.sand.withValues(alpha: 0.3),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: NavalgoColors.mist,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return textTheme.labelLarge?.copyWith(
          color: selected ? NavalgoColors.tide : NavalgoColors.storm,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected ? NavalgoColors.tide : NavalgoColors.storm,
        );
      }),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: Colors.transparent,
      selectedIconTheme: const IconThemeData(color: NavalgoColors.tide),
      unselectedIconTheme: const IconThemeData(color: NavalgoColors.storm),
      selectedLabelTextStyle: textTheme.labelLarge?.copyWith(
        color: NavalgoColors.tide,
      ),
      unselectedLabelTextStyle: textTheme.bodyMedium,
      indicatorColor: NavalgoColors.mist,
      useIndicator: true,
    ),
  );
}
