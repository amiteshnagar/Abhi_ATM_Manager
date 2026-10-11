import 'package:flutter/material.dart';

class AppTheme {
  // Exact Brand Palette
  static const Color primaryColor = Color(0xFFEE1C4B);      // Primary Brand Red
  static const Color secondaryColor = Color(0xFF1E1A4D);    // Primary Dark / Deep Navy
  static const Color accentColor = Color(0xFFF04A70);       // Light Brand Red
  static const Color textGray = Color(0xFF525277);          // Secondary Text Gray
  
  // Light Theme Colors
  static const Color lightBg = Color(0xFFF7F7FA);           // Light Background
  static const Color lightSurface = Color(0xFFFFFFFF);      // White
  static const Color lightCard = Color(0xFFFFFFFF);         // Card Background
  
  // Dark Theme Colors
  static const Color darkBg = Color(0xFF0F172A);            // Slate 900
  static const Color darkSurface = Color(0xFF1E293B);       // Slate 800
  static const Color darkCard = Color(0xFF1E293B);          // Slate 800

  // Light Theme Configuration
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: lightBg,
      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        secondary: secondaryColor,
        tertiary: accentColor,
        surface: lightSurface,
        onSurface: secondaryColor,
      ),
      fontFamily: 'Google Sans',
      fontFamilyFallback: const ['Inter', 'sans-serif'],
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontFamily: 'Google Sans', fontFamilyFallback: ['Inter', 'sans-serif'], fontSize: 32, fontWeight: FontWeight.w700, color: secondaryColor),
        displayMedium: TextStyle(fontFamily: 'Google Sans', fontFamilyFallback: ['Inter', 'sans-serif'], fontSize: 28, fontWeight: FontWeight.w700, color: secondaryColor),
        displaySmall: TextStyle(fontFamily: 'Google Sans', fontFamilyFallback: ['Inter', 'sans-serif'], fontSize: 24, fontWeight: FontWeight.w700, color: secondaryColor),
        headlineLarge: TextStyle(fontFamily: 'Google Sans', fontFamilyFallback: ['Inter', 'sans-serif'], fontSize: 24, fontWeight: FontWeight.w700, color: secondaryColor),
        headlineMedium: TextStyle(fontFamily: 'Google Sans', fontFamilyFallback: ['Inter', 'sans-serif'], fontSize: 20, fontWeight: FontWeight.w600, color: secondaryColor),
        headlineSmall: TextStyle(fontFamily: 'Google Sans', fontFamilyFallback: ['Inter', 'sans-serif'], fontSize: 18, fontWeight: FontWeight.w600, color: secondaryColor),
        titleLarge: TextStyle(fontFamily: 'Google Sans', fontFamilyFallback: ['Inter', 'sans-serif'], fontSize: 18, fontWeight: FontWeight.w600, color: secondaryColor),
        titleMedium: TextStyle(fontFamily: 'Google Sans', fontFamilyFallback: ['Inter', 'sans-serif'], fontSize: 16, fontWeight: FontWeight.w600, color: secondaryColor),
        titleSmall: TextStyle(fontFamily: 'Google Sans', fontFamilyFallback: ['Inter', 'sans-serif'], fontSize: 14, fontWeight: FontWeight.w500, color: secondaryColor),
        bodyLarge: TextStyle(fontFamily: 'Google Sans', fontFamilyFallback: ['Inter', 'sans-serif'], fontSize: 14, fontWeight: FontWeight.w500, color: secondaryColor),
        bodyMedium: TextStyle(fontFamily: 'Google Sans', fontFamilyFallback: ['Inter', 'sans-serif'], fontSize: 14, fontWeight: FontWeight.w400, color: textGray),
        bodySmall: TextStyle(fontFamily: 'Google Sans', fontFamilyFallback: ['Inter', 'sans-serif'], fontSize: 12, fontWeight: FontWeight.w400, color: textGray),
        labelLarge: TextStyle(fontFamily: 'Google Sans', fontFamilyFallback: ['Inter', 'sans-serif'], fontSize: 13, fontWeight: FontWeight.w500, color: secondaryColor),
        labelMedium: TextStyle(fontFamily: 'Google Sans', fontFamilyFallback: ['Inter', 'sans-serif'], fontSize: 12, fontWeight: FontWeight.w500, color: textGray),
        labelSmall: TextStyle(fontFamily: 'Google Sans', fontFamilyFallback: ['Inter', 'sans-serif'], fontSize: 10, fontWeight: FontWeight.w400, color: textGray),
      ),
      cardTheme: const CardThemeData(
        color: lightCard,
        elevation: 1,
        shadowColor: Color(0x0F000000),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          side: BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: lightBg,
        foregroundColor: secondaryColor,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: 'Google Sans',
          fontFamilyFallback: ['Inter', 'sans-serif'],
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: secondaryColor,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: lightSurface,
        selectedItemColor: primaryColor,
        unselectedItemColor: textGray,
        elevation: 8,
        type: BottomNavigationBarType.fixed,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFF1F5F9), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryColor, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: const TextStyle(fontFamily: 'Google Sans', color: textGray, fontSize: 13),
        hintStyle: const TextStyle(fontFamily: 'Google Sans', color: textGray, fontSize: 13),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, fontFamily: 'Google Sans'),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          side: const BorderSide(color: primaryColor, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, fontFamily: 'Google Sans'),
        ),
      ),
    );
  }

  // Dark Theme Configuration
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: darkBg,
      colorScheme: const ColorScheme.dark(
        primary: primaryColor,
        secondary: secondaryColor,
        tertiary: accentColor,
        surface: darkSurface,
        onSurface: Colors.white,
      ),
      fontFamily: 'Google Sans',
      fontFamilyFallback: const ['Inter', 'sans-serif'],
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontFamily: 'Google Sans', fontFamilyFallback: ['Inter', 'sans-serif'], fontSize: 32, fontWeight: FontWeight.w700, color: Colors.white),
        displayMedium: TextStyle(fontFamily: 'Google Sans', fontFamilyFallback: ['Inter', 'sans-serif'], fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white),
        displaySmall: TextStyle(fontFamily: 'Google Sans', fontFamilyFallback: ['Inter', 'sans-serif'], fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white),
        headlineLarge: TextStyle(fontFamily: 'Google Sans', fontFamilyFallback: ['Inter', 'sans-serif'], fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white),
        headlineMedium: TextStyle(fontFamily: 'Google Sans', fontFamilyFallback: ['Inter', 'sans-serif'], fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white),
        headlineSmall: TextStyle(fontFamily: 'Google Sans', fontFamilyFallback: ['Inter', 'sans-serif'], fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
        titleLarge: TextStyle(fontFamily: 'Google Sans', fontFamilyFallback: ['Inter', 'sans-serif'], fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
        titleMedium: TextStyle(fontFamily: 'Google Sans', fontFamilyFallback: ['Inter', 'sans-serif'], fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
        titleSmall: TextStyle(fontFamily: 'Google Sans', fontFamilyFallback: ['Inter', 'sans-serif'], fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white),
        bodyLarge: TextStyle(fontFamily: 'Google Sans', fontFamilyFallback: ['Inter', 'sans-serif'], fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white),
        bodyMedium: TextStyle(fontFamily: 'Google Sans', fontFamilyFallback: ['Inter', 'sans-serif'], fontSize: 14, fontWeight: FontWeight.w400, color: Color(0xFF94A3B8)),
        bodySmall: TextStyle(fontFamily: 'Google Sans', fontFamilyFallback: ['Inter', 'sans-serif'], fontSize: 12, fontWeight: FontWeight.w400, color: Color(0xFF94A3B8)),
        labelLarge: TextStyle(fontFamily: 'Google Sans', fontFamilyFallback: ['Inter', 'sans-serif'], fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white),
        labelMedium: TextStyle(fontFamily: 'Google Sans', fontFamilyFallback: ['Inter', 'sans-serif'], fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF94A3B8)),
        labelSmall: TextStyle(fontFamily: 'Google Sans', fontFamilyFallback: ['Inter', 'sans-serif'], fontSize: 10, fontWeight: FontWeight.w400, color: Color(0xFF94A3B8)),
      ),
      cardTheme: const CardThemeData(
        color: darkCard,
        elevation: 2,
        shadowColor: Color(0x1F000000),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          side: BorderSide(color: Color(0xFF334155), width: 1),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: darkBg,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: 'Google Sans',
          fontFamilyFallback: ['Inter', 'sans-serif'],
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: darkSurface,
        selectedItemColor: primaryColor,
        unselectedItemColor: Color(0xFF94A3B8),
        elevation: 8,
        type: BottomNavigationBarType.fixed,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1E293B),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF334155), width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF334155), width: 1),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryColor, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: const TextStyle(fontFamily: 'Google Sans', color: Color(0xFF94A3B8), fontSize: 13),
        hintStyle: const TextStyle(fontFamily: 'Google Sans', color: Color(0xFF94A3B8), fontSize: 13),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, fontFamily: 'Google Sans'),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          side: const BorderSide(color: primaryColor, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, fontFamily: 'Google Sans'),
        ),
      ),
    );
  }
}
