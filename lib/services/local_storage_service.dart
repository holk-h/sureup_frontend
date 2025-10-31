import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// 本地存储服务 - 管理用户统计数据的本地持久化
class LocalStorageService {
  static final LocalStorageService _instance = LocalStorageService._internal();
  factory LocalStorageService() => _instance;
  LocalStorageService._internal();

  SharedPreferences? _prefs;

  /// 初始化 SharedPreferences
  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// 确保已初始化
  Future<SharedPreferences> get prefs async {
    if (_prefs == null) {
      await initialize();
    }
    return _prefs!;
  }

  // ==================== 统计数据存储 ====================

  /// 保存用户统计数据
  Future<void> saveUserStats(String userId, Map<String, dynamic> stats) async {
    final p = await prefs;
    final key = 'user_stats_$userId';
    await p.setString(key, jsonEncode(stats));
    print('💾 已保存统计数据到本地: $key');
  }

  /// 获取用户统计数据
  Future<Map<String, dynamic>?> getUserStats(String userId) async {
    final p = await prefs;
    final key = 'user_stats_$userId';
    final jsonStr = p.getString(key);
    
    if (jsonStr == null) {
      print('📭 本地无统计数据: $key');
      return null;
    }
    
    try {
      final stats = jsonDecode(jsonStr) as Map<String, dynamic>;
      print('📦 从本地加载统计数据: $key');
      return stats;
    } catch (e) {
      print('⚠️ 解析统计数据失败: $e');
      return null;
    }
  }

  /// 更新单个统计字段
  Future<void> updateUserStatField(String userId, String field, dynamic value) async {
    final stats = await getUserStats(userId) ?? getDefaultStats();
    stats[field] = value;
    stats['updatedAt'] = DateTime.now().toIso8601String();
    await saveUserStats(userId, stats);
  }

  /// 批量更新统计字段
  Future<void> updateUserStatFields(String userId, Map<String, dynamic> updates) async {
    final stats = await getUserStats(userId) ?? getDefaultStats();
    stats.addAll(updates);
    stats['updatedAt'] = DateTime.now().toIso8601String();
    await saveUserStats(userId, stats);
  }

  /// 清除用户统计数据
  Future<void> clearUserStats(String userId) async {
    final p = await prefs;
    final key = 'user_stats_$userId';
    await p.remove(key);
    print('🗑️ 已清除统计数据: $key');
  }

  // ==================== 用户信息存储 ====================

  /// 保存用户基本信息
  Future<void> saveUserInfo(String userId, Map<String, dynamic> userInfo) async {
    final p = await prefs;
    final key = 'user_info_$userId';
    await p.setString(key, jsonEncode(userInfo));
  }

  /// 获取用户基本信息
  Future<Map<String, dynamic>?> getUserInfo(String userId) async {
    final p = await prefs;
    final key = 'user_info_$userId';
    final jsonStr = p.getString(key);
    
    if (jsonStr == null) return null;
    
    try {
      return jsonDecode(jsonStr) as Map<String, dynamic>;
    } catch (e) {
      print('⚠️ 解析用户信息失败: $e');
      return null;
    }
  }

  // ==================== 周数据缓存 ====================

  /// 保存本周图表数据（每次更新时同步）
  Future<void> saveWeeklyChartData(String userId, List<Map<String, dynamic>> data) async {
    final p = await prefs;
    final key = 'weekly_chart_$userId';
    await p.setString(key, jsonEncode(data));
  }

  /// 获取本周图表数据
  Future<List<Map<String, dynamic>>?> getWeeklyChartData(String userId) async {
    final p = await prefs;
    final key = 'weekly_chart_$userId';
    final jsonStr = p.getString(key);
    
    if (jsonStr == null) return null;
    
    try {
      final List<dynamic> list = jsonDecode(jsonStr);
      return list.map((item) => item as Map<String, dynamic>).toList();
    } catch (e) {
      print('⚠️ 解析周数据失败: $e');
      return null;
    }
  }

  // ==================== 辅助方法 ====================

  /// 获取默认统计数据结构
  Map<String, dynamic> getDefaultStats() {
    return {
      'totalMistakes': 0,
      'masteredMistakes': 0,
      'totalPracticeSessions': 0,
      'completedSessions': 0,
      'continuousDays': 0,
      'weekMistakes': 0,
      'lastPracticeDate': null,
      'statsUpdatedAt': null,
      'updatedAt': DateTime.now().toIso8601String(),
    };
  }

  /// 清除所有数据（用于登出）
  Future<void> clearAll() async {
    final p = await prefs;
    await p.clear();
    print('🗑️ 已清除所有本地数据');
  }
}

