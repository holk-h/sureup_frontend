import 'dart:convert';
import 'package:appwrite/appwrite.dart';
import '../config/api_config.dart';
import '../models/models.dart';
import 'local_storage_service.dart';

/// 统计数据服务 - 处理用户统计数据的获取和展示
/// 
/// 新架构说明：
/// - 统计数据由后端自动更新（mistake_analyzer 和 stats-updater）
/// - 前端主要从 UserProfile 读取统计数据
/// - 本地缓存用于离线访问和快速显示
/// - 不再需要前端手动更新统计，后端事件触发自动更新
class StatsService {
  static final StatsService _instance = StatsService._internal();
  factory StatsService() => _instance;
  StatsService._internal();

  late Client _client;
  late Databases _databases;
  final LocalStorageService _localStorage = LocalStorageService();
  
  // 内存缓存，避免频繁读取本地存储
  final Map<String, Map<String, dynamic>> _memoryCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  static const _cacheValidDuration = Duration(minutes: 5);
  
  /// 初始化客户端和本地存储
  Future<void> initialize(Client client) async {
    _client = client;
    _databases = Databases(_client);
    // 本地存储已在 main.dart 中预初始化，这里不需要再次初始化
  }

  /// 获取用户的主页统计数据
  /// 
  /// 策略：内存缓存 > 本地缓存 > 云端数据，三级缓存提升性能
  Future<Map<String, dynamic>> getHomeStats(String userId) async {
    try {
      // 1. 先检查内存缓存（超快，无 I/O）
      if (_memoryCache.containsKey(userId)) {
        final cacheTime = _cacheTimestamps[userId];
        if (cacheTime != null && 
            DateTime.now().difference(cacheTime) < _cacheValidDuration) {
          print('⚡ 从内存缓存加载统计数据');
          // 后台刷新（不阻塞）
          _refreshStatsInBackground(userId);
          return _memoryCache[userId]!;
        }
      }
      
      // 2. 从本地存储读取（快）
      final localStats = await _localStorage.getUserStats(userId);
      if (localStats != null) {
        print('📦 从本地存储加载统计数据');
        final enrichedStats = _enrichStatsData(localStats);
        // 更新内存缓存
        _memoryCache[userId] = enrichedStats;
        _cacheTimestamps[userId] = DateTime.now();
        // 后台刷新云端数据（不阻塞）
        _refreshStatsInBackground(userId);
        return enrichedStats;
      }

      // 3. 本地无数据，从云端同步（慢）
      print('🔄 从云端读取统计数据...');
      return await _fetchStatsFromProfile(userId);
      
    } catch (e) {
      print('获取主页统计数据失败: $e');
      return _getDefaultStats();
    }
  }
  
  /// 后台刷新统计数据（不阻塞 UI）
  void _refreshStatsInBackground(String userId) {
    _fetchStatsFromProfile(userId).catchError((e) {
      print('⚠️ 后台刷新统计失败: $e');
      return <String, dynamic>{}; // 返回空 map
    });
  }
  
  /// 从 UserProfile 获取统计数据
  Future<Map<String, dynamic>> _fetchStatsFromProfile(String userId) async {
    try {
      // 通过 userId 字段查询 profile
      final response = await _databases.listDocuments(
        databaseId: ApiConfig.databaseId,
        collectionId: ApiConfig.usersCollectionId,
        queries: [
          Query.equal('userId', userId),
          Query.limit(1),
        ],
      );
      
      if (response.documents.isEmpty) {
        print('⚠️ 未找到用户档案');
        return _getDefaultStats();
      }
      
      final doc = response.documents.first;
      final profile = UserProfile.fromJson({
        'id': doc.$id,
        ...doc.data,
      });
      
      // 转换为统计数据格式
      final stats = _profileToStats(profile);
      final enrichedStats = _enrichStatsData(stats);
      
      // 更新内存缓存
      _memoryCache[userId] = enrichedStats;
      _cacheTimestamps[userId] = DateTime.now();
      
      // 保存到本地缓存
      await _localStorage.saveUserStats(userId, stats);
      
      print('✅ 统计数据已从云端更新');
      return enrichedStats;
      
    } catch (e) {
      print('从 Profile 获取统计失败: $e');
      return _getDefaultStats();
    }
  }
  
