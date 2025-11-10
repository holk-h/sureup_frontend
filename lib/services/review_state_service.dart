import 'package:appwrite/appwrite.dart';
import '../config/api_config.dart';
import '../models/review_state.dart';

/// 复习状态服务 - 处理知识点复习状态的更新
class ReviewStateService {
  static final ReviewStateService _instance = ReviewStateService._internal();
  factory ReviewStateService() => _instance;
  ReviewStateService._internal();

  late Client _client;
  late Databases _databases;

  /// 初始化客户端
  void initialize(Client client) {
    _client = client;
    _databases = Databases(_client);
  }

  /// 获取知识点的复习状态
  Future<ReviewState?> getReviewState(String userId, String knowledgePointId) async {
    try {
      final response = await _databases.listDocuments(
        databaseId: ApiConfig.databaseId,
        collectionId: ApiConfig.reviewStatesCollectionId,
        queries: [
          Query.equal('userId', userId),
          Query.equal('knowledgePointId', knowledgePointId),
          Query.limit(1),
        ],
      );

      if (response.documents.isEmpty) {
        return null;
      }

      final doc = response.documents.first;
      return ReviewState.fromJson({
        'id': doc.$id,
        'createdAt': doc.$createdAt,
        'updatedAt': doc.$updatedAt,
        ...doc.data,
      });
    } catch (e) {
      print('获取复习状态失败: $e');
      return null;
    }
  }

  /// 更新复习状态（根据用户反馈）
  /// 
  /// [feedback] 用户的反馈选项，例如：
  /// - newLearning: "完全看懂了", "大致理解了", "还是不太懂"
  /// - reviewing: "一看就会了", "想了会儿才懂", "完全想不起来"
  /// - mastered: "做对了", "做错了但看懂了", "还是不太会"
  /// 
  /// 前端直接计算并更新数据库
  Future<ReviewState> updateReviewState({
    required String userId,
    required String knowledgePointId,
    required ReviewStatus currentStatus,
    required int currentMasteryScore,
    required int currentInterval,
    required int consecutiveCorrect,
    required String feedback,
  }) async {
    try {
      // 1. 获取或创建 ReviewState
      ReviewState? reviewState = await getReviewState(userId, knowledgePointId);
      
      // 2. 计算更新参数
      final updates = _calculateUpdates(currentStatus, feedback);
      final masteryChange = updates['masteryChange'] as int;
      final intervalMultiplier = updates['intervalMultiplier'] as double;
      final resetConsecutive = updates['resetConsecutive'] as bool;
      final isCorrect = updates['isCorrect'] as bool;
      
      // 3. 计算新的掌握度（0-100之间）
      int newMasteryScore = (currentMasteryScore + masteryChange).clamp(0, 100);
      
      // 4. 计算新的连续答对次数（只有真正"答对"才+1）
      int newConsecutiveCorrect = resetConsecutive ? 0 : (isCorrect ? consecutiveCorrect + 1 : consecutiveCorrect);
      
      // 5. 计算新的间隔
      int newInterval = _calculateNewInterval(
        currentStatus: currentStatus,
        currentInterval: currentInterval,
        intervalMultiplier: intervalMultiplier,
      );
      
      // 6. 判断状态转换
      ReviewStatus newStatus = _determineNewStatus(
        currentStatus: currentStatus,
        newMasteryScore: newMasteryScore,
        consecutiveCorrect: newConsecutiveCorrect,
      );
      
      // 7. 计算下次复习时间
      DateTime nextReviewDate = DateTime.now().add(Duration(days: newInterval));
      
      // 8. 准备更新数据
      final now = DateTime.now();
      
      // 统计正确/错误次数
      final currentTotalCorrect = reviewState?.totalCorrect ?? 0;
      final currentTotalWrong = reviewState?.totalWrong ?? 0;
      final newTotalCorrect = isCorrect ? currentTotalCorrect + 1 : currentTotalCorrect;
      final newTotalWrong = resetConsecutive ? currentTotalWrong + 1 : currentTotalWrong;
      
      final data = {
        'masteryScore': newMasteryScore,
        'currentInterval': newInterval,
        'nextReviewDate': nextReviewDate.toIso8601String(),
        'lastReviewDate': now.toIso8601String(),
        'status': newStatus.name,
        'consecutiveCorrect': newConsecutiveCorrect,
        'totalReviews': (reviewState?.totalReviews ?? 0) + 1,
        'totalCorrect': newTotalCorrect,
        'totalWrong': newTotalWrong,
      };
      
      // 9. 更新或创建文档
      if (reviewState != null) {
        // 更新现有文档
        await _databases.updateDocument(
          databaseId: ApiConfig.databaseId,
          collectionId: ApiConfig.reviewStatesCollectionId,
          documentId: reviewState.id,
          data: data,
        );
        
        print('✅ 复习状态已更新:');
        print('   掌握度: $currentMasteryScore → $newMasteryScore (${masteryChange > 0 ? '+' : ''}$masteryChange)');
        print('   状态: ${currentStatus.displayName} → ${newStatus.displayName}');
        print('   连续答对: $consecutiveCorrect → $newConsecutiveCorrect');
        print('   正确率: $newTotalCorrect/${newTotalCorrect + newTotalWrong}');
        print('   间隔: $currentInterval → $newInterval 天');
        print('   下次复习: ${nextReviewDate.toString().split(' ')[0]}');
        
        return reviewState.copyWith(
          masteryScore: newMasteryScore,
          currentInterval: newInterval,
          nextReviewDate: nextReviewDate,
          lastReviewDate: now,
          status: newStatus,
          consecutiveCorrect: newConsecutiveCorrect,
          totalReviews: reviewState.totalReviews + 1,
          totalCorrect: newTotalCorrect,
          totalWrong: newTotalWrong,
          updatedAt: now,
        );
      } else {
        // 创建新文档
        final doc = await _databases.createDocument(
          databaseId: ApiConfig.databaseId,
          collectionId: ApiConfig.reviewStatesCollectionId,
          documentId: ID.unique(),
          data: {
            'userId': userId,
            'knowledgePointId': knowledgePointId,
            'isActive': true,
            'totalCorrect': 0,
            'totalWrong': 0,
            ...data,
          },
        );
        
        print('✅ 创建新的复习状态:');
        print('   掌握度: $newMasteryScore');
        print('   状态: ${newStatus.displayName}');
        print('   间隔: $newInterval 天');
        
        return ReviewState.fromJson({
          'id': doc.$id,
          'createdAt': doc.$createdAt,
          'updatedAt': doc.$updatedAt,
          ...doc.data,
        });
      }
    } catch (e) {
      print('❌ 更新复习状态失败: $e');
      rethrow;
    }
  }

