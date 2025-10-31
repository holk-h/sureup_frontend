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
  late Storage _storage;
  late Realtime _realtime;
  
  /// 初始化客户端
  void initialize(Client client) {
    _client = client;
    _databases = Databases(_client);
    _storage = Storage(_client);
    _realtime = Realtime(_client);
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

  /// 上传错题图片到存储桶
  Future<String> uploadMistakeImage(String filePath) async {
    try {
      final fileName = 'mistake_${DateTime.now().millisecondsSinceEpoch}.jpg';
      
      final result = await _storage.createFile(
        bucketId: ApiConfig.originQuestionImageBucketId,
        fileId: ID.unique(),
        file: InputFile.fromPath(
          path: filePath,
          filename: fileName,
        ),
      );
      
      return result.$id;
    } catch (e) {
      print('上传图片失败: $e');
      rethrow;
    }
  }

  /// 批量上传错题图片
  Future<List<String>> uploadMistakeImages(List<String> filePaths) async {
    final fileIds = <String>[];
    
    for (final path in filePaths) {
      try {
        final fileId = await uploadMistakeImage(path);
        fileIds.add(fileId);
      } catch (e) {
        print('上传图片失败 ($path): $e');
        // 如果部分图片上传失败，继续上传其他图片
      }
    }
    
    return fileIds;
  }

  /// 创建错题记录（拍照录入）
  /// 返回创建的错题记录 ID
  Future<String> createMistakeFromPhotos({
    required String userId,
    required Subject subject,
    required List<String> photoFilePaths,
    String? note,
  }) async {
    try {
      // 1. 上传图片到存储桶
      print('开始上传 ${photoFilePaths.length} 张图片...');
      final fileIds = await uploadMistakeImages(photoFilePaths);
      
      if (fileIds.isEmpty) {
        throw Exception('所有图片上传失败');
      }
      
      print('成功上传 ${fileIds.length} 张图片');
      
      // 2. 创建错题记录
      final data = {
        'userId': userId,
        'questionId': null, // 拍照录入时暂无题目ID，等待AI分析后填充
        'subject': subject.name,
        'originalImageUrls': fileIds,
        'analysisStatus': 'pending', // 等待 AI 分析
        'masteryStatus': 'notStarted',
        'reviewCount': 0,
        'correctCount': 0,
        'moduleIds': [], // 空数组，等待AI分析后填充
        'knowledgePointIds': [], // 空数组，等待AI分析后填充
        if (note != null) 'note': note,
      };
      
      final document = await _databases.createDocument(
        databaseId: ApiConfig.databaseId,
        collectionId: ApiConfig.mistakeRecordsCollectionId,
        documentId: ID.unique(),
        data: data,
      );
      
      print('创建错题记录成功: ${document.$id}');
      return document.$id;
    } catch (e) {
      print('创建错题记录失败: $e');
      rethrow;
    }
  }

  /// 订阅错题记录的更新（监听 AI 分析进度）
  RealtimeSubscription subscribeMistakeAnalysis({
    required String mistakeRecordId,
    required void Function(MistakeRecord record) onUpdate,
    void Function(dynamic error)? onError,
  }) {
    final subscription = _realtime.subscribe([
      'databases.${ApiConfig.databaseId}.collections.${ApiConfig.mistakeRecordsCollectionId}.documents.$mistakeRecordId'
    ]);

    subscription.stream.listen(
      (event) {
        if (event.events.any((e) => e.endsWith('update'))) {
          try {
            final record = MistakeRecord.fromJson({
              'id': event.payload['\$id'],
              'createdAt': event.payload['\$createdAt'],
              ...event.payload,
            });
            onUpdate(record);
          } catch (e) {
            print('解析错题记录更新失败: $e');
            onError?.call(e);
          }
        }
      },
      onError: (error) {
        print('Realtime 订阅错误: $error');
        onError?.call(error);
      },
    );

    return subscription;
  }

  /// 获取单个错题记录
  Future<MistakeRecord?> getMistakeRecord(String recordId) async {
    try {
      final document = await _databases.getDocument(
        databaseId: ApiConfig.databaseId,
        collectionId: ApiConfig.mistakeRecordsCollectionId,
        documentId: recordId,
      );

      return MistakeRecord.fromJson({
        'id': document.$id,
        'createdAt': document.$createdAt,
        ...document.data,
      });
    } catch (e) {
      print('获取错题记录失败: $e');
      return null;
    }
  }

  /// 重新分析错题（更新状态为 pending）
  Future<void> reanalyzeMistake(String recordId) async {
    try {
      await _databases.updateDocument(
        databaseId: ApiConfig.databaseId,
        collectionId: ApiConfig.mistakeRecordsCollectionId,
        documentId: recordId,
        data: {
          'analysisStatus': 'pending',
          'analysisError': null,
        },
      );
      print('触发重新分析: $recordId');
    } catch (e) {
      print('触发重新分析失败: $e');
      rethrow;
    }
  }

  /// 更新错题记录备注
  Future<void> updateMistakeNote(String recordId, String note) async {
    try {
      await _databases.updateDocument(
        databaseId: ApiConfig.databaseId,
        collectionId: ApiConfig.mistakeRecordsCollectionId,
        documentId: recordId,
        data: {'note': note},
      );
    } catch (e) {
      print('更新备注失败: $e');
      rethrow;
    }
  }

  /// 删除错题记录
  Future<void> deleteMistake(String recordId) async {
    try {
      await _databases.deleteDocument(
        databaseId: ApiConfig.databaseId,
        collectionId: ApiConfig.mistakeRecordsCollectionId,
        documentId: recordId,
      );
      print('删除错题记录成功: $recordId');
    } catch (e) {
      print('删除错题记录失败: $e');
      rethrow;
    }
  }
}

