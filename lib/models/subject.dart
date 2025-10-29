import 'package:flutter/material.dart';

/// 学科枚举
enum Subject {
  math('数学', '📐', Color(0xFF3B82F6)),      // blue-500
  physics('物理', '⚛️', Color(0xFF8B5CF6)),    // purple-500
  chemistry('化学', '🧪', Color(0xFFEF4444)),  // red-500
  biology('生物', '🧬', Color(0xFF22C55E)),    // green-500
  chinese('语文', '📖', Color(0xFFF59E0B)),    // amber-500
  english('英语', '🔤', Color(0xFF10B981)),    // emerald-500
  history('历史', '📜', Color(0xFFDC2626)),    // red-600
  geography('地理', '🌍', Color(0xFF14B8A6)),  // teal-500
  politics('政治', '⚖️', Color(0xFFF97316));   // orange-500

  const Subject(this.displayName, this.icon, this.color);
  
  final String displayName;
  final String icon;
  final Color color;

  /// 从字符串解析
  static Subject? fromString(String value) {
    return Subject.values.where((e) => e.name == value || e.displayName == value).firstOrNull;
  }
}

