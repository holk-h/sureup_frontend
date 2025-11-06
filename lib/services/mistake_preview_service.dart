import 'dart:async';
import 'package:appwrite/appwrite.dart';
import '../config/api_config.dart';
import '../models/models.dart';
import 'mistake_service.dart';

/// 错题预览服务
/// 处理数据加载、缓存和 Realtime 订阅管理
class MistakePreviewService {
  final MistakeService _mistakeService = MistakeService();
  
  // 缓存所有记录和题目数据（按记录ID缓存）
  final Map<String, MistakeRecord> _cachedRecords = {}; // recordId -> MistakeRecord
  final Map<String, Question> _cachedQuestions = {}; // recordId -> Question
  final Map<String, Map<String, Map<String, String>>> _recordModulesInfo = {}; // recordId -> moduleId -> moduleInfo
  final Map<String, Map<String, Map<String, String>>> _recordKnowledgePointsInfo = {}; // recordId -> kpId -> kpInfo
  
  // Realtime 订阅管理
  RealtimeSubscription? _realtimeSubscription;
  final Set<String> _subscribedRecordIds = {};
  
  // 事件流控制器
  final StreamController<MistakeRecord> _recordUpdateController = StreamController<MistakeRecord>.broadcast();
  final StreamController<String> _errorController = StreamController<String>.broadcast();
  
  // 公开的事件流
  Stream<MistakeRecord> get recordUpdates => _recordUpdateController.stream;
  Stream<String> get errors => _errorController.stream;
  
  /// 获取缓存的记录
  MistakeRecord? getCachedRecord(String recordId) => _cachedRecords[recordId];
  
  /// 获取缓存的题目
  Question? getCachedQuestion(String recordId) => _cachedQuestions[recordId];
  
  /// 获取缓存的模块信息
  Map<String, Map<String, String>> getCachedModulesInfo(String recordId) => 
      _recordModulesInfo[recordId] ?? {};
  
  /// 获取缓存的知识点信息
  Map<String, Map<String, String>> getCachedKnowledgePointsInfo(String recordId) => 
      _recordKnowledgePointsInfo[recordId] ?? {};
  
  /// 加载记录数据
  Future<MistakeRecord?> loadRecord(String recordId) async {
    try {
      // 如果已经缓存，检查是否需要刷新
      if (_cachedRecords.containsKey(recordId)) {
        final cachedRecord = _cachedRecords[recordId]!;
        
        // 如果分析尚未完成，进行后台刷新
        if (cachedRecord.analysisStatus != AnalysisStatus.completed &&
            cachedRecord.analysisStatus != AnalysisStatus.failed) {
          _refreshRecord(recordId);
        }
        
        return cachedRecord;
      }
      
      // 加载新记录
      final record = await _mistakeService.getMistakeRecord(recordId);
      if (record == null) {
        throw Exception('错题记录不存在');
      }
      
      // 缓存记录数据
      _cachedRecords[recordId] = record;
      
      // 如果已经有 questionId，加载题目详情
      if (record.questionId != null) {
        await _loadQuestionDetails(recordId, record.questionId!);
        // 加载题目的模块和知识点信息
        if (_cachedQuestions.containsKey(recordId)) {
          await _loadQuestionInfo(recordId);
        }
      }
      
      return record;
    } catch (e) {
      _errorController.add('加载失败: $e');
      return null;
    }
  }
  
  /// 后台刷新记录数据
  Future<void> _refreshRecord(String recordId) async {
    try {
      final record = await _mistakeService.getMistakeRecord(recordId);
      if (record == null) return;
      
      final oldRecord = _cachedRecords[recordId];
      
      // 检查是否真的有变化
      final hasStatusChange = oldRecord?.analysisStatus != record.analysisStatus;
      final hasQuestionIdChange = oldRecord?.questionId != record.questionId;
      
      // 更新缓存
      _cachedRecords[recordId] = record;
      
      // 如果状态有变化，发送更新事件
      if (hasStatusChange || hasQuestionIdChange) {
        // 如果新增了questionId，加载题目详情
        if (record.questionId != null && !_cachedQuestions.containsKey(recordId)) {
          await _loadQuestionDetails(recordId, record.questionId!);
          // 只在分析完成时加载完整信息（模块和知识点）
          if (record.analysisStatus == AnalysisStatus.completed && 
              _cachedQuestions.containsKey(recordId)) {
            await _loadQuestionInfo(recordId);
          }
        }
        
        _recordUpdateController.add(record);
      }
    } catch (e) {
      print('后台刷新失败: $e');
    }
  }
  
