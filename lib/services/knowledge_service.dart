import 'package:appwrite/appwrite.dart';
import '../config/api_config.dart';
import '../models/models.dart';

/// 知识点服务 - 处理知识点相关的业务逻辑
class KnowledgeService {
  static final KnowledgeService _instance = KnowledgeService._internal();
  factory KnowledgeService() => _instance;
  KnowledgeService._internal();

  late Client _client;
  late Databases _databases;
  
  /// 初始化客户端
  void initialize(Client client) {
    _client = client;
    _databases = Databases(_client);
  }

  /// 获取用户的所有知识点
  Future<List<KnowledgePoint>> getUserKnowledgePoints(String userId) async {
    try {
      final response = await _databases.listDocuments(
        databaseId: ApiConfig.databaseId,
        collectionId: ApiConfig.knowledgePointsCollectionId,
        queries: [
          Query.equal('userId', userId),
          Query.orderDesc('lastMistakeAt'),
          Query.limit(100),
        ],
      );

      return response.documents
          .map((doc) => KnowledgePoint.fromJson({
                'id': doc.$id,
                'createdAt': doc.$createdAt,
                'updatedAt': doc.$updatedAt,
                ...doc.data,
              }))
          .toList();
    } catch (e) {
      print('获取知识点失败: $e');
      return [];
    }
  }

  /// 获取某个学科下的所有模块（从 knowledge_points_library）
  Future<List<Module>> getSubjectModules(String userId, Subject subject) async {
    try {
      // 1. 获取该学科的所有模块（从公共库）
      // 注意：数据库中 subject 字段存储的是中文名称（如"数学"）
      final modulesResponse = await _databases.listDocuments(
        databaseId: ApiConfig.databaseId,
        collectionId: ApiConfig.knowledgePointsLibraryCollectionId,
        queries: [
          Query.equal('subject', subject.displayName), // 使用中文名称
          Query.equal('isActive', true),
          Query.orderAsc('order'),
          Query.limit(100),
        ],
      );

      // 2. 获取用户在该学科下的所有知识点
      final userKnowledgePoints = await getUserKnowledgePoints(userId);
      final subjectKnowledgePoints = userKnowledgePoints
          .where((kp) => kp.subject == subject)
          .toList();

      // 3. 为每个模块统计知识点数量和错题数
      final modules = <Module>[];
      for (final doc in modulesResponse.documents) {
        final moduleId = doc.$id;
        
        // 找到该模块下的所有知识点
        final moduleKnowledgePoints = subjectKnowledgePoints
            .where((kp) => kp.moduleId == moduleId)
            .toList();
        
        // 计算统计数据
        // 使用 Set 去重，因为同一道题可能关联多个知识点
        final allQuestionIds = <String>{};
        for (final kp in moduleKnowledgePoints) {
          allQuestionIds.addAll(kp.questionIds);
        }
        final mistakeCount = allQuestionIds.length; // 错题数 = 去重后的题目数
        final knowledgePointCount = moduleKnowledgePoints.length;

        modules.add(Module.fromJson({
          'id': doc.$id,
          'createdAt': doc.$createdAt,
          'updatedAt': doc.$updatedAt,
          ...doc.data,
          'mistakeCount': mistakeCount,
          'knowledgePointCount': knowledgePointCount,
        }));
      }

      return modules;
    } catch (e) {
      print('获取模块失败: $e');
      return [];
    }
  }

  /// 获取某个模块下的所有知识点
  Future<List<KnowledgePoint>> getModuleKnowledgePoints(
    String userId,
    String moduleId,
  ) async {
    try {
      final response = await _databases.listDocuments(
        databaseId: ApiConfig.databaseId,
        collectionId: ApiConfig.knowledgePointsCollectionId,
        queries: [
          Query.equal('userId', userId),
          Query.equal('moduleId', moduleId),
          Query.orderDesc('lastMistakeAt'),
          Query.limit(100),
        ],
      );

      return response.documents
          .map((doc) => KnowledgePoint.fromJson({
                'id': doc.$id,
                'createdAt': doc.$createdAt,
                'updatedAt': doc.$updatedAt,
                ...doc.data,
              }))
          .toList();
    } catch (e) {
      print('获取模块知识点失败: $e');
      return [];
    }
  }

  /// 按学科分组知识点
  Map<String, List<KnowledgePoint>> groupBySubject(List<KnowledgePoint> points) {
    final Map<String, List<KnowledgePoint>> groups = {};
    
    for (final point in points) {
      // 获取学科名称
      final subjectName = point.subject.displayName;
      
      if (!groups.containsKey(subjectName)) {
        groups[subjectName] = [];
      }
      groups[subjectName]!.add(point);
    }
    
    return groups;
  }

  /// 只保留用户关注的学科
  Map<String, List<KnowledgePoint>> filterFocusSubjects(
    Map<String, List<KnowledgePoint>> allGroups,
    List<String> focusSubjects,
  ) {
    if (focusSubjects.isEmpty) {
      return {}; // 如果没有关注学科，返回空
    }
    
    final Map<String, List<KnowledgePoint>> filtered = {};
    
    for (final subjectId in focusSubjects) {
      // 将学科ID转换为中文名称
      final subject = Subject.fromString(subjectId);
      final displayName = subject?.displayName ?? subjectId;
      
      // 如果这个学科有数据，添加到结果中
      if (allGroups.containsKey(displayName)) {
        filtered[displayName] = allGroups[displayName]!;
      }
    }
    
    return filtered;
  }

  /// 获取过滤后的知识点列表
  List<KnowledgePoint> getFilteredPoints(
    List<KnowledgePoint> allPoints,
    List<String> focusSubjects,
  ) {
    if (focusSubjects.isEmpty) {
      return [];
    }
    
    return allPoints.where((point) {
      final subjectName = point.subject.displayName;
      
      // 检查这个知识点的学科是否在关注列表中
      return focusSubjects.any((subjectId) {
        final subject = Subject.fromString(subjectId);
        return subject?.displayName == subjectName;
      });
    }).toList();
  }

  /// 计算整体统计数据
  Map<String, dynamic> calculateStats(List<KnowledgePoint> points) {
    if (points.isEmpty) {
      return {
        'totalPoints': 0,
        'weakPoints': 0,
        'totalMistakes': 0,
        'avgMastery': 0,
      };
    }

    final totalMistakes = points.fold<int>(0, (sum, p) => sum + p.mistakeCount);
    final avgMastery = points.fold<int>(0, (sum, p) => sum + p.masteryLevel) ~/ points.length;
    final weakPoints = points.where((p) => p.masteryLevel < 60).length;

    return {
      'totalPoints': points.length,
      'weakPoints': weakPoints,
      'totalMistakes': totalMistakes,
      'avgMastery': avgMastery,
    };
  }

  /// 计算学科统计数据
  Map<String, dynamic> calculateSubjectStats(List<KnowledgePoint> points) {
    if (points.isEmpty) {
      return {
        'totalMistakes': 0,
        'weakPoints': 0,
        'avgMastery': 0,
      };
    }

    final totalMistakes = points.fold<int>(0, (sum, p) => sum + p.mistakeCount);
    final avgMastery = points.fold<int>(0, (sum, p) => sum + p.masteryLevel) ~/ points.length;
    final weakPoints = points.where((p) => p.masteryLevel < 60).length;

    return {
      'totalMistakes': totalMistakes,
      'weakPoints': weakPoints,
      'avgMastery': avgMastery,
    };
  }
}

