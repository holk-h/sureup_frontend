import 'dart:async';
import 'dart:convert';
import 'package:appwrite/appwrite.dart';
import '../config/api_config.dart';

/// 积累错题分析服务
/// 
/// 负责：
/// 1. 触发分析任务
/// 2. 订阅 Realtime 更新
/// 3. 提供流式分析内容
class AccumulatedAnalysisService {
  Databases? _databases;
  Functions? _functions;
  Realtime? _realtime;
  
  // Realtime 订阅
  RealtimeSubscription? _subscription;
  
  // 流控制器
  final _analysisStreamController = StreamController<AnalysisUpdate>.broadcast();
  
  /// 分析内容更新流
  Stream<AnalysisUpdate> get analysisStream => _analysisStreamController.stream;
  
  /// 初始化服务
  void initialize(Client client) {
    _databases = Databases(client);
    _functions = Functions(client);
    _realtime = Realtime(client);
  }
  
  /// 创建分析任务
  /// 
  /// 返回分析记录 ID
  Future<String> createAnalysis(String userId) async {
    if (_functions == null) {
      throw Exception('服务未初始化');
    }
    
    try {
      // 调用 Appwrite Function
      final execution = await _functions!.createExecution(
        functionId: ApiConfig.functionAccumulatedAnalyzer,
        body: '{"userId": "$userId"}',
      );
      
      // 解析响应
      final response = execution.responseBody;
      
      // 假设响应是 JSON 格式
      if (response.contains('analysisId')) {
        // 简单的字符串解析
        final start = response.indexOf('"analysisId":"') + 14;
        final end = response.indexOf('"', start);
        final analysisId = response.substring(start, end);
        
        return analysisId;
      } else {
        throw Exception('创建分析任务失败');
      }
    } catch (e) {
      print('创建分析任务失败: $e');
      rethrow;
    }
  }
  
  /// 订阅分析更新
  /// 
  /// 通过 Realtime API 订阅分析记录的更新
  void subscribeToAnalysis(String analysisId) {
    if (_realtime == null) {
      throw Exception('服务未初始化');
    }
    
    // 取消之前的订阅
    _subscription?.close();
    
    try {
      // 订阅特定文档的更新
      _subscription = _realtime!.subscribe([
        'databases.${ApiConfig.databaseId}.collections.${ApiConfig.accumulatedAnalysesCollectionId}.documents.$analysisId'
      ]);
      
      // 监听更新事件
      _subscription!.stream.listen(
        (response) {
          _handleRealtimeUpdate(response);
        },
        onError: (error) {
          print('Realtime 订阅错误: $error');
          _analysisStreamController.addError(error);
        },
        onDone: () {
          print('Realtime 订阅结束');
        },
      );
      
      print('已订阅分析更新: $analysisId');
    } catch (e) {
      print('订阅失败: $e');
      rethrow;
    }
  }
  
  /// 处理 Realtime 更新
  void _handleRealtimeUpdate(dynamic response) {
    try {
      // 检查事件类型
      final events = response.events as List<dynamic>?;
      
      // 只处理文档更新事件
      if (events != null && events.any((e) => e.toString().contains('.update'))) {
        final payload = response.payload as Map<String, dynamic>?;
        
        if (payload == null) {
          print('Realtime payload is null');
          return;
        }
        
        // 提取关键字段
        final status = payload['status'] as String?;
        final content = payload['analysisContent'] as String?;
        final summaryStr = payload['summary'] as String?;
        
        // 解析 summary（从 JSON 字符串转换为 Map）
        Map<String, dynamic>? summary;
        if (summaryStr != null && summaryStr.isNotEmpty && summaryStr != '{}') {
          try {
            summary = json.decode(summaryStr) as Map<String, dynamic>?;
          } catch (e) {
            print('解析 summary 失败: $e');
          }
        }
        
        // 发送更新
        final update = AnalysisUpdate(
          status: status ?? 'unknown',
          content: content ?? '',
          summary: summary,
          timestamp: DateTime.now(),
        );
        
        _analysisStreamController.add(update);
        
        // 如果分析完成或失败，关闭订阅
        if (status == 'completed' || status == 'failed') {
          print('分析已完成，状态: $status');
          unsubscribe();
        }
      }
    } catch (e) {
      print('处理 Realtime 更新失败: $e');
    }
  }
  
  /// 取消订阅
  void unsubscribe() {
    _subscription?.close();
    _subscription = null;
    print('已取消分析订阅');
  }
  
  /// 获取分析记录
  Future<Map<String, dynamic>> getAnalysis(String analysisId) async {
    if (_databases == null) {
      throw Exception('服务未初始化');
    }
    
    try {
      final document = await _databases!.getDocument(
        databaseId: ApiConfig.databaseId,
        collectionId: ApiConfig.accumulatedAnalysesCollectionId,
        documentId: analysisId,
      );
      
      return document.data;
    } catch (e) {
      print('获取分析记录失败: $e');
      rethrow;
    }
  }
  
  /// 获取用户的历史分析记录
  Future<List<Map<String, dynamic>>> getUserAnalyses(
    String userId, {
    int limit = 10,
  }) async {
    if (_databases == null) {
      throw Exception('服务未初始化');
    }
    
    try {
      final documents = await _databases!.listDocuments(
        databaseId: ApiConfig.databaseId,
        collectionId: ApiConfig.accumulatedAnalysesCollectionId,
        queries: [
          Query.equal('userId', userId),
          Query.orderDesc('\$createdAt'),
          Query.limit(limit),
        ],
      );
      
      return documents.documents.map((doc) => doc.data).toList();
    } catch (e) {
      print('获取历史分析记录失败: $e');
      return [];
    }
  }
  
  /// 清理资源
  void dispose() {
    unsubscribe();
    _analysisStreamController.close();
  }
}

/// 分析更新数据模型
class AnalysisUpdate {
  final String status;
  final String content;
  final Map<String, dynamic>? summary;
  final DateTime timestamp;
  
  AnalysisUpdate({
    required this.status,
    required this.content,
    this.summary,
    required this.timestamp,
  });
  
  bool get isCompleted => status == 'completed';
  bool get isFailed => status == 'failed';
  bool get isProcessing => status == 'processing';
  bool get isPending => status == 'pending';
}