  /// 根据当前状态和用户反馈计算掌握度变化和间隔调整
  Map<String, dynamic> _calculateUpdates(ReviewStatus status, String feedback) {
    int masteryChange = 0;
    double intervalMultiplier = 1.0;
    bool resetConsecutive = false;
    bool isCorrect = false; // 是否算作"答对"

    switch (status) {
      case ReviewStatus.newLearning:
        switch (feedback) {
          case '完全看懂了':
            masteryChange = 40; // 提高增量，加快进度
            intervalMultiplier = 2.0; // 1天 -> 2天
            isCorrect = true;
            break;
          case '大致理解了':
            masteryChange = 25; // 提高增量
            intervalMultiplier = 1.5; // 1天 -> 1-2天
            isCorrect = true;
            break;
          case '还是不太懂':
            masteryChange = 10; // 稍微提高一点
            intervalMultiplier = 1.0; // 保持1天
            resetConsecutive = true;
            break;
        }
        break;

      case ReviewStatus.reviewing:
        switch (feedback) {
          case '一看就会了':
            masteryChange = 30; // 提高增量
            intervalMultiplier = 2.0;
            isCorrect = true;
            break;
          case '想了会儿才懂':
            masteryChange = 15; // 提高增量
            intervalMultiplier = 1.3;
            isCorrect = true;
            break;
          case '完全想不起来':
            masteryChange = -15; // 降得更多
            intervalMultiplier = 0.0; // 重置为3天
            resetConsecutive = true;
            break;
        }
        break;

      case ReviewStatus.mastered:
        switch (feedback) {
          case '做对了':
            masteryChange = 5; // 保持即可
            intervalMultiplier = 2.0; // 30天 -> 60天 -> 90天
            isCorrect = true;
            break;
          case '做错了但看懂了':
            masteryChange = -10;
            intervalMultiplier = 0.5; // 缩短间隔
            resetConsecutive = true;
            break;
          case '还是不太会':
            masteryChange = -30; // 降得更多
            intervalMultiplier = 0.0; // 重置为3天，可能降级
            resetConsecutive = true;
            break;
        }
        break;
    }

    return {
      'masteryChange': masteryChange,
      'intervalMultiplier': intervalMultiplier,
      'resetConsecutive': resetConsecutive,
      'isCorrect': isCorrect,
    };
  }