  /// 将 UserProfile 转换为统计数据格式
  Map<String, dynamic> _profileToStats(UserProfile profile) {
    // 解析 weeklyMistakesData JSON
    List<Map<String, dynamic>> weeklyData = [];
    if (profile.weeklyMistakesData != null && profile.weeklyMistakesData!.isNotEmpty) {
      try {
        // 尝试解析 JSON 字符串
        final decoded = jsonDecode(profile.weeklyMistakesData!);
        if (decoded is List) {
          weeklyData = decoded.map((e) => {
            'date': e['date'] as String,
            'count': e['count'] as int,
          }).toList();
        }
      } catch (e) {
        print('⚠️ 解析 weeklyMistakesData 失败: $e');
      }
    }
    
    return {
      // 错题统计
      'totalMistakes': profile.totalMistakes,
      'masteredMistakes': profile.masteredMistakes,
      'todayMistakes': profile.todayMistakes,
      'weekMistakes': profile.weekMistakes,
      
      // 练习统计
      'totalPracticeSessions': profile.totalPracticeSessions,
      'completedSessions': profile.completedSessions,
      'todayPracticeSessions': profile.todayPracticeSessions,
      'weekPracticeSessions': profile.weekPracticeSessions,
      
      // 答题统计
      'totalQuestions': profile.totalQuestions,
      'totalCorrectAnswers': profile.totalCorrectAnswers,
      
      // 学习进度
      'continuousDays': profile.continuousDays,
      'activeDays': profile.activeDays,
      
      // 图表数据（原始 JSON 数据）
      'weeklyMistakesData': weeklyData,
      
      // 用户信息
      'userName': profile.name,
      'usageDays': profile.activeDays, // 使用 activeDays 而不是注册天数
      
      // 时间戳
      'createdAt': profile.createdAt.toIso8601String(),
      'lastActiveAt': profile.lastActiveAt?.toIso8601String(),
      'lastPracticeDate': profile.lastPracticeDate?.toIso8601String(),
      'statsUpdatedAt': profile.statsUpdatedAt?.toIso8601String(),
    };
  }
  
  /// 丰富统计数据（计算派生字段）
  Map<String, dynamic> _enrichStatsData(Map<String, dynamic> stats) {
    return {
      ...stats,
      // 计算派生字段
      'notMasteredCount': (stats['totalMistakes'] ?? 0) - (stats['masteredMistakes'] ?? 0),
      'progress': _calculateProgress(stats),
      'completionRate': _calculateCompletionRate(stats),
      'accuracy': _calculateAccuracy(stats),
      // 格式化周数据为图表格式
      'weeklyChartData': _formatWeeklyChartData(stats['weeklyMistakesData']),
    };
  }
  
  /// 格式化周数据为图表格式
  /// 
  /// 输入：[{"date": "2024-11-01", "count": 5}, ...]
  /// 输出：[{"day": "周一", "date": "2024-11-01", "mistakeCount": 5.0, ...}, ...]
  List<Map<String, dynamic>> _formatWeeklyChartData(dynamic weeklyData) {
    if (weeklyData == null || weeklyData is! List) {
      return _getDefaultWeeklyData();
    }
    
    // 确保有最近7天的数据
    final now = DateTime.now();
    final result = <Map<String, dynamic>>[];
    
    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dateStr = _getDateKey(date);
      
      // 查找该日期的数据
      int count = 0;
      try {
        // 使用 where + first 避免类型问题
        final matchingData = weeklyData.where((e) => e['date'] == dateStr);
        if (matchingData.isNotEmpty) {
          final dayData = matchingData.first;
          count = (dayData['count'] as num?)?.toInt() ?? 0;
        }
      } catch (e) {
        count = 0;
      }
      
      result.add({
        'day': _getDayName(date.weekday),
        'date': dateStr,
        'mistakeCount': count.toDouble(),
        'practiceCount': 0.0, // 暂时没有练习数据
        'isToday': i == 0,
      });
    }
    
