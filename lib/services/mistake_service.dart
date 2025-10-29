import 'package:appwrite/appwrite.dart';
import '../config/api_config.dart';
import '../models/models.dart';

/// 错题服务 - 处理错题相关的业务逻辑
class MistakeService {
  static final MistakeService _instance = MistakeService._internal();
  factory MistakeService() => _instance;
  MistakeService._internal();

  late Client _client;
  late Databases _databases;
  
  /// 初始化客户端
  void initialize(Client client) {
    _client = client;
    _databases = Databases(_client);
  }

  /// 获取用户的所有错题记录
  Future<List<MistakeRecord>> getUserMistakes(String userId) async {
    try {
      final response = await _databases.listDocuments(
        databaseId: ApiConfig.databaseId,
        collectionId: ApiConfig.mistakeRecordsCollectionId,
        queries: [
          Query.equal('userId', userId),
          Query.orderDesc('\$createdAt'),  // 使用系统字段 $createdAt
          Query.limit(100),
        ],
      );

      return response.documents
          .map((doc) => MistakeRecord.fromJson({
                'id': doc.$id,
                'createdAt': doc.$createdAt,
                'updatedAt': doc.$updatedAt,
                ...doc.data,
              }))
          .toList();
    } catch (e) {
      print('获取错题记录失败: $e');
      return [];
    }
  }

  /// 获取待复盘的错题（未掌握的）
  Future<List<MistakeRecord>> getUnmasteredMistakes(String userId) async {
    try {
      final response = await _databases.listDocuments(
        databaseId: ApiConfig.databaseId,
        collectionId: ApiConfig.mistakeRecordsCollectionId,
        queries: [
          Query.equal('userId', userId),
          Query.notEqual('masteryStatus', 'mastered'),
          Query.orderDesc('\$createdAt'),  // 使用系统字段 $createdAt
          Query.limit(100),
        ],
      );

      return response.documents
          .map((doc) => MistakeRecord.fromJson({
                'id': doc.$id,
                'createdAt': doc.$createdAt,
                'updatedAt': doc.$updatedAt,
                ...doc.data,
              }))
          .toList();
    } catch (e) {
      print('获取待复盘错题失败: $e');
      return [];
    }
  }

  /// 计算积累的错题数量和距离上次复盘的天数
  Future<Map<String, int>> getAccumulationStats(String userId) async {
    try {
      // 获取所有错题
      final mistakes = await getUserMistakes(userId);
      
      // 计算积累的错题数（未掌握的）
      final accumulatedMistakes = mistakes
          .where((m) => m.masteryStatus != MasteryStatus.mastered)
          .length;
      
      // 计算距离上次复盘的天数
      int daysSinceLastReview = 0;
      if (mistakes.isNotEmpty) {
        final lastReview = mistakes
            .where((m) => m.lastReviewAt != null)
            .map((m) => m.lastReviewAt!)
            .fold<DateTime?>(null, (prev, curr) {
              if (prev == null) return curr;
              return curr.isAfter(prev) ? curr : prev;
            });
        
        if (lastReview != null) {
          daysSinceLastReview = DateTime.now().difference(lastReview).inDays;
        }
      }
      
      return {
        'accumulatedMistakes': accumulatedMistakes,
        'daysSinceLastReview': daysSinceLastReview,
      };
    } catch (e) {
      print('获取积累统计失败: $e');
      return {
        'accumulatedMistakes': 0,
        'daysSinceLastReview': 0,
      };
    }
  }
}

