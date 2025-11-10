import 'dart:convert';
import 'review_state.dart';

/// 知识点分组辅助类（用于转换后端数据）
class _KnowledgePointGroup {
  final String knowledgePointId;
  final String knowledgePointName;
  final ReviewStatus status;
  final List<TaskQuestion> _questions = [];

  _KnowledgePointGroup({
    required this.knowledgePointId,
    required this.knowledgePointName,
    required this.status,
  });

  void addQuestion({
    required String questionId,
    required QuestionSource source,
    String? mistakeRecordId,
  }) {
    // 避免重复添加同一道题
    if (_questions.any((q) => q.questionId == questionId)) {
      return;
    }

    _questions.add(TaskQuestion(
      questionId: questionId,
      source: source,
      displayOrder: _questions.length,
      mistakeRecordId: mistakeRecordId,
    ));
  }

  TaskItem toTaskItem() {
    final originalCount = _questions.where((q) => q.source == QuestionSource.original).length;
    final variantCount = _questions.where((q) => q.source == QuestionSource.variant).length;

    return TaskItem(
      knowledgePointId: knowledgePointId,
      knowledgePointName: knowledgePointName,
      status: status,
      questions: _questions,
      originalCount: originalCount,
      variantCount: variantCount,
    );
  }
}

/// 题目来源
enum QuestionSource {
  original('原题'),
  variant('变式题');

  const QuestionSource(this.displayName);
  final String displayName;
}

/// 知识点信息（用于题目关联）
class KnowledgePointInfo {
  final String knowledgePointId;
  final String knowledgePointName;
  final ReviewStatus status;

  const KnowledgePointInfo({
    required this.knowledgePointId,
    required this.knowledgePointName,
    required this.status,
  });

  Map<String, dynamic> toJson() => {
    'knowledgePointId': knowledgePointId,
    'knowledgePointName': knowledgePointName,
    'status': status.name,
  };

  factory KnowledgePointInfo.fromJson(Map<String, dynamic> json) => KnowledgePointInfo(
    knowledgePointId: json['knowledgePointId'] as String,
    knowledgePointName: json['knowledgePointName'] as String,
    status: ReviewStatus.values.byName(json['status'] as String),
  );
}

/// 后端返回的任务项（一道题对应多个知识点）
class RawTaskItem {
  final String id;
  final String questionId;
  final QuestionSource source;
  final List<KnowledgePointInfo> knowledgePoints;
  final bool isCompleted;
  final bool? isCorrect;
  final String? mistakeRecordId;

  const RawTaskItem({
    required this.id,
    required this.questionId,
    required this.source,
    required this.knowledgePoints,
    this.isCompleted = false,
    this.isCorrect,
    this.mistakeRecordId,
  });

  factory RawTaskItem.fromJson(Map<String, dynamic> json) => RawTaskItem(
    id: json['id'] as String,
    questionId: json['questionId'] as String,
    source: QuestionSource.values.byName(json['source'] as String),
    knowledgePoints: (json['knowledgePoints'] as List<dynamic>)
        .map((kp) => KnowledgePointInfo.fromJson(kp as Map<String, dynamic>))
        .toList(),
    isCompleted: json['isCompleted'] as bool? ?? false,
    isCorrect: json['isCorrect'] as bool?,
    mistakeRecordId: json['mistakeRecordId'] as String?,
  );
}

/// 任务题目（前端使用）
class TaskQuestion {
  final String questionId;
  final QuestionSource source;
  final int displayOrder;
  final String? mistakeRecordId;
  final List<KnowledgePointInfo>? relatedKnowledgePoints; // 综合题使用：该题涉及的知识点

  const TaskQuestion({
    required this.questionId,
    required this.source,
    required this.displayOrder,
    this.mistakeRecordId,
    this.relatedKnowledgePoints,
  });

  Map<String, dynamic> toJson() => {
    'questionId': questionId,
    'source': source.name,
    'displayOrder': displayOrder,
    if (mistakeRecordId != null) 'mistakeRecordId': mistakeRecordId,
    if (relatedKnowledgePoints != null) 
      'relatedKnowledgePoints': relatedKnowledgePoints!.map((kp) => kp.toJson()).toList(),
  };

  factory TaskQuestion.fromJson(Map<String, dynamic> json) => TaskQuestion(
    questionId: json['questionId'] as String,
    source: QuestionSource.values.byName(json['source'] as String),
    displayOrder: json['displayOrder'] as int? ?? 0,
    mistakeRecordId: json['mistakeRecordId'] as String?,
    relatedKnowledgePoints: json['relatedKnowledgePoints'] != null
        ? (json['relatedKnowledgePoints'] as List<dynamic>)
            .map((kp) => KnowledgePointInfo.fromJson(kp as Map<String, dynamic>))
            .toList()
        : null,
  );
}

/// 任务项
class TaskItem {
  final String knowledgePointId;
  final String knowledgePointName;
  final ReviewStatus status;
  
  final List<TaskQuestion> questions; // 题目列表
  final int originalCount; // 原题数量
  final int variantCount; // 变式题数量
  