  /// 加载题目详情
  Future<void> _loadQuestionDetails(String recordId, String questionId) async {
    try {
      print('      🔍 开始加载题目: recordId=$recordId, questionId=$questionId');
      final questions = await _mistakeService.getQuestions([questionId]);
      print('      📦 收到题目数据: ${questions.length} 个');
      if (questions.isNotEmpty) {
        final question = questions.first;
        _cachedQuestions[recordId] = question;
        print('      ✅ 题目已缓存: ${question.content.substring(0, 20)}...');
        print('      📊 题目信息:');
        print('         - subject: ${question.subject}');
        print('         - moduleIds: ${question.moduleIds}');
        print('         - knowledgePointIds: ${question.knowledgePointIds}');
      } else {
        print('      ⚠️ 未找到题目数据');
      }
    } catch (e) {
      print('      ❌ 加载题目详情失败: $e');
    }
  }
  
  /// 加载题目的模块和知识点详细信息
  Future<void> _loadQuestionInfo(String recordId) async {
    final question = _cachedQuestions[recordId];
    if (question == null) {
      print('      ⚠️ 题目为空，无法加载模块和知识点信息');
      return;
    }

    print('      📚 加载模块和知识点信息 (recordId: $recordId)');
    print('         - moduleIds: ${question.moduleIds}');
    print('         - knowledgePointIds: ${question.knowledgePointIds}');

    // 检查是否已缓存
    if (_recordModulesInfo.containsKey(recordId) &&
        _recordKnowledgePointsInfo.containsKey(recordId)) {
      print('      ✓ 模块和知识点信息已缓存，跳过加载');
      return;
    }

    try {
      final futures = <Future>[];
      
      // 加载模块信息
      if (question.moduleIds.isNotEmpty) {
        print('      🔄 加载 ${question.moduleIds.length} 个模块信息...');
        futures.add(
          _mistakeService.getModules(question.moduleIds).then((modules) {
            _recordModulesInfo[recordId] = modules;
            print('      ✅ 模块信息已加载: ${modules.keys}');
          })
        );
      } else {
        print('      ⚠️ moduleIds 为空，跳过加载模块信息');
      }
      
      // 加载知识点信息
      if (question.knowledgePointIds.isNotEmpty) {
        print('      🔄 加载 ${question.knowledgePointIds.length} 个知识点信息...');
        futures.add(
          _mistakeService.getKnowledgePoints(question.knowledgePointIds).then((kps) {
            _recordKnowledgePointsInfo[recordId] = kps;
            print('      ✅ 知识点信息已加载: ${kps.keys}');
          })
        );
      } else {
        print('      ⚠️ knowledgePointIds 为空，跳过加载知识点信息');
      }

      // 等待所有数据加载完成
      await Future.wait(futures);
      print('      🎉 模块和知识点信息加载完成');
    } catch (e) {
      print('      ❌ 加载题目详细信息失败: $e');
    }
  }
  
  /// 建立 Realtime 订阅
  void setupRealtimeSubscription(List<String> recordIds) {
    if (_realtimeSubscription != null || recordIds.isEmpty) {
      return;
    }
    
    // 构建所有记录的频道列表
    final channels = recordIds
        .map((id) => 'databases.${ApiConfig.databaseId}.collections.${ApiConfig.mistakeRecordsCollectionId}.documents.$id')
        .toList();
    
    print('📡 建立 Realtime 订阅 (频道数: ${channels.length})');
    
    try {
      _realtimeSubscription = _mistakeService.subscribeMultipleMistakes(
        channels: channels,
        onUpdate: _handleRealtimeUpdate,
        onError: _handleRealtimeError,
      );
      
      _subscribedRecordIds.addAll(recordIds);
      print('✅ Realtime 订阅已建立');
    } catch (e) {
      print('❌ 建立 Realtime 订阅失败: $e');
      _errorController.add('订阅失败: $e');
    }
  }
  
