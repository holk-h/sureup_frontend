import 'dart:convert';
import 'package:appwrite/appwrite.dart';
import '../config/api_config.dart';
import '../models/daily_task.dart';
import 'auth_service.dart';

/// 每日任务服务
class DailyTaskService {
  static final DailyTaskService _instance = DailyTaskService._internal();
  factory DailyTaskService() => _instance;
  DailyTaskService._internal();

  late Databases _databases;
  final AuthService _authService = AuthService();

  /// 初始化
  void initialize(Client client) {
    _databases = Databases(client);
  }

  /// 获取今日任务
  Future<DailyTask?> getTodayTask() async {
    final userId = _authService.userId;
    if (userId == null) throw Exception('用户未登录');

    final now = DateTime.now();
    // 今天的开始时间（本地时区 00:00:00）
    final todayStart = DateTime(now.year, now.month, now.day);
    // 今天的结束时间（本地时区 23:59:59）
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

    try {
      final response = await _databases.listDocuments(
        databaseId: ApiConfig.databaseId,
        collectionId: 'daily_tasks',
        queries: [
          Query.equal('userId', userId),
          Query.greaterThanEqual('taskDate', todayStart.toIso8601String()),
          Query.lessThanEqual('taskDate', todayEnd.toIso8601String()),
          Query.limit(1),
        ],
      );

      if (response.documents.isEmpty) return null;

      final doc = response.documents.first;
      return DailyTask.fromJson(doc.data);
    } catch (e) {
      print('获取今日任务失败: $e');
      rethrow;
    }
  }

  /// 获取指定日期的任务
  Future<DailyTask?> getTaskByDate(DateTime date) async {
    final userId = _authService.userId;
    if (userId == null) throw Exception('用户未登录');

    // 指定日期的开始时间（本地时区 00:00:00）
    final dateStart = DateTime(date.year, date.month, date.day);
    // 指定日期的结束时间（本地时区 23:59:59）
    final dateEnd = DateTime(date.year, date.month, date.day, 23, 59, 59);

    try {
      final response = await _databases.listDocuments(
        databaseId: ApiConfig.databaseId,
        collectionId: 'daily_tasks',
        queries: [
          Query.equal('userId', userId),
          Query.greaterThanEqual('taskDate', dateStart.toIso8601String()),
          Query.lessThanEqual('taskDate', dateEnd.toIso8601String()),
          Query.limit(1),
        ],
      );

      if (response.documents.isEmpty) return null;

      final doc = response.documents.first;
      return DailyTask.fromJson(doc.data);
    } catch (e) {
      print('获取任务失败: $e');
      rethrow;
    }
  }

  /// 更新任务进度
  Future<void> updateTaskProgress(
    String taskId,
    List<TaskItem> updatedItems,
  ) async {
    try {
      final completedCount = updatedItems.where((item) => item.isCompleted).length;
      final allCompleted = updatedItems.every((item) => item.isCompleted);

      // 将 items 序列化为 JSON 字符串
      final itemsJson = jsonEncode(
        updatedItems.map((item) => item.toJson()).toList(),
      );

      await _databases.updateDocument(
        databaseId: ApiConfig.databaseId,
        collectionId: 'daily_tasks',
        documentId: taskId,
        data: {
          'items': itemsJson,
          'completedCount': completedCount,
          'isCompleted': allCompleted,
          'completedAt': allCompleted ? DateTime.now().toIso8601String() : null,
        },
      );
    } catch (e) {
      print('更新任务进度失败: $e');
      rethrow;
    }
  }

  /// 完成任务项（知识点）
  Future<void> completeTaskItem({
    required String taskId,
    required String knowledgePointId,
    required List<TaskItem> allItems,
    required int itemIndex,
    required int correctCount,
    required int wrongCount,
  }) async {
    try {
      // 更新当前知识点的完成状态
      final updatedItems = List<TaskItem>.from(allItems);
      updatedItems[itemIndex] = updatedItems[itemIndex].copyWith(
        isCompleted: true,
        correctCount: correctCount,
        wrongCount: wrongCount,
      );

      // 更新任务进度
      await updateTaskProgress(taskId, updatedItems);
    } catch (e) {
      print('完成任务项失败: $e');
      rethrow;
    }
  }

  /// 创建练习记录
  Future<String> createPracticeSession({
    required String taskId,
    required String knowledgePointId,
    required String knowledgePointName,
    required int totalQuestions,
    required int correctQuestions,
    required DateTime startedAt,
    required String userFeedback,
  }) async {
    final userId = _authService.userId;
    if (userId == null) throw Exception('用户未登录');

    try {
      final response = await _databases.createDocument(
        databaseId: ApiConfig.databaseId,
        collectionId: ApiConfig.practiceSessionsCollectionId,
        documentId: 'unique()',
        data: {
          'userId': userId,
          'type': 'daily_task',
          'dailyTaskId': taskId,
          'knowledgePointId': knowledgePointId,
          'title': '每日任务 - $knowledgePointName',
          'totalQuestions': totalQuestions,
          'completedQuestions': totalQuestions,
          'correctQuestions': correctQuestions,
          'startedAt': startedAt.toIso8601String(),
          'completedAt': DateTime.now().toIso8601String(),
          'status': 'completed',
          'userFeedback': userFeedback,
        },
      );

      return response.$id;
    } catch (e) {
      print('创建练习记录失败: $e');
      rethrow;
    }
  }

  /// 获取最近的任务历史
  Future<List<DailyTask>> getRecentTasks({int limit = 7}) async {
    final userId = _authService.userId;
    if (userId == null) throw Exception('用户未登录');

    try {
      final response = await _databases.listDocuments(
        databaseId: ApiConfig.databaseId,
        collectionId: 'daily_tasks',
        queries: [
          Query.equal('userId', userId),
          Query.orderDesc('taskDate'),
          Query.limit(limit),
        ],
      );

      return response.documents
          .map((doc) => DailyTask.fromJson(doc.data))
          .toList();
    } catch (e) {
      print('获取任务历史失败: $e');
      rethrow;
    }
  }

  /// 获取任务统计信息
  Future<Map<String, dynamic>> getTaskStats() async {
    final userId = _authService.userId;
    if (userId == null) throw Exception('用户未登录');

    try {
      // 获取最近30天的任务
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      final response = await _databases.listDocuments(
        databaseId: ApiConfig.databaseId,
        collectionId: 'daily_tasks',
        queries: [
          Query.equal('userId', userId),
          Query.greaterThan('taskDate', thirtyDaysAgo.toIso8601String()),
        ],
      );

      final tasks = response.documents
          .map((doc) => DailyTask.fromJson(doc.data))
          .toList();

      final totalTasks = tasks.length;
      final completedTasks = tasks.where((t) => t.isCompleted).length;
      final totalQuestions = tasks.fold<int>(
        0,
        (sum, task) => sum + task.totalQuestions,
      );
      final completedQuestions = tasks.fold<int>(
        0,
        (sum, task) => sum + task.completedCount,
      );

      return {
        'totalTasks': totalTasks,
        'completedTasks': completedTasks,
        'totalQuestions': totalQuestions,
        'completedQuestions': completedQuestions,
        'completionRate': totalTasks > 0 ? completedTasks / totalTasks : 0.0,
      };
    } catch (e) {
      print('获取任务统计失败: $e');
      rethrow;
    }
  }
}