  final bool isCompleted;
  final int correctCount;
  final int wrongCount;
  
  final String? aiMessage; // AI提示
  final bool isComprehensive; // 是否是综合题（涉及多个知识点）

  const TaskItem({
    required this.knowledgePointId,
    required this.knowledgePointName,
    required this.status,
    required this.questions,
    required this.originalCount,
    required this.variantCount,
    this.isCompleted = false,
    this.correctCount = 0,
    this.wrongCount = 0,
    this.aiMessage,
    this.isComprehensive = false,
  });

  /// 总题数
  int get totalQuestions => questions.length;

  /// 完成进度
  double get progress {
    final total = correctCount + wrongCount;
    if (totalQuestions == 0) return 0.0;
    return total / totalQuestions;
  }

  /// 正确率
  double get accuracy {
    final total = correctCount + wrongCount;
    if (total == 0) return 0.0;
    return correctCount / total;
  }

  Map<String, dynamic> toJson() => {
    'knowledgePointId': knowledgePointId,
    'knowledgePointName': knowledgePointName,
    'status': status.name,
    'questions': questions.map((q) => q.toJson()).toList(),
    'originalCount': originalCount,
    'variantCount': variantCount,
    'isCompleted': isCompleted,
    'correctCount': correctCount,
    'wrongCount': wrongCount,
    'aiMessage': aiMessage,
    'isComprehensive': isComprehensive,
  };

  factory TaskItem.fromJson(Map<String, dynamic> json) => TaskItem(
    knowledgePointId: json['knowledgePointId'] as String,
    knowledgePointName: json['knowledgePointName'] as String,
    status: ReviewStatus.values.byName(json['status'] as String),
    questions: (json['questions'] as List<dynamic>)
        .map((q) => TaskQuestion.fromJson(q as Map<String, dynamic>))
        .toList(),
    originalCount: json['originalCount'] as int? ?? 0,
    variantCount: json['variantCount'] as int? ?? 0,
    isCompleted: json['isCompleted'] as bool? ?? false,
    correctCount: json['correctCount'] as int? ?? 0,
    wrongCount: json['wrongCount'] as int? ?? 0,
    aiMessage: json['aiMessage'] as String?,
    isComprehensive: json['isComprehensive'] as bool? ?? false,
  );

  TaskItem copyWith({
    String? knowledgePointId,
    String? knowledgePointName,
    ReviewStatus? status,
    List<TaskQuestion>? questions,
    int? originalCount,
    int? variantCount,
    bool? isCompleted,
    int? correctCount,
    int? wrongCount,
    String? aiMessage,
    bool? isComprehensive,
  }) => TaskItem(
    knowledgePointId: knowledgePointId ?? this.knowledgePointId,
    knowledgePointName: knowledgePointName ?? this.knowledgePointName,
    status: status ?? this.status,
    questions: questions ?? this.questions,
    originalCount: originalCount ?? this.originalCount,
    variantCount: variantCount ?? this.variantCount,
    isCompleted: isCompleted ?? this.isCompleted,
    correctCount: correctCount ?? this.correctCount,
    wrongCount: wrongCount ?? this.wrongCount,
    aiMessage: aiMessage ?? this.aiMessage,
    isComprehensive: isComprehensive ?? this.isComprehensive,
  );
}

/// 每日任务
class DailyTask {
  final String id;
  final String userId;
  final DateTime taskDate;
  
  final List<TaskItem> items; // 2-3个知识点
  
  final int totalQuestions;
  final int completedCount;
  final bool isCompleted;
  
  final DateTime createdAt;
  final DateTime? completedAt;

  const DailyTask({
    required this.id,
    required this.userId,
    required this.taskDate,
    required this.items,
    required this.totalQuestions,
    this.completedCount = 0,
    this.isCompleted = false,
    required this.createdAt,
    this.completedAt,
  });

  /// 进度
  double get progress {
    if (totalQuestions == 0) return 0.0;
    return completedCount / totalQuestions;
  }

  /// 是否今天的任务
  bool get isToday {
    final now = DateTime.now();
    return taskDate.year == now.year &&
        taskDate.month == now.month &&
        taskDate.day == now.day;
  }

  /// 是否逾期
  bool get isOverdue {
    if (isCompleted) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final taskDay = DateTime(taskDate.year, taskDate.month, taskDate.day);
    return taskDay.isBefore(today);
  }

  /// JSON 序列化
  Map<String, dynamic> toJson() => {
    'userId': userId,
    'taskDate': taskDate.toIso8601String(),
    'items': items.map((i) => i.toJson()).toList(),
    'totalQuestions': totalQuestions,
    'completedCount': completedCount,
    'isCompleted': isCompleted,
    'completedAt': completedAt?.toIso8601String(),
  };

