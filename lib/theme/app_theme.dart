import 'dart:io' show Platform;

import 'package:flutter/material.dart';

/// 小清新主题 —— 薄荷绿 + 莫兰迪配色
class AppTheme {
  // 主色
  static const Color mint = Color(0xFF5DCAA5);
  static const Color mintDark = Color(0xFF1D9E75);
  static const Color mintLight = Color(0xFFE1F5EE);
  static const Color blue = Color(0xFF7FB8E6);
  static const Color blueLight = Color(0xFFEAF4FB);

  // 中性色
  static const Color ink = Color(0xFF2C3A36);
  static const Color ink2 = Color(0xFF6B7A75);
  static const Color ink3 = Color(0xFF9AA7A2);
  static const Color line = Color(0xFFECEFED);
  static const Color line2 = Color(0xFFDFE4E1);
  static const Color cream = Color(0xFFFFFCF5);
  static const Color paper = Color(0xFFFFFFFF);

  // 评分色
  static const Color again = Color(0xFFE24B4A);
  static const Color hard = Color(0xFFEF9F27);
  static const Color good = Color(0xFF5DCAA5);
  static const Color easy = Color(0xFF7FB8E6);
  static const Color coral = Color(0xFFF0997B);

  // 牌组配色
  static const List<Color> deckColors = [
    Color(0xFF5DCAA5),
    Color(0xFF7FB8E6),
    Color(0xFFF0997B),
    Color(0xFFAFA9EC),
    Color(0xFFED93B1),
    Color(0xFF97C459),
  ];

  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: mint,
        primary: mintDark,
        secondary: blue,
      ),
      scaffoldBackgroundColor: Color(0xFFF3FAF7),
      // 苹方只在 Apple 平台存在；Android 用系统默认（思源黑体）反而更协调
      fontFamily:
          Platform.isIOS || Platform.isMacOS ? 'PingFang SC' : null,
    );

    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: ink,
        displayColor: ink,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: paper,
        foregroundColor: ink,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: paper,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: line),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: mintDark,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