    return result;
  }
  
  /// 计算掌握进度（错题掌握率）
  double _calculateProgress(Map<String, dynamic> stats) {
    final total = stats['totalMistakes'] ?? 0;
    final mastered = stats['masteredMistakes'] ?? 0;
    if (total == 0) return 0.0;
    return mastered / total;
  }

  /// 计算练习完成率
  int _calculateCompletionRate(Map<String, dynamic> stats) {
    final total = stats['totalPracticeSessions'] ?? 0;
    final completed = stats['completedSessions'] ?? 0;
    if (total == 0) return 0;
    return ((completed / total) * 100).round();
  }
  
  /// 计算答题准确率
  double _calculateAccuracy(Map<String, dynamic> stats) {
    final total = stats['totalQuestions'] ?? 0;
    final correct = stats['totalCorrectAnswers'] ?? 0;
    if (total == 0) return 0.0;
    return correct / total;
  }
  
  /// 获取日期键（用于分组）格式：YYYY-MM-DD
  String _getDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// 获取星期几的中文名称
  String _getDayName(int weekday) {
    switch (weekday) {
      case 1: return '周一';
      case 2: return '周二';
      case 3: return '周三';
      case 4: return '周四';
      case 5: return '周五';
      case 6: return '周六';
      case 7: return '周日';
      default: return '';
    }
  }

  /// 获取默认统计数据（当获取真实数据失败时使用）
  Map<String, dynamic> _getDefaultStats() {
    return {
      'totalMistakes': 0,
      'masteredMistakes': 0,
      'todayMistakes': 0,
      'weekMistakes': 0,
      'notMasteredCount': 0,
      'progress': 0.0,
      'totalPracticeSessions': 0,
      'completedSessions': 0,
      'todayPracticeSessions': 0,
      'weekPracticeSessions': 0,
      'completionRate': 0,
      'continuousDays': 0,
      'activeDays': 0,
      'totalQuestions': 0,
      'totalCorrectAnswers': 0,
      'accuracy': 0.0,
      'weeklyChartData': _getDefaultWeeklyData(),
      'weeklyMistakesData': [],
      'usageDays': 0,
      'userName': '用户',
    };
  }

  /// 获取默认周数据（7天全为0）
  List<Map<String, dynamic>> _getDefaultWeeklyData() {
    final now = DateTime.now();
    final List<Map<String, dynamic>> data = [];
    
    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      data.add({
        'day': _getDayName(date.weekday),
        'date': _getDateKey(date),
        'mistakeCount': 0.0,
        'practiceCount': 0.0,
        'isToday': i == 0,
      });
    }
    
    return data;
  }

  /// 每周一重置本周统计（可选，由后端 stats-updater 处理）
  /// 
  /// 注意：这个方法已废弃，统计重置由后端处理
  /// 保留此方法仅用于兼容性，实际不做任何操作
  @Deprecated('统计重置由后端 stats-updater 处理')
  Future<void> resetWeeklyStatsIfNeeded(String userId) async {
    print('ℹ️ resetWeeklyStatsIfNeeded 已废弃，统计由后端自动更新');
    // 不做任何操作，后端会自动处理
  }

  /// 强制刷新统计数据（手动触发）
  /// 从云端重新读取并更新本地缓存
  Future<void> forceRefreshStats(String userId) async {
    print('🔄 开始强制刷新统计数据...');
    await _fetchStatsFromProfile(userId);
    print('✅ 统计数据强制刷新完成');
  }
}
