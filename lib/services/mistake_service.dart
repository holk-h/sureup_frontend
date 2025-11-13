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

  // Caches
  final Map<String, MistakeRecord> _mistakeRecordCache = {};
  final Map<String, Question> _questionCache = {};
  final Map<String, Map<String, String>> _moduleCache = {};
  final Map<String, Map<String, String>> _knowledgePointCache = {};

  /// 清空所有缓存
  void clearCache() {
    _mistakeRecordCache.clear();
    _questionCache.clear();
    _moduleCache.clear();
    _knowledgePointCache.clear();
  }
  
  /// 清除单个题目的缓存
  void clearQuestionCache(String questionId) {
    _questionCache.remove(questionId);
  }
  
  /// 预加载错题数据（包括题目、模块、知识点）到缓存
  Future<void> preloadMistakeRecordData(List<String> recordIds) async {
    // 1. 过滤掉已经缓存的记录ID
    final idsToFetch = recordIds.where((id) => !_mistakeRecordCache.containsKey(id)).toList();
    if (idsToFetch.isEmpty) {
      return;
    }

    // 2. 并行获取所有 MistakeRecord
    final futures = idsToFetch.map((id) => getMistakeRecord(id)).toList();
    final records = await Future.wait(futures);
    
    final validRecords = records.where((r) => r != null).cast<MistakeRecord>().toList();
    if (validRecords.isEmpty) {
      return;
    }

    // 3. 收集所有需要加载的 questionId, moduleId, knowledgePointId
    final questionIds = <String>{};
    final moduleIds = <String>{};
    final knowledgePointIds = <String>{};

    for (final record in validRecords) {
      if (record.questionId != null) {
        questionIds.add(record.questionId!);
      }
    }

    // 4. 并行获取所有 Question，然后收集其下的 module 和 knowledgePoint Ids
    if (questionIds.isNotEmpty) {
      final questions = await getQuestions(questionIds.toList());
      for (final question in questions) {
        moduleIds.addAll(question.moduleIds);
        knowledgePointIds.addAll(question.knowledgePointIds);
      }
    }

    // 5. 并行获取所有 Module 和 KnowledgePoint 信息
    final preloadFutures = <Future>[];
    if (moduleIds.isNotEmpty) {
      preloadFutures.add(getModules(moduleIds.toList()));
    }
    if (knowledgePointIds.isNotEmpty) {
      preloadFutures.add(getKnowledgePoints(knowledgePointIds.toList()));
    }

    if (preloadFutures.isNotEmpty) {
      await Future.wait(preloadFutures);
    }
    
    print('预加载完成: ${idsToFetch.length} 条记录');
  }

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
      
      // 计算积累的错题数（accumulatedAnalyzedAt 为空的，即未进行过积累错题分析的）
      final accumulatedMistakes = mistakes
          .where((m) => m.accumulatedAnalyzedAt == null)
          .length;
      
      // 计算距离上次复盘的天数（基于最近的 accumulatedAnalyzedAt）
      int daysSinceLastReview = 0;
      if (mistakes.isNotEmpty) {
        // 找到最近一次积累分析的时间
        final lastAnalysis = mistakes
            .where((m) => m.accumulatedAnalyzedAt != null)
            .map((m) => m.accumulatedAnalyzedAt!)
            .fold<DateTime?>(null, (prev, curr) {
              if (prev == null) return curr;
              return curr.isAfter(prev) ? curr : prev;
            });
        
        if (lastAnalysis != null) {
          daysSinceLastReview = DateTime.now().difference(lastAnalysis).inDays;
        } else {
          // 如果从未分析过，计算从最早的错题创建时间到现在的天数
          if (mistakes.isNotEmpty) {
            final earliestMistake = mistakes
                .map((m) => m.createdAt)
                .reduce((a, b) => a.isBefore(b) ? a : b);
            daysSinceLastReview = DateTime.now().difference(earliestMistake).inDays;
          }
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

  /// 批量上传错题图片（并行）
  Future<List<String>> uploadMistakeImages(List<String> filePaths) async {
    // 并行上传所有图片
    final uploadFutures = filePaths.map((path) async {
      try {
        return await uploadMistakeImage(path);
      } catch (e) {
        print('上传图片失败 ($path): $e');
        return ''; // 返回空字符串表示上传失败
      }
    }).toList();
    
    final results = await Future.wait(uploadFutures);
    
    // 过滤掉失败的上传（空字符串）
    final fileIds = results.where((id) => id.isNotEmpty).toList();
    
    print('成功上传 ${fileIds.length}/${filePaths.length} 张图片');
    return fileIds;
  }

  /// 创建错题记录（支持多图题）
  /// [questions] 题目列表，每个题目包含一张或多张照片路径
  /// [userProfile] 用户档案，用于权限检查
  /// 返回创建的错题记录 ID 列表
  Future<List<String>> createMistakeFromQuestions({
    required String userId,
    required List<List<String>> questions,
    String? note,
    UserProfile? userProfile,
  }) async {
    try {
      // 🔒 权限检查：每日错题录入限制
      if (userProfile != null) {
        final subscriptionStatus = userProfile.subscriptionStatus ?? 'free';
        final isPremium = subscriptionStatus == 'active' &&
            userProfile.subscriptionExpiryDate != null &&
            userProfile.subscriptionExpiryDate!.isAfter(DateTime.now().toUtc());

        if (!isPremium) {
          // 免费用户每天最多 3 个
          const dailyLimit = 3;
          final todayCount = userProfile.todayMistakeRecords ?? 0;
          if (todayCount >= dailyLimit) {
            throw Exception('今日错题记录已达上限（$dailyLimit 次），升级会员即可无限使用');
          }
          print('💡 今日还可录入 ${dailyLimit - todayCount} 次错题');
        }
      }

      // 1. 展平并上传所有图片
      final allPhotoPaths = questions.expand((q) => q).toList();
      print('开始上传 ${allPhotoPaths.length} 张图片（共 ${questions.length} 道题）...');
      final allFileIds = await uploadMistakeImages(allPhotoPaths);
      
      if (allFileIds.isEmpty) {
        throw Exception('所有图片上传失败');
      }
      
      print('成功上传 ${allFileIds.length} 张图片');
      
      // 2. 将上传后的 fileIds 按题目重新组织
      final questionFileIds = <List<String>>[];
      var currentIndex = 0;
      for (final question in questions) {
        final questionLength = question.length;
        final endIndex = currentIndex + questionLength;
        if (endIndex <= allFileIds.length) {
          final fileIdsForQuestion = allFileIds.sublist(currentIndex, endIndex);
          questionFileIds.add(fileIdsForQuestion);
          currentIndex = endIndex;
        }
      }
      
      // 3. 为每道题创建一条错题记录
      print('开始创建 ${questionFileIds.length} 条错题记录...');
      
      final createFutures = questionFileIds.map((fileIds) {
        final data = {
          'userId': userId,
          'questionId': null,
          'originalImageIds': fileIds, // 多张图片ID列表
          'analysisStatus': 'pending',
          'masteryStatus': 'notStarted',
          'reviewCount': 0,
          'correctCount': 0,
          'moduleIds': [],
          'knowledgePointIds': [],
          'errorReason': null,
          if (note != null) 'note': note,
        };
        
        return _databases.createDocument(
          databaseId: ApiConfig.databaseId,
          collectionId: ApiConfig.mistakeRecordsCollectionId,
          documentId: ID.unique(),
          data: data,
        );
      }).toList();
      
      final results = await Future.wait(createFutures, eagerError: false);
      
      final List<String> recordIds = [];
      for (var i = 0; i < results.length; i++) {
        try {
          final document = results[i];
          recordIds.add(document.$id);
          print('成功创建错题记录 ${i + 1}/${questionFileIds.length}: ${document.$id}');
        } catch (e) {
          print('创建错题记录失败（跳过题目 ${i + 1}）: $e');
        }
      }
      
      if (recordIds.isEmpty) {
        throw Exception('所有错题记录创建失败');
      }
      
      print('成功创建 ${recordIds.length}/${questionFileIds.length} 条错题记录');
      return recordIds;
    } catch (e) {
      print('创建错题记录失败: $e');
      rethrow;
    }
  }
  
  /// 创建错题记录（拍照录入）- 每张照片作为单独的题目
  /// 返回创建的错题记录 ID
  /// subject 由 AI 自动识别，不需要手动传入
  Future<List<String>> createMistakeFromPhotos({
    required String userId,
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
      
      // 2. 为每张图片并行创建错题记录
      print('开始并行创建 ${fileIds.length} 条错题记录...');
      
      final createFutures = fileIds.map((fileId) {
        final data = {
          'userId': userId,
          'questionId': null, // 拍照录入时暂无题目ID，等待AI分析后填充
          // subject 字段不再传入，由后端 AI 自动识别
          'originalImageIds': [fileId], // 数组格式，单图题包含一张图片
          'analysisStatus': 'pending', // 等待 AI 分析
          'masteryStatus': 'notStarted',
          'reviewCount': 0,
          'correctCount': 0,
          'moduleIds': [], // 空数组，等待AI分析后填充
          'knowledgePointIds': [], // 空数组，等待AI分析后填充
          'errorReason': null, // 错因默认为空，由用户手动添加
          if (note != null) 'note': note,
        };
        
        return _databases.createDocument(
          databaseId: ApiConfig.databaseId,
          collectionId: ApiConfig.mistakeRecordsCollectionId,
          documentId: ID.unique(),
          data: data,
        );
      }).toList();
      
      // 并行等待所有创建完成
      final results = await Future.wait(
        createFutures,
        eagerError: false, // 即使有错误也继续等待其他任务完成
      );
      
      // 收集成功创建的记录ID
      final List<String> recordIds = [];
      for (var i = 0; i < results.length; i++) {
        try {
          final document = results[i];
          recordIds.add(document.$id);
          print('成功创建错题记录 ${i + 1}/${fileIds.length}: ${document.$id}');
        } catch (e) {
          print('创建错题记录失败（跳过图片 ${fileIds[i]}）: $e');
          // 继续处理其他图片
        }
      }
      
      if (recordIds.isEmpty) {
        throw Exception('所有错题记录创建失败');
      }
      
      print('成功创建 ${recordIds.length}/${fileIds.length} 条错题记录');
      return recordIds;
    } catch (e) {
      print('创建错题记录失败: $e');
      rethrow;
    }
  }

  /// 订阅单个错题记录的更新（监听 AI 分析进度）
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

  /// 订阅多个错题记录的更新（使用单一 WebSocket 连接，符合 Appwrite 最佳实践）
  /// 
  /// 根据 Appwrite 文档：SDK 为所有订阅频道创建单个 WebSocket 连接
  /// https://appwrite.io/docs/apis/realtime#limitations
  RealtimeSubscription subscribeMultipleMistakes({
    required List<String> channels,
    required void Function(MistakeRecord record) onUpdate,
    void Function(dynamic error)? onError,
  }) {
    print('📡 订阅 ${channels.length} 个频道 (单一 WebSocket 连接)');
    
    final subscription = _realtime.subscribe(channels);

    subscription.stream.listen(
      (event) {
        // 监听 update 事件
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
  Future<MistakeRecord?> getMistakeRecord(String recordId, {bool forceRefresh = false}) async {
    // 1. 检查缓存（如果不强制刷新）
    if (!forceRefresh && _mistakeRecordCache.containsKey(recordId)) {
      return _mistakeRecordCache[recordId];
    }
    
    // 2. 从网络获取（强制刷新时清除缓存）
    if (forceRefresh) {
      _mistakeRecordCache.remove(recordId);
    }
    
    try {
      final document = await _databases.getDocument(
        databaseId: ApiConfig.databaseId,
        collectionId: ApiConfig.mistakeRecordsCollectionId,
        documentId: recordId,
      );

      final record = MistakeRecord.fromJson({
        'id': document.$id,
        'createdAt': document.$createdAt,
        ...document.data,
      });

      // 3. 存入缓存
      _mistakeRecordCache[recordId] = record;
      
      return record;
    } catch (e) {
      print('获取错题记录失败: $e');
      return null;
    }
  }
  
  /// 清除单个错题记录的缓存
  void clearMistakeRecordCache(String recordId) {
    _mistakeRecordCache.remove(recordId);
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

  /// 反馈 OCR 识别错误（保存反馈并重新触发分析）
  Future<void> reportOcrError(String recordId, String wrongReason) async {
    try {
      await _databases.updateDocument(
        databaseId: ApiConfig.databaseId,
        collectionId: ApiConfig.mistakeRecordsCollectionId,
        documentId: recordId,
        data: {
          'analysisStatus': 'pending',  // 直接触发重新分析
          'wrongReason': wrongReason,   // 保存用户反馈
          'analysisError': null,        // 清除之前的错误
        },
      );
      // 更新成功后，使缓存失效
      _mistakeRecordCache.remove(recordId);
      print('已反馈 OCR 错误，触发重新分析: $recordId');
    } catch (e) {
      print('反馈 OCR 错误失败: $e');
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
      // 更新成功后，使缓存失效
      _mistakeRecordCache.remove(recordId);
    } catch (e) {
      print('更新备注失败: $e');
      rethrow;
    }
  }
  
  /// 更新题目答案
  Future<void> updateQuestionAnswer(String questionId, String answer) async {
    try {
      await _databases.updateDocument(
        databaseId: ApiConfig.databaseId,
        collectionId: ApiConfig.questionsCollectionId,
        documentId: questionId,
        data: {'answer': answer},
      );
      // 更新成功后，使缓存失效
      _questionCache.remove(questionId);
    } catch (e) {
      print('更新答案失败: $e');
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

  /// 获取题目详情
  Future<Question?> getQuestion(String questionId) async {
    // 1. 检查缓存
    if (_questionCache.containsKey(questionId)) {
      return _questionCache[questionId];
    }
    
    // 2. 如果缓存中没有，从网络获取
    try {
      final document = await _databases.getDocument(
        databaseId: ApiConfig.databaseId,
        collectionId: ApiConfig.questionsCollectionId,
        documentId: questionId,
      );

      final question = Question.fromJson({
        'id': document.$id,
        'createdAt': document.$createdAt,
        ...document.data,
      });
      
      // 3. 存入缓存
      _questionCache[questionId] = question;

      return question;
    } catch (e) {
      print('获取题目详情失败: $e');
      return null;
    }
  }

  /// 批量获取题目详情
  Future<List<Question>> getQuestions(List<String> questionIds) async {
    final questions = <Question>[];
    final idsToFetch = <String>[];

    // 1. 从缓存中分离出已有的和需要获取的
    for (final id in questionIds) {
      if (_questionCache.containsKey(id)) {
        questions.add(_questionCache[id]!);
      } else {
        idsToFetch.add(id);
      }
    }

    // 2. 并行获取所有缺失的题目
    if (idsToFetch.isNotEmpty) {
      try {
        final futures = idsToFetch.map((id) => getQuestion(id));
        final fetchedQuestions = await Future.wait(futures);
        
        for (final question in fetchedQuestions) {
          if (question != null) {
            questions.add(question);
            // getQuestion 方法内部已经做了缓存，这里无需重复添加
          }
        }
      } catch (e) {
        print('批量获取题目失败: $e');
      }
    }
    
    return questions;
  }

  /// 更新错题记录
  Future<void> updateMistakeRecord({
    required String recordId,
    required Map<String, dynamic> data,
  }) async {
    try {
      await _databases.updateDocument(
        databaseId: ApiConfig.databaseId,
        collectionId: ApiConfig.mistakeRecordsCollectionId,
        documentId: recordId,
        data: data,
      );
      // 更新成功后，使缓存失效
      _mistakeRecordCache.remove(recordId);
    } catch (e) {
      print('更新错题记录失败: $e');
      rethrow;
    }
  }

  /// 更新错因
  /// [errorReason] 可以是预定义的枚举 name（如 "conceptUnclear"）或自定义文本
  Future<void> updateErrorReason(
    String mistakeId, {
    required String? errorReason,
  }) async {
    await updateMistakeRecord(
      recordId: mistakeId,
      data: {'errorReason': errorReason},
    );
    // updateMistakeRecord 内部已经清除了缓存
  }

  /// 删除错题记录
  Future<void> deleteMistakeRecord(String recordId) async {
    try {
      await _databases.deleteDocument(
        databaseId: ApiConfig.databaseId,
        collectionId: ApiConfig.mistakeRecordsCollectionId,
        documentId: recordId,
      );
      // 删除成功后，从缓存中移除
      _mistakeRecordCache.remove(recordId);
      _questionCache.removeWhere((key, value) => _mistakeRecordCache[recordId]?.questionId == key); // Not perfect but helps
    } catch (e) {
      print('删除错题记录失败: $e');
      rethrow;
    }
  }

  /// 获取模块信息（从公共模块库）
  Future<Map<String, String>> getModule(String moduleId) async {
    if (_moduleCache.containsKey(moduleId)) {
      return _moduleCache[moduleId]!;
    }
    
    try {
      final document = await _databases.getDocument(
        databaseId: ApiConfig.databaseId,
        collectionId: ApiConfig.knowledgePointsLibraryCollectionId,
        documentId: moduleId,
      );
      
      final moduleData = {
        'id': document.$id,
        'name': document.data['name'] as String? ?? '未知模块',
        'description': document.data['description'] as String? ?? '',
      };
      
      _moduleCache[moduleId] = moduleData;
      return moduleData;
    } catch (e) {
      print('获取模块信息失败 ($moduleId): $e');
      return {
        'id': moduleId,
        'name': '模块 ${moduleId.substring(0, 8)}...',
        'description': '',
      };
    }
  }

  /// 批量获取模块信息
  Future<Map<String, Map<String, String>>> getModules(List<String> moduleIds) async {
    final modules = <String, Map<String, String>>{};
    final idsToFetch = <String>[];
    
    for (final id in moduleIds) {
      if (_moduleCache.containsKey(id)) {
        modules[id] = _moduleCache[id]!;
      } else {
        idsToFetch.add(id);
      }
    }
    
    if (idsToFetch.isNotEmpty) {
      final futures = idsToFetch.map((id) => getModule(id)).toList();
      final results = await Future.wait(futures);
      for (var i = 0; i < idsToFetch.length; i++) {
        modules[idsToFetch[i]] = results[i];
        // getModule 内部已经做了缓存
      }
    }
    
    return modules;
  }

  /// 获取知识点信息（从用户知识点）
  Future<Map<String, String>> getKnowledgePoint(String knowledgePointId) async {
    if (_knowledgePointCache.containsKey(knowledgePointId)) {
      return _knowledgePointCache[knowledgePointId]!;
    }
    
    try {
      final document = await _databases.getDocument(
        databaseId: ApiConfig.databaseId,
        collectionId: ApiConfig.knowledgePointsCollectionId,
        documentId: knowledgePointId,
      );
      
      final kpData = {
        'id': document.$id,
        'name': document.data['name'] as String? ?? '未知知识点',
        'moduleId': document.data['moduleId'] as String? ?? '',
      };
      
      _knowledgePointCache[knowledgePointId] = kpData;
      return kpData;
    } catch (e) {
      print('获取知识点信息失败 ($knowledgePointId): $e');
      return {
        'id': knowledgePointId,
        'name': '知识点 ${knowledgePointId.substring(0, 8)}...',
        'moduleId': '',
      };
    }
  }

  /// 批量获取知识点信息
  Future<Map<String, Map<String, String>>> getKnowledgePoints(List<String> knowledgePointIds) async {
    final knowledgePoints = <String, Map<String, String>>{};
    final idsToFetch = <String>[];

    for (final id in knowledgePointIds) {
      if (_knowledgePointCache.containsKey(id)) {
        knowledgePoints[id] = _knowledgePointCache[id]!;
      } else {
        idsToFetch.add(id);
      }
    }
    
    if (idsToFetch.isNotEmpty) {
      final futures = idsToFetch.map((id) => getKnowledgePoint(id)).toList();
      final results = await Future.wait(futures);
      for (var i = 0; i < idsToFetch.length; i++) {
        knowledgePoints[idsToFetch[i]] = results[i];
        // getKnowledgePoint 内部已经做了缓存
      }
    }
    
    return knowledgePoints;
  }
}

