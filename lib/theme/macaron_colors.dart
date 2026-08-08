import 'package:flutter/material.dart';

/// 马卡龙色板与主题
class MacaronColors {
  MacaronColors._();

  static const Color cream = Color(0xFFFFF6F0);
  static const Color blush = Color(0xFFFFB4C8);
  static const Color mint = Color(0xFFB8F0D8);
  static const Color lilac = Color(0xFFD4C4F5);
  static const Color lemon = Color(0xFFFFE6A7);
  static const Color sky = Color(0xFFB8E0FF);
  static const Color cocoa = Color(0xFF6B4F4F);
  static const Color rose = Color(0xFFFF8FB5);
  static const Color softWhite = Color(0xFFFFFBFE);

  static ThemeData get theme {
    final base = ColorScheme.fromSeed(
      seedColor: blush,
      brightness: Brightness.light,
      primary: rose,
      secondary: mint,
      tertiary: lilac,
      surface: cream,
    );
    return ThemeData(
      colorScheme: base,
      useMaterial3: true,
      scaffoldBackgroundColor: cream,
      appBarTheme: const AppBarTheme(
        backgroundColor: blush,
        foregroundColor: cocoa,
        elevation: 0,
        centerTitle: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: rose,
          foregroundColor: softWhite,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
        ),
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          color: cocoa,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
        titleLarge: TextStyle(color: cocoa, fontWeight: FontWeight.w700),
        bodyLarge: TextStyle(color: cocoa),
      ),
    );
  }
}

/// 世界主题色（低多边形场景用）
class WorldPalette {
  const WorldPalette({
    required this.name,
    required this.skyTop,
    required this.skyBottom,
    required this.ground,
    required this.groundDark,
    required this.accent,
    required this.parallaxFar,
    required this.parallaxMid,
  });

  final String name;
  final Color skyTop;
  final Color skyBottom;
  final Color ground;
  final Color groundDark;
  final Color accent;
  final Color parallaxFar;
  final Color parallaxMid;
}
