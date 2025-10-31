import 'package:appwrite/appwrite.dart';
import '../config/api_config.dart';
import '../models/models.dart';
import 'local_storage_service.dart';

/// 统计数据服务 - 处理用户统计数据的获取和计算
/// 采用本地优先策略：数据持久化在本地，增量更新时同步云端
class StatsService {
  static final StatsService _instance = StatsService._internal();
  factory StatsService() => _instance;
  StatsService._internal();

  late Client _client;
  late Databases _databases;
  final LocalStorageService _localStorage = LocalStorageService();
  
  /// 初始化客户端和本地存储
  Future<void> initialize(Client client) async {
    _client = client;
    _databases = Databases(_client);
    await _localStorage.initialize();
  }

  /// 获取用户的主页统计数据
  /// 本地优先策略：优先从本地读取，本地无数据时从云端同步
  Future<Map<String, dynamic>> getHomeStats(String userId) async {
    try {
      // 1. 先从本地读取
      final localStats = await _localStorage.getUserStats(userId);
      final localWeeklyData = await _localStorage.getWeeklyChartData(userId);
      
      if (localStats != null) {
        // 本地有数据，直接返回（加上图表数据）
        print('📦 从本地加载统计数据');
        
        return {
          ...localStats,
          'weeklyChartData': localWeeklyData ?? _getDefaultWeeklyData(),
          // 计算派生字段
          'notMasteredCount': (localStats['totalMistakes'] ?? 0) - (localStats['masteredMistakes'] ?? 0),
          'progress': _calculateProgress(localStats),
          'completionRate': _calculateCompletionRate(localStats),
        };
      }

      // 2. 本地无数据，从云端同步（初始化）
      print('🔄 本地无数据，从云端初始化...');
      return await syncFromCloud(userId);
      
    } catch (e) {
      print('获取主页统计数据失败: $e');
      // 出错也尝试返回本地数据
      final localStats = await _localStorage.getUserStats(userId);
      return localStats ?? _getDefaultStats();
    }
  }

  /// 从云端同步完整数据到本地（初始化或强制刷新时使用）
  Future<Map<String, dynamic>> syncFromCloud(String userId) async {
    try {
      final userProfile = await _getUserProfile(userId);
      
      if (userProfile == null) {
        return _getDefaultStats();
      }

      // 并行获取所有数据
      final futures = await Future.wait([
        _getMistakeStats(userId),
        _getPracticeStats(userId),
        _getWeeklyData(userId),
      ]);

      final mistakeStats = futures[0] as Map<String, dynamic>;
      final practiceStats = futures[1] as Map<String, dynamic>;
      final weeklyData = futures[2] as List<Map<String, dynamic>>;

      // 构建统计数据
      final stats = {
        // 错题统计
        'totalMistakes': mistakeStats['total'] ?? 0,
        'masteredMistakes': mistakeStats['mastered'] ?? 0,
        'weekMistakes': mistakeStats['weekMistakes'] ?? 0,
        
        // 练习统计
        'totalPracticeSessions': practiceStats['total'] ?? 0,
        'completedSessions': practiceStats['completed'] ?? 0,
        'continuousDays': practiceStats['continuousDays'] ?? 0,
        'lastPracticeDate': null, // 需要从最后一次练习记录获取
        
        // 用户信息
        'userName': userProfile.name,
        'usageDays': DateTime.now().difference(userProfile.createdAt).inDays + 1,
        'createdAt': userProfile.createdAt.toIso8601String(),
        
        // 元数据
        'statsUpdatedAt': DateTime.now().toIso8601String(),
      };

      // 保存到本地
      await _localStorage.saveUserStats(userId, stats);
      await _localStorage.saveWeeklyChartData(userId, weeklyData);

      // 同时更新云端的统计字段
      await _updateCloudStats(userId, stats);

      print('✅ 已从云端同步数据到本地');

      return {
        ...stats,
        'weeklyChartData': weeklyData,
        'notMasteredCount': (stats['totalMistakes'] ?? 0) - (stats['masteredMistakes'] ?? 0),
        'progress': _calculateProgress(stats),
        'completionRate': _calculateCompletionRate(stats),
      };
    } catch (e) {
      print('从云端同步失败: $e');
      return _getDefaultStats();
    }
  }