  /// JSON 反序列化
  factory DailyTask.fromJson(Map<String, dynamic> json) {
    // items 字段在数据库中存储为 JSON 字符串
    List<TaskItem> items = [];
    final itemsData = json['items'];
    
    if (itemsData is String) {
      // 如果是字符串，需要先解析
      final parsed = jsonDecode(itemsData);
      if (parsed is List) {
        items = _parseTaskItems(parsed);
      }
    } else if (itemsData is List) {
      items = _parseTaskItems(itemsData);
    }

    return DailyTask(
      id: json['id'] as String? ?? json['\$id'] as String,
      userId: json['userId'] as String,
      taskDate: DateTime.parse(json['taskDate'] as String).toLocal(),
      items: items,
      totalQuestions: json['totalQuestions'] as int? ?? 0,
      completedCount: json['completedCount'] as int? ?? 0,
      isCompleted: json['isCompleted'] as bool? ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String).toLocal()
          : (json['\$createdAt'] != null
              ? DateTime.parse(json['\$createdAt'] as String).toLocal()
              : DateTime.now()),
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String).toLocal()
          : null,
    );
  }

  /// 解析任务项：支持新旧两种数据格式
  static List<TaskItem> _parseTaskItems(List<dynamic> itemsData) {
    if (itemsData.isEmpty) return [];

    // 检测数据格式
    final firstItem = itemsData.first as Map<String, dynamic>;
    
    // 新格式：包含 knowledgePoints 数组（一题多知识点）
    if (firstItem.containsKey('knowledgePoints')) {
      return _convertFromRawItems(itemsData);
    }
    
    // 旧格式：直接是 TaskItem（一个知识点对应多道题）
    return itemsData
        .map((i) => TaskItem.fromJson(i as Map<String, dynamic>))
        .toList();
  }

  /// 将后端的 RawTaskItem 列表转换为前端的 TaskItem 列表
  /// 策略：
  /// - 单知识点题目 → 按知识点分组
  /// - 多知识点题目 → 单独作为"综合题"分组
  static List<TaskItem> _convertFromRawItems(List<dynamic> rawItemsData) {
    // 1. 解析原始数据
    final rawItems = rawItemsData
        .map((i) => RawTaskItem.fromJson(i as Map<String, dynamic>))
        .toList();

    // 2. 分离单知识点和多知识点题目
    final singleKpItems = <RawTaskItem>[];
    final multiKpItems = <RawTaskItem>[];

    for (final rawItem in rawItems) {
      if (rawItem.knowledgePoints.length == 1) {
        singleKpItems.add(rawItem);
      } else {
        multiKpItems.add(rawItem);
      }
    }

    final result = <TaskItem>[];

    // 3. 处理单知识点题目：按知识点分组
    if (singleKpItems.isNotEmpty) {
      final kpMap = <String, _KnowledgePointGroup>{};

      for (final rawItem in singleKpItems) {
        final kpInfo = rawItem.knowledgePoints.first;
        final kpId = kpInfo.knowledgePointId;
        
        if (!kpMap.containsKey(kpId)) {
          kpMap[kpId] = _KnowledgePointGroup(
            knowledgePointId: kpId,
            knowledgePointName: kpInfo.knowledgePointName,
            status: kpInfo.status,
          );
        }

        kpMap[kpId]!.addQuestion(
          questionId: rawItem.questionId,
          source: rawItem.source,
          mistakeRecordId: rawItem.mistakeRecordId,
        );
      }

      result.addAll(kpMap.values.map((group) => group.toTaskItem()));
    }

    // 4. 处理多知识点题目：每道题创建单独的任务项
    if (multiKpItems.isNotEmpty) {
      for (final rawItem in multiKpItems) {
        // 拼接知识点名称："知识点1、知识点2"
        final kpNames = rawItem.knowledgePoints
            .map((kp) => kp.knowledgePointName)
            .join('、');
        
        // 拼接知识点ID（用逗号分隔，方便追踪）
        final kpIds = rawItem.knowledgePoints
            .map((kp) => kp.knowledgePointId)
            .join(',');
        
        // 使用主要知识点的状态（第一个）
        final primaryStatus = rawItem.knowledgePoints.first.status;

        result.add(TaskItem(
          knowledgePointId: kpIds,
          knowledgePointName: kpNames,
          status: primaryStatus,
          questions: [
            TaskQuestion(
              questionId: rawItem.questionId,
              source: rawItem.source,
              displayOrder: 0,
              mistakeRecordId: rawItem.mistakeRecordId,
              relatedKnowledgePoints: rawItem.knowledgePoints,
            ),
          ],
          originalCount: rawItem.source == QuestionSource.original ? 1 : 0,
          variantCount: rawItem.source == QuestionSource.variant ? 1 : 0,
          isComprehensive: true,
        ));
      }
    }

    return result;
  }

  /// 复制并更新
  DailyTask copyWith({
    String? id,
    String? userId,
    DateTime? taskDate,
    List<TaskItem>? items,
    int? totalQuestions,
    int? completedCount,
    bool? isCompleted,
    DateTime? createdAt,
    DateTime? completedAt,
  }) => DailyTask(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    taskDate: taskDate ?? this.taskDate,
    items: items ?? this.items,
    totalQuestions: totalQuestions ?? this.totalQuestions,
    completedCount: completedCount ?? this.completedCount,
    isCompleted: isCompleted ?? this.isCompleted,
    createdAt: createdAt ?? this.createdAt,
    completedAt: completedAt ?? this.completedAt,
  );
}