  /// 计算新的间隔（天数）
  int _calculateNewInterval({
    required ReviewStatus currentStatus,
    required int currentInterval,
    required double intervalMultiplier,
  }) {
    if (intervalMultiplier == 0.0) {
      // 重置间隔
      switch (currentStatus) {
        case ReviewStatus.newLearning:
          return 1; // 重置为1天
        case ReviewStatus.reviewing:
          return 3; // 重置为3天
        case ReviewStatus.mastered:
          return 3; // 降级，重置为3天
      }
    }

    // 应用倍数
    int newInterval = (currentInterval * intervalMultiplier).round();

    // 根据不同状态限制间隔范围
    switch (currentStatus) {
      case ReviewStatus.newLearning:
        return newInterval.clamp(1, 3); // 1-3天
      case ReviewStatus.reviewing:
        return newInterval.clamp(3, 30); // 3-30天
      case ReviewStatus.mastered:
        return newInterval.clamp(30, 90); // 30-90天
    }
  }

  /// 判断状态转换
  /// 
  /// 新逻辑（更合理）：
  /// - newLearning → reviewing：完成第一次复习且掌握度 ≥ 40%
  /// - reviewing → mastered：连续答对 ≥ 2次 且掌握度 ≥ 70%
  /// - 降级：掌握度过低时降级
  ReviewStatus _determineNewStatus({
    required ReviewStatus currentStatus,
    required int newMasteryScore,
    required int consecutiveCorrect,
  }) {
    switch (currentStatus) {
      case ReviewStatus.newLearning:
        // 只要掌握度达到40%就进入复习阶段（更容易进入）
        if (newMasteryScore >= 40) {
          return ReviewStatus.reviewing;
        }
        return ReviewStatus.newLearning;

      case ReviewStatus.reviewing:
        // 连续答对2次且掌握度≥70%就可以掌握（大幅降低要求）
        if (consecutiveCorrect >= 2 && newMasteryScore >= 70) {
          return ReviewStatus.mastered;
        }
        // 掌握度低于40%降级到新学习
        if (newMasteryScore < 40) {
          return ReviewStatus.newLearning;
        }
        return ReviewStatus.reviewing;

      case ReviewStatus.mastered:
        // 掌握度低于60%降级到复习中
        if (newMasteryScore < 60) {
          return ReviewStatus.reviewing;
        }
        return ReviewStatus.mastered;
    }
  }

  /// 批量更新多个知识点的复习状态
  Future<List<ReviewState>> batchUpdateReviewStates({
    required String userId,
    required List<Map<String, dynamic>> feedbackList,
  }) async {
    try {
      // 并行更新所有知识点
      final futures = feedbackList.map((item) {
        return updateReviewState(
          userId: userId,
          knowledgePointId: item['knowledgePointId'] as String,
          currentStatus: item['status'] as ReviewStatus,
          currentMasteryScore: item['masteryScore'] as int,
          currentInterval: item['interval'] as int,
          consecutiveCorrect: item['consecutiveCorrect'] as int,
          feedback: item['feedback'] as String,
        );
      }).toList();

      final results = await Future.wait(futures);
      print('✅ 批量更新复习状态成功: ${feedbackList.length} 个知识点');
      return results;
    } catch (e) {
      print('❌ 批量更新复习状态失败: $e');
      rethrow;
    }
  }
}

