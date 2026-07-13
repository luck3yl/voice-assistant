import 'package:flutter/material.dart';

/// 应用主题 - 深色科技风格，参考炼钢助手设计稿
class AppTheme {
  AppTheme._();

  // 主色调
  static const Color primaryColor = Color(0xFF2196F3);
  static const Color accentColor = Color(0xFF4FC3F7);
  static const Color backgroundColor = Color(0xFF0A1628);
  static const Color surfaceColor = Color(0xFF0F1E36);
  static const Color cardColor = Color(0x33FFFFFF); // 半透明白色卡片

  // 语音状态颜色
  static const Color voiceActiveColor = Color(0xFF2196F3);
  static const Color voiceGlowColor = Color(0xFF64B5F6);
  static const Color voiceIdleColor = Color(0xFF4CAF50);
  static const Color voiceListeningColor = Color(0xFF2196F3);
  static const Color voiceProcessingColor = Color(0xFFFFC107);

  // 安全/警告
  static const Color warningColor = Color(0xFFFF9800);
  static const Color dangerColor = Color(0xFFF44336);
  static const Color safeColor = Color(0xFF4CAF50);

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: backgroundColor,
      colorScheme: const ColorScheme.dark(
        primary: primaryColor,
        secondary: accentColor,
        surface: surfaceColor,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        headlineMedium: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        bodyLarge: TextStyle(
          fontSize: 17,
          color: Colors.white,
          height: 1.6,
        ),
        bodyMedium: TextStyle(
          fontSize: 15,
          color: Colors.white70,
        ),
      ),
    );
  }
}