  /// 处理 Realtime 更新
  Future<void> _handleRealtimeUpdate(MistakeRecord updatedRecord) async {
    final recordId = updatedRecord.id;
    print('📨 收到 Realtime 更新: $recordId (状态: ${updatedRecord.analysisStatus})');
    print('   questionId: ${updatedRecord.questionId}');
    print('   题目已缓存: ${_cachedQuestions.containsKey(recordId)}');

    // 更新缓存
    _cachedRecords[recordId] = updatedRecord;

    // 如果有 questionId，加载题目详情
    if (updatedRecord.questionId != null) {
      print('   ✅ questionId 不为空，准备加载题目');
      
      if (updatedRecord.analysisStatus == AnalysisStatus.ocrOK) {
        print('   📝 状态为 ocrOK');
        // OCR 完成：加载题目基本信息（内容和选项）
        if (!_cachedQuestions.containsKey(recordId)) {
          print('🎯 OCR 完成，加载题目基本信息: ${updatedRecord.questionId}');
          await _loadQuestionDetails(recordId, updatedRecord.questionId!);
          print('   ✅ 题目加载完成，缓存中题目数: ${_cachedQuestions.length}');
        } else {
          print('   ⚠️ 题目已在缓存中，跳过加载');
        }
      } else if (updatedRecord.analysisStatus == AnalysisStatus.completed) {
        print('   📝 状态为 completed');
        // 分析完成：清除题目缓存并重新加载，以获取最新的 moduleIds 和 knowledgePointIds
        print('🎯 分析完成，清除缓存并重新加载完整题目详情: ${updatedRecord.questionId}');
        
        // 清除 MistakeService 中的题目缓存，确保获取最新数据
        _mistakeService.clearQuestionCache(updatedRecord.questionId!);
        
        // 重新加载题目详情
        await _loadQuestionDetails(recordId, updatedRecord.questionId!);
        
        // 加载模块和知识点信息
        if (_cachedQuestions.containsKey(recordId)) {
          print('📚 加载模块和知识点信息');
          await _loadQuestionInfo(recordId);
        }
      } else {
        print('   ⚠️ 状态不是 ocrOK 或 completed，当前状态: ${updatedRecord.analysisStatus}');
      }
    } else {
      print('   ❌ questionId 为空，跳过题目加载');
    }
    
    // 发送更新事件
    print('   📢 发送更新事件');
    _recordUpdateController.add(updatedRecord);
    
    // 检查是否所有记录都已完成分析
    _checkAndCloseSubscriptionIfAllCompleted();
  }
  
  /// 处理 Realtime 错误
  void _handleRealtimeError(dynamic error) {
    print('❌ Realtime 订阅错误: $error');
    _errorController.add('订阅错误: $error');
    
    // 关闭失败的订阅
    _closeSubscription();
    
    // 延迟重试
    Future.delayed(const Duration(seconds: 3), () {
      if (_subscribedRecordIds.isNotEmpty) {
        print('🔄 尝试重新建立 Realtime 订阅...');
        setupRealtimeSubscription(_subscribedRecordIds.toList());
      }
    });
  }
  
  /// 检查是否所有记录都已完成分析，如果是则关闭订阅
  void _checkAndCloseSubscriptionIfAllCompleted() {
    if (_realtimeSubscription == null) return;
    
    // 检查所有记录是否都已完成或失败
    bool allCompleted = true;
    for (final recordId in _subscribedRecordIds) {
      final record = _cachedRecords[recordId];
      if (record != null &&
          record.analysisStatus != AnalysisStatus.completed &&
          record.analysisStatus != AnalysisStatus.failed) {
        allCompleted = false;
        break;
      }
    }
    
    if (allCompleted) {
      print('🎉 所有记录分析完成，关闭 Realtime 订阅');
      _closeSubscription();
    }
  }
  
