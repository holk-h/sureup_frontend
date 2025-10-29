import 'package:flutter/material.dart';

/// 稳了！设计系统 - 现代高级配色（绿色主题）
class AppColors {
  // 主色调：清新绿
  static const Color primary = Color(0xFF10B981); // emerald-500
  static const Color primaryDark = Color(0xFF059669); // emerald-600
  static const Color primaryLight = Color(0xFF34D399); // emerald-400
  static const Color primaryUltraLight = Color(0xFFECFDF5); // emerald-50

  // 辅助色：活力蓝
  static const Color accent = Color(0xFF3B82F6); // blue-500
  static const Color accentDark = Color(0xFF2563EB); // blue-600
  static const Color accentLight = Color(0xFF60A5FA); // blue-400
  static const Color accentUltraLight = Color(0xFFEFF6FF); // blue-50
  
  // 次要色（用于练习页面）
  static const Color secondary = Color(0xFF3B82F6); // 与accent相同
  static const Color secondaryDark = Color(0xFF2563EB);
  static const Color secondaryLight = Color(0xFF60A5FA);

  // 功能色
  static const Color success = Color(0xFF10B981); // 与主色一致
  static const Color successLight = Color(0xFF34D399);
  static const Color error = Color(0xFFEF4444); // red-500
  static const Color errorLight = Color(0xFFF87171); // red-400
  static const Color warning = Color(0xFFF59E0B); // amber-500
  static const Color warningLight = Color(0xFFFBBF24); // amber-400
  
  // 错题记录色：温和的粉色系
  static const Color mistake = Color(0xFFEC4899); // pink-500，温和友好
  static const Color mistakeLight = Color(0xFFF472B6); // pink-400

  // 中性色 - 背景
  static const Color background = Color(0xFFFAFAFC); // 极浅灰背景，更舒适
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color surfaceElevated = Color(0xFFFFFFFE);
  
  // 背景渐变 - 柔和的淡彩色渐变（粉紫蓝调）
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFFFF1F3), // 淡粉色 rose-50
      Color(0xFFFCF5FF), // 淡紫色 purple-50
      Color(0xFFF0F9FF), // 淡蓝色 sky-50
      Color(0xFFECFEFF), // 淡青色 cyan-50
    ],
    stops: [0.0, 0.33, 0.66, 1.0],
  );
  
  // 高级渐变 - 微妙的同色系渐变
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF10B981), // emerald-500
      Color(0xFF34D399), // emerald-400
    ],
  );
  
  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF3B82F6), // blue-500
      Color(0xFF60A5FA), // blue-400
    ],
  );
  
  static const LinearGradient successGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF10B981), // emerald-500
      Color(0xFF34D399), // emerald-400
    ],
  );
  
  static const LinearGradient warningGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFF59E0B), // amber-500
      Color(0xFFFBBF24), // amber-400
    ],
  );
  
  static const LinearGradient secondaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF3B82F6), // blue-500
      Color(0xFF60A5FA), // blue-400
    ],
  );
  
  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFFFFFFF),
      Color(0xFFFAFBFC),
    ],
  );

  // 学科渐变 - 更新为新配色
  static const LinearGradient mathGradient = LinearGradient(
    colors: [Color(0xFFEFF6FF), Color(0xFFDBEAFE)], // blue-50 to blue-100
  );
  
  static const LinearGradient physicsGradient = LinearGradient(
    colors: [Color(0xFFFAF5FF), Color(0xFFF3E8FF)], // purple-50 to purple-100
  );
  
  static const LinearGradient chemistryGradient = LinearGradient(
    colors: [Color(0xFFFEF2F2), Color(0xFFFEE2E2)], // red-50 to red-100
  );
  
  static const LinearGradient englishGradient = LinearGradient(
    colors: [Color(0xFFECFDF5), Color(0xFFD1FAE5)], // emerald-50 to emerald-100
  );

  // 学科纯色（用于非渐变场景）
  static const Color subjectMath = Color(0xFFEFF6FF); // blue-50
  static const Color subjectPhysics = Color(0xFFFAF5FF); // purple-50
  static const Color subjectChemistry = Color(0xFFFEF2F2); // red-50
  static const Color subjectEnglish = Color(0xFFECFDF5); // emerald-50
  static const Color subjectDefault = Color(0xFFF9FAFB); // gray-50

  // 中性色 - 文字
  static const Color textPrimary = Color(0xFF1A1A1C);
  static const Color textSecondary = Color(0xFF48484A);
  static const Color textTertiary = Color(0xFF8E8E93);
  static const Color textDisabled = Color(0xFFC7C7CC);

  // 分割线
  static const Color divider = Color(0xFFEBEBF0);
  static const Color dividerLight = Color(0xFFF2F2F7);
  
  // 现代阴影系统 - 多层阴影创造深度
  static const Color shadowLight = Color(0x08000000);
  
  static const List<BoxShadow> shadowSoft = [
    BoxShadow(
      color: Color(0x08000000),
      blurRadius: 12,
      offset: Offset(0, 2),
    ),
    BoxShadow(
      color: Color(0x04000000),
      blurRadius: 4,
      offset: Offset(0, 1),
    ),
  ];
  
  static const List<BoxShadow> shadowMedium = [
    BoxShadow(
      color: Color(0x0D000000),
      blurRadius: 20,
      offset: Offset(0, 4),
    ),
    BoxShadow(
      color: Color(0x05000000),
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];
  
  static const List<BoxShadow> shadowLarge = [
    BoxShadow(
      color: Color(0x12000000),
      blurRadius: 32,
      offset: Offset(0, 8),
    ),
    BoxShadow(
      color: Color(0x08000000),
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
  ];
  
  // 彩色阴影 - 为主色调卡片增加高级感
  static List<BoxShadow> coloredShadow(Color color, {double opacity = 0.2}) {
    return [
      BoxShadow(
        color: color.withOpacity(opacity),
        blurRadius: 20,
        offset: const Offset(0, 8),
      ),
      BoxShadow(
        color: color.withOpacity(opacity * 0.5),
        blurRadius: 10,
        offset: const Offset(0, 4),
      ),
    ];
  }
}