  /// 辅助方法：计算进度
  double _calculateProgress(Map<String, dynamic> stats) {
    final total = stats['totalMistakes'] ?? 0;
    final mastered = stats['masteredMistakes'] ?? 0;
    if (total == 0) return 0.0;
    return mastered / total;
  }

  /// 辅助方法：计算完成率
  int _calculateCompletionRate(Map<String, dynamic> stats) {
    final total = stats['totalPracticeSessions'] ?? 0;
    final completed = stats['completedSessions'] ?? 0;
    if (total == 0) return 0;
    return ((completed / total) * 100).round();
  }

  /// 更新云端统计数据
  Future<void> _updateCloudStats(String userId, Map<String, dynamic> stats) async {
    try {
      await _databases.updateDocument(
        databaseId: ApiConfig.databaseId,
        collectionId: ApiConfig.usersCollectionId,
        documentId: userId,
        data: {
          'totalMistakes': stats['totalMistakes'],
          'masteredMistakes': stats['masteredMistakes'],
          'totalPracticeSessions': stats['totalPracticeSessions'],
          'completedSessions': stats['completedSessions'],
          'continuousDays': stats['continuousDays'],
          'weekMistakes': stats['weekMistakes'],
          'lastPracticeDate': stats['lastPracticeDate'],
          'statsUpdatedAt': stats['statsUpdatedAt'],
        },
      );
    } catch (e) {
      print('⚠️ 更新云端统计失败（继续使用本地数据）: $e');
    }
  }

  /// 获取错题统计数据
  Future<Map<String, dynamic>> _getMistakeStats(String userId) async {
    try {
      // 获取所有错题记录
      final response = await _databases.listDocuments(
        databaseId: ApiConfig.databaseId,
        collectionId: ApiConfig.mistakeRecordsCollectionId,
        queries: [
          Query.equal('userId', userId),
          Query.limit(1000), // 获取更多数据用于统计
        ],
      );

      final mistakes = response.documents
          .map((doc) => MistakeRecord.fromJson({
                'id': doc.$id,
                'createdAt': doc.$createdAt,
                'updatedAt': doc.$updatedAt,
                ...doc.data,
              }))
          .toList();

      final total = mistakes.length;
      final mastered = mistakes.where((m) => m.masteryStatus == MasteryStatus.mastered).length;
      final notMastered = total - mastered;
      final progress = total > 0 ? mastered / total : 0.0;

      // 计算本周错题数
      final now = DateTime.now();
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      final weekMistakes = mistakes.where((m) => 
        m.createdAt.isAfter(weekStart)
      ).length;

      return {
        'total': total,
        'mastered': mastered,
        'notMastered': notMastered,
        'progress': progress,
        'weekMistakes': weekMistakes,
      };
    } catch (e) {
      print('获取错题统计失败: $e');
      return {
        'total': 0,
        'mastered': 0,
        'notMastered': 0,
        'progress': 0.0,
        'weekMistakes': 0,
      };
    }
  }

  /// 获取练习统计数据
  Future<Map<String, dynamic>> _getPracticeStats(String userId) async {
    try {
      // 获取所有练习会话
      final response = await _databases.listDocuments(
        databaseId: ApiConfig.databaseId,
        collectionId: ApiConfig.practiceSessionsCollectionId,
        queries: [
          Query.equal('userId', userId),
          Query.limit(1000),
        ],
      );

      final sessions = response.documents
          .map((doc) => PracticeSession.fromJson({
                'id': doc.$id,
                'createdAt': doc.$createdAt,
                'updatedAt': doc.$updatedAt,
                ...doc.data,
              }))
          .toList();

      final total = sessions.length;
      final completed = sessions.where((s) => s.isCompleted).length;
      final completionRate = total > 0 ? (completed / total * 100).round() : 0;

      // 计算连续练习天数
      final continuousDays = _calculateContinuousDays(sessions);

      return {
        'total': total,
        'completed': completed,
        'completionRate': completionRate,
        'continuousDays': continuousDays,
      };
    } catch (e) {
      print('获取练习统计失败: $e');
      return {
        'total': 0,
        'completed': 0,
        'completionRate': 0,
        'continuousDays': 0,
      };
    }
  }

