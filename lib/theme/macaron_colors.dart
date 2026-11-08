import 'package:flutter/cupertino.dart'
    show CupertinoTextThemeData, CupertinoThemeData;
import 'package:flutter/material.dart';

/// 色板与主题：冷调、利落的御姐风——瓷白底、墨紫字、深酒红做强调色，金色点缀。
/// （类名沿用 Macaron，色值已换成偏冷的高级灰粉。）
class MacaronColors {
  MacaronColors._();

  static const Color cream = Color(0xFFF4F1F3);
  static const Color blush = Color(0xFFE3B9C3);
  static const Color mint = Color(0xFFB9D6D0);
  static const Color lilac = Color(0xFFC9C1DE);
  static const Color lemon = Color(0xFFE8D3A0);
  static const Color sky = Color(0xFFBFD2E6);
  static const Color cocoa = Color(0xFF2E2433);
  static const Color rose = Color(0xFFA8344F);
  static const Color softWhite = Color(0xFFFBF9FA);

  /// 内置的中文字体族，见 pubspec.yaml。
  static const String fontFamily = 'NotoSansSC';
  static const lyricFallbackFamily = 'NotoSansSCFull';
  static const List<String> fontFallback = [
    lyricFallbackFamily,
    'NotoColorEmoji',
  ];

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
      fontFamily: fontFamily,
      fontFamilyFallback: fontFallback,
      colorScheme: base,
      useMaterial3: true,
      // Cupertino 按钮默认用系统字体，也统一成内置字体。
      cupertinoOverrideTheme: const CupertinoThemeData(
        textTheme: CupertinoTextThemeData(
          textStyle: TextStyle(
            fontFamily: fontFamily,
            fontFamilyFallback: fontFallback,
            color: cocoa,
          ),
          actionTextStyle: TextStyle(
            fontFamily: fontFamily,
            fontFamilyFallback: fontFallback,
            color: rose,
          ),
        ),
      ),
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
            borderRadius: BorderRadius.circular(12),
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
    this.title,
    required this.skyTop,
    required this.skyBottom,
    required this.ground,
    required this.groundDark,
    required this.accent,
    required this.parallaxFar,
    required this.parallaxMid,
  });

  /// 渲染器按它认主题（不能改）。
  final String name;

  /// 玩家看到的世界名，缺省同 name。
  final String? title;
  String get displayName => title ?? name;
  final Color skyTop;
  final Color skyBottom;
  final Color ground;
  final Color groundDark;
  final Color accent;
  final Color parallaxFar;
  final Color parallaxMid;
}
