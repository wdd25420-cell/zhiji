import 'package:flutter/material.dart';

/// OKLch 色彩 → Flutter Color 映射
/// 来源：prototype css/tokens.css
///
/// Seed color: oklch(56% 0.12 170) ≈ #00897B (青绿)
class AppColors {
  AppColors._();

  /// Seed color for ColorScheme.fromSeed()
  static const Color seed = Color(0xFF00897B);

  /// 深色模式专用色 — UX 升级：纯黑省电 + 卡片深灰
  static const Color darkBackground = Color(0xFF121212);
  static const Color darkCard = Color(0xFF1E1E1E);
}