  /// 获取过去一周的数据（用于图表展示）
  Future<List<Map<String, dynamic>>> _getWeeklyData(String userId) async {
    try {
      final now = DateTime.now();
      final weekStart = now.subtract(const Duration(days: 6));
      
      // 获取过去一周的错题记录
      final mistakeResponse = await _databases.listDocuments(
        databaseId: ApiConfig.databaseId,
        collectionId: ApiConfig.mistakeRecordsCollectionId,
        queries: [
          Query.equal('userId', userId),
          Query.greaterThanEqual('\$createdAt', weekStart.toIso8601String()),
          Query.limit(1000),
        ],
      );

      // 获取过去一周的练习会话
      final practiceResponse = await _databases.listDocuments(
        databaseId: ApiConfig.databaseId,
        collectionId: ApiConfig.practiceSessionsCollectionId,
        queries: [
          Query.equal('userId', userId),
          Query.greaterThanEqual('\$createdAt', weekStart.toIso8601String()),
          Query.limit(1000),
        ],
      );

      final mistakes = mistakeResponse.documents
          .map((doc) => MistakeRecord.fromJson({
                'id': doc.$id,
                'createdAt': doc.$createdAt,
                'updatedAt': doc.$updatedAt,
                ...doc.data,
              }))
          .toList();

      final practices = practiceResponse.documents
          .map((doc) => PracticeSession.fromJson({
                'id': doc.$id,
                'createdAt': doc.$createdAt,
                'updatedAt': doc.$updatedAt,
                // 如果没有 startedAt，使用 createdAt
                'startedAt': doc.data['startedAt'] ?? doc.$createdAt,
                ...doc.data,
              }))
          .toList();

      // 按天统计数据
      final List<Map<String, dynamic>> weeklyData = [];
      for (int i = 6; i >= 0; i--) {
        final date = now.subtract(Duration(days: i));
        final dayStart = DateTime(date.year, date.month, date.day);
        final dayEnd = dayStart.add(const Duration(days: 1));

        final dayMistakes = mistakes.where((m) => 
          m.createdAt.isAfter(dayStart) && m.createdAt.isBefore(dayEnd)
        ).length;

        final dayPractices = practices.where((p) => 
          p.startedAt.isAfter(dayStart) && p.startedAt.isBefore(dayEnd)
        ).length;

        weeklyData.add({
          'day': _getDayName(date.weekday),
          'date': date.toIso8601String(),
          'mistakeCount': dayMistakes.toDouble(),
          'practiceCount': dayPractices.toDouble(),
          'isToday': i == 0,
        });
      }

      return weeklyData;
    } catch (e) {
      print('获取周数据失败: $e');
      return _getDefaultWeeklyData();
    }
  }

  /// 获取用户档案
  Future<UserProfile?> _getUserProfile(String userId) async {
    try {
      final document = await _databases.getDocument(
        databaseId: ApiConfig.databaseId,
        collectionId: ApiConfig.usersCollectionId,
        documentId: userId,
      );

      return UserProfile.fromJson({
        'id': document.$id,
        ...document.data,
      });
    } catch (e) {
      print('获取用户档案失败: $e');
      return null;
    }
  }

