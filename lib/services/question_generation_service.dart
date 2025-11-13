import 'dart:async';
import 'package:appwrite/appwrite.dart';
import '../config/api_config.dart';
import '../models/question_generation_task.dart';
import '../models/user_profile.dart';

/// 题目生成任务服务
class QuestionGenerationService {
  static final QuestionGenerationService _instance = QuestionGenerationService._internal();
  factory QuestionGenerationService() => _instance;
  QuestionGenerationService._internal();

  late Client _client;
  late Databases _databases;
  Realtime? _realtime;
  RealtimeSubscription? _currentSubscription;
  StreamSubscription<dynamic>? _streamSubscription;

  /// 初始化客户端
  void initialize(Client client) {
    _client = client;
    _databases = Databases(_client);
    _realtime = Realtime(_client);
  }

  /// 创建题目生成任务
  /// [userProfile] 用户档案，用于权限检查
  Future<QuestionGenerationTask> createTask({
    required String userId,
    required List<String> sourceQuestionIds,
    int variantsPerQuestion = 1, // 默认每题生成1道变式
    UserProfile? userProfile,
  }) async {
    try {
      // 🔒 权限检查：变式题生成仅限会员
      if (userProfile != null) {
        final subscriptionStatus = userProfile.subscriptionStatus ?? 'free';
        final isPremium = subscriptionStatus == 'active' &&
            userProfile.subscriptionExpiryDate != null &&
            userProfile.subscriptionExpiryDate!.isAfter(DateTime.now().toUtc());

        if (!isPremium) {
          throw Exception('变式题生成功能仅限会员使用，升级会员即可无限生成变式题');
        }
      }

      final totalCount = sourceQuestionIds.length * variantsPerQuestion;

      final response = await _databases.createDocument(
        databaseId: ApiConfig.databaseId,
        collectionId: 'question_generation_tasks',
        documentId: ID.unique(),
        data: {
          'userId': userId,
          'type': 'variant',
          'status': 'pending',
          'sourceQuestionIds': sourceQuestionIds,
          'variantsPerQuestion': variantsPerQuestion,
          'totalCount': totalCount,
          'completedCount': 0,
        },
      );

      return QuestionGenerationTask.fromJson({
        '\$id': response.$id,
        'createdAt': response.$createdAt,
        'updatedAt': response.$updatedAt,
        ...response.data,
      });
    } catch (e) {
      print('创建题目生成任务失败: $e');
      rethrow;
    }
  }

  /// 获取任务详情
  Future<QuestionGenerationTask?> getTask(String taskId) async {
    try {
      final response = await _databases.getDocument(
        databaseId: ApiConfig.databaseId,
        collectionId: 'question_generation_tasks',
        documentId: taskId,
      );

      return QuestionGenerationTask.fromJson({
        '\$id': response.$id,
        'createdAt': response.$createdAt,
        'updatedAt': response.$updatedAt,
        ...response.data,
      });
    } catch (e) {
      print('获取任务详情失败: $e');
      return null;
    }
  }

  /// 监听任务进度
  Stream<QuestionGenerationTask> watchTask(String taskId) {
    final controller = StreamController<QuestionGenerationTask>.broadcast();

    if (_realtime == null) {
      // 如果 realtime 未初始化，只返回一次当前状态
      getTask(taskId).then((task) {
        if (task != null) {
          controller.add(task);
        }
      });
      return controller.stream;
    }

    // 取消之前的订阅和监听器
    _streamSubscription?.cancel();
    _streamSubscription = null;
    _currentSubscription?.close();
    _currentSubscription = null;

    final subscription = _realtime!.subscribe([
      'databases.${ApiConfig.databaseId}.collections.question_generation_tasks.documents.$taskId'
    ]);

    // 保存订阅引用
    _currentSubscription = subscription;

    // 保存 stream subscription 引用以便后续取消
    _streamSubscription = subscription.stream.listen((event) {
      try {
        // Appwrite Realtime 事件结构
        if (event.events.isNotEmpty && event.events.any((e) => e.toString().contains('.update'))) {
          // payload 是 Map<String, dynamic>
          final payload = event.payload as Map<String, dynamic>?;
          
          if (payload != null) {
            try {
              final task = QuestionGenerationTask.fromJson({
                '\$id': payload['\$id'],
                'createdAt': payload['\$createdAt'],
                'updatedAt': payload['\$updatedAt'],
                ...payload,
              });
              controller.add(task);
            } catch (e) {
              print('解析任务数据失败: $e');
            }
          }
        }
      } catch (e) {
        print('处理 Realtime 事件失败: $e');
      }
    });

    // 立即获取一次当前状态
    getTask(taskId).then((task) {
      if (task != null) {
        controller.add(task);
      }
    });

    return controller.stream;
  }

  /// 取消监听并关闭 realtime 连接
  void cancelWatch() {
    // 先取消 stream subscription
    _streamSubscription?.cancel();
    _streamSubscription = null;
    
    // 然后关闭 realtime subscription
    _currentSubscription?.close();
    _currentSubscription = null;
    
    print('已关闭 Realtime 订阅');
  }

  /// 取消监听
  void dispose() {
    cancelWatch();
  }

  /// 获取用户的任务历史列表
  Future<List<QuestionGenerationTask>> getTaskHistory({
    required String userId,
    int limit = 50,
  }) async {
    try {
      final response = await _databases.listDocuments(
        databaseId: ApiConfig.databaseId,
        collectionId: 'question_generation_tasks',
        queries: [
          Query.equal('userId', userId),
          Query.orderDesc('\$createdAt'),
          Query.limit(limit),
        ],
      );

      return response.documents
          .map((doc) => QuestionGenerationTask.fromJson({
                '\$id': doc.$id,
                'createdAt': doc.$createdAt,
                'updatedAt': doc.$updatedAt,
                ...doc.data,
              }))
          .toList();
    } catch (e) {
      print('获取任务历史失败: $e');
      return [];
    }
  }
}