  /// 关闭订阅
  void _closeSubscription() {
    try {
      _realtimeSubscription?.close();
      _realtimeSubscription = null;
      _subscribedRecordIds.clear();
    } catch (e) {
      print('❌ 关闭订阅失败: $e');
    }
  }
  
  /// 更新错因
  Future<void> updateErrorReason(String recordId, String errorReason) async {
    try {
      await _mistakeService.updateErrorReason(recordId, errorReason: errorReason);
      
      // 更新本地缓存
      final record = _cachedRecords[recordId];
      if (record != null) {
        final updatedRecord = record.copyWith(errorReason: errorReason);
        _cachedRecords[recordId] = updatedRecord;
        _recordUpdateController.add(updatedRecord);
      }
    } catch (e) {
      _errorController.add('更新错因失败: $e');
    }
  }
  
  /// 更新是否重要
  Future<void> updateIsImportant(String recordId, bool isImportant) async {
    try {
      await _mistakeService.updateMistakeRecord(
        recordId: recordId,
        data: {'isImportant': isImportant},
      );
      
      // 更新本地缓存
      final record = _cachedRecords[recordId];
      if (record != null) {
        final updatedRecord = record.copyWith(isImportant: isImportant);
        _cachedRecords[recordId] = updatedRecord;
        _recordUpdateController.add(updatedRecord);
      }
    } catch (e) {
      _errorController.add('更新重要标记失败: $e');
      rethrow;
    }
  }
  
  /// 重新分析
  Future<void> retryAnalysis(String recordId) async {
    try {
      await _mistakeService.updateMistakeRecord(
        recordId: recordId,
        data: {
          'analysisStatus': 'pending',
          'analysisError': null,
        },
      );
      
      // 更新本地缓存
      final record = _cachedRecords[recordId];
      if (record != null) {
        final updatedRecord = record.copyWith(
          analysisStatus: AnalysisStatus.pending,
          analysisError: null,
          analyzedAt: null,
        );
        _cachedRecords[recordId] = updatedRecord;
        _recordUpdateController.add(updatedRecord);
      }
      
      // 如果订阅已关闭，重新建立
      _ensureSubscriptionActive([recordId]);
    } catch (e) {
      _errorController.add('重新分析失败: $e');
    }
  }
  
  /// 确保 Realtime 订阅处于活跃状态
  void _ensureSubscriptionActive(List<String> recordIds) {
    if (_realtimeSubscription == null && recordIds.isNotEmpty) {
      print('🔄 Realtime 订阅已关闭，重新建立订阅');
      setupRealtimeSubscription(recordIds);
    }
  }
  
  /// 反馈 OCR 错误并重新分析
  Future<void> reportOcrError(String recordId, String wrongReason) async {
    try {
      await _mistakeService.reportOcrError(recordId, wrongReason);
      
      // 更新本地缓存
      final record = _cachedRecords[recordId];
      if (record != null) {
        final updatedRecord = record.copyWith(
          analysisStatus: AnalysisStatus.pending,
          wrongReason: wrongReason,
          analysisError: null,
        );
        _cachedRecords[recordId] = updatedRecord;
        _recordUpdateController.add(updatedRecord);
      }
      
      // 如果订阅已关闭，重新建立
      _ensureSubscriptionActive([recordId]);
    } catch (e) {
      _errorController.add('反馈 OCR 错误失败: $e');
      rethrow;
    }
  }
  
  /// 删除记录
  Future<void> deleteRecord(String recordId) async {
    try {
      await _mistakeService.deleteMistakeRecord(recordId);
      
      // 清理本地缓存
      _cachedRecords.remove(recordId);
      _cachedQuestions.remove(recordId);
      _recordModulesInfo.remove(recordId);
      _recordKnowledgePointsInfo.remove(recordId);
      _subscribedRecordIds.remove(recordId);
    } catch (e) {
      _errorController.add('删除失败: $e');
      rethrow;
    }
  }
  
  /// 释放资源
  void dispose() {
    _closeSubscription();
    _recordUpdateController.close();
    _errorController.close();
    _cachedRecords.clear();
    _cachedQuestions.clear();
    _recordModulesInfo.clear();
    _recordKnowledgePointsInfo.clear();
  }
}