  /// 计算连续练习天数
  int _calculateContinuousDays(List<PracticeSession> sessions) {
    if (sessions.isEmpty) return 0;

    // 按日期分组练习会话
    final Map<String, List<PracticeSession>> sessionsByDate = {};
    for (final session in sessions) {
      final dateKey = _getDateKey(session.startedAt);
      if (!sessionsByDate.containsKey(dateKey)) {
        sessionsByDate[dateKey] = [];
      }
      sessionsByDate[dateKey]!.add(session);
    }

    // 从今天开始往前计算连续天数
    int continuousDays = 0;
    final now = DateTime.now();
    
    for (int i = 0; i < 365; i++) { // 最多检查一年
      final checkDate = now.subtract(Duration(days: i));
      final dateKey = _getDateKey(checkDate);
      
      if (sessionsByDate.containsKey(dateKey) && sessionsByDate[dateKey]!.isNotEmpty) {
        continuousDays++;
      } else {
        break; // 遇到没有练习的日期就停止
      }
    }

    return continuousDays;
  }

  /// 获取日期键（用于分组）
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
      'notMasteredCount': 0,
      'masteredCount': 0,
      'progress': 0.0,
      'totalPracticeSessions': 0,
      'completionRate': 0,
      'continuousDays': 0,
      'weekMistakes': 0,
      'weeklyChartData': _getDefaultWeeklyData(),
      'usageDays': 0,
      'userName': '用户',
    };
  }

  /// 获取默认周数据
  List<Map<String, dynamic>> _getDefaultWeeklyData() {
    final now = DateTime.now();
    final List<Map<String, dynamic>> data = [];
    
    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      data.add({
        'day': _getDayName(date.weekday),
        'date': date,
        'mistakeCount': 0.0,
        'practiceCount': 0.0,
        'isToday': i == 0,
      });
    }
    
    return data;
  }

  // ==================== 增量更新方法 ====================

  /// 增量更新：新增错题时调用
  /// 同时更新本地和云端的 totalMistakes 和 weekMistakes
  Future<void> incrementMistakeCount(String userId) async {
    try {
      // 1. 读取本地数据
      final localStats = await _localStorage.getUserStats(userId) ?? _localStorage.getDefaultStats();
      
      final now = DateTime.now();
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      final isThisWeek = now.isAfter(weekStart);

      // 2. 更新本地数据
      await _localStorage.updateUserStatFields(userId, {
        'totalMistakes': (localStats['totalMistakes'] ?? 0) + 1,
        'weekMistakes': isThisWeek ? (localStats['weekMistakes'] ?? 0) + 1 : (localStats['weekMistakes'] ?? 0),
        'statsUpdatedAt': now.toIso8601String(),
      });

      // 3. 同步到云端
      final updatedStats = await _localStorage.getUserStats(userId);
      if (updatedStats != null) {
        await _updateCloudStats(userId, updatedStats);
      }
      
      print('✅ 已更新错题统计: totalMistakes=${(localStats['totalMistakes'] ?? 0) + 1}');
    } catch (e) {
      print('⚠️ 更新错题统计失败: $e');
    }
  }

  /// 增量更新：错题被标记为已掌握时调用
  /// 同时更新本地和云端的 masteredMistakes
  Future<void> incrementMasteredCount(String userId) async {
    try {
      // 1. 读取本地数据
      final localStats = await _localStorage.getUserStats(userId) ?? _localStorage.getDefaultStats();
      
      // 2. 更新本地数据
      await _localStorage.updateUserStatFields(userId, {
        'masteredMistakes': (localStats['masteredMistakes'] ?? 0) + 1,
        'statsUpdatedAt': DateTime.now().toIso8601String(),
      });

      // 3. 同步到云端
      final updatedStats = await _localStorage.getUserStats(userId);
      if (updatedStats != null) {
        await _updateCloudStats(userId, updatedStats);
      }
      
      print('✅ 已更新掌握统计: masteredMistakes=${(localStats['masteredMistakes'] ?? 0) + 1}');
    } catch (e) {
      print('⚠️ 更新掌握统计失败: $e');
    }
  }

  /// 增量更新：开始练习时调用
  /// 同时更新本地和云端的 totalPracticeSessions、lastPracticeDate 和 continuousDays
  Future<void> incrementPracticeSession(String userId) async {
    try {
      // 1. 读取本地数据
      final localStats = await _localStorage.getUserStats(userId) ?? _localStorage.getDefaultStats();
      
      final now = DateTime.now();
      
      // 计算连续天数（基于 lastPracticeDate）
      int newContinuousDays = localStats['continuousDays'] ?? 0;
      final lastPracticeDateStr = localStats['lastPracticeDate'];
      
      if (lastPracticeDateStr != null) {
        final lastPracticeDate = DateTime.parse(lastPracticeDateStr);
        final daysDiff = now.difference(lastPracticeDate).inDays;
        if (daysDiff == 0) {
          // 同一天，连续天数不变
        } else if (daysDiff == 1) {
          // 连续的下一天，+1
          newContinuousDays = (localStats['continuousDays'] ?? 0) + 1;
        } else {
          // 中断了，重置为1
          newContinuousDays = 1;
        }
      } else {
        // 第一次练习
        newContinuousDays = 1;
      }

      // 2. 更新本地数据
      await _localStorage.updateUserStatFields(userId, {
        'totalPracticeSessions': (localStats['totalPracticeSessions'] ?? 0) + 1,
        'lastPracticeDate': now.toIso8601String(),
        'continuousDays': newContinuousDays,
        'statsUpdatedAt': now.toIso8601String(),
      });

      // 3. 同步到云端
      final updatedStats = await _localStorage.getUserStats(userId);
      if (updatedStats != null) {
        await _updateCloudStats(userId, updatedStats);
      }
      
      print('✅ 已更新练习统计: totalSessions=${(localStats['totalPracticeSessions'] ?? 0) + 1}, continuousDays=$newContinuousDays');
    } catch (e) {
      print('⚠️ 更新练习统计失败: $e');
    }
  }

  /// 增量更新：完成练习时调用
  /// 同时更新本地和云端的 completedSessions
  Future<void> incrementCompletedSession(String userId) async {
    try {
      // 1. 读取本地数据
      final localStats = await _localStorage.getUserStats(userId) ?? _localStorage.getDefaultStats();
      
      // 2. 更新本地数据
      await _localStorage.updateUserStatFields(userId, {
        'completedSessions': (localStats['completedSessions'] ?? 0) + 1,
        'statsUpdatedAt': DateTime.now().toIso8601String(),
      });

      // 3. 同步到云端
      final updatedStats = await _localStorage.getUserStats(userId);
      if (updatedStats != null) {
        await _updateCloudStats(userId, updatedStats);
      }
      
      print('✅ 已更新完成统计: completedSessions=${(localStats['completedSessions'] ?? 0) + 1}');
    } catch (e) {
      print('⚠️ 更新完成统计失败: $e');
    }
  }

  /// 每周一重置本周错题数
  /// 可以在应用启动时或用户打开主页时检查并调用
  Future<void> resetWeeklyStatsIfNeeded(String userId) async {
    try {
      // 1. 读取本地数据
      final localStats = await _localStorage.getUserStats(userId);
      if (localStats == null) return;

      final now = DateTime.now();
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      
      // 如果 statsUpdatedAt 是上周或更早，重置 weekMistakes
      final statsUpdatedAtStr = localStats['statsUpdatedAt'];
      final statsUpdatedAt = statsUpdatedAtStr != null ? DateTime.parse(statsUpdatedAtStr) : null;
      
      if (statsUpdatedAt == null || statsUpdatedAt.isBefore(weekStart)) {
        // 2. 更新本地数据
        await _localStorage.updateUserStatFields(userId, {
          'weekMistakes': 0,
          'statsUpdatedAt': now.toIso8601String(),
        });

        // 3. 同步到云端
        final updatedStats = await _localStorage.getUserStats(userId);
        if (updatedStats != null) {
          await _updateCloudStats(userId, updatedStats);
        }
        
        print('🔄 已重置本周统计');
      }
    } catch (e) {
      print('⚠️ 重置周统计失败: $e');
    }
  }

  /// 强制刷新统计数据（手动触发）
  /// 从云端重新计算并同步到本地
  Future<void> forceRefreshStats(String userId) async {
    print('🔄 开始强制刷新统计数据...');
    await syncFromCloud(userId);
    print('✅ 统计数据强制刷新完成');
  }
}
