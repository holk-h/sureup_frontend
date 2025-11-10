/// 题目生成任务状态
enum QuestionGenerationTaskStatus {
  pending,
  processing,
  completed,
  failed,
}

/// 题目生成任务类型
enum QuestionGenerationTaskType {
  variant, // 变式题
}

/// 题目生成任务模型
class QuestionGenerationTask {
  /// 任务 ID
  final String id;

  /// 用户 ID
  final String userId;

  /// 任务类型
  final QuestionGenerationTaskType type;

  /// 任务状态
  final QuestionGenerationTaskStatus status;

  /// 源题目 ID 列表
  final List<String> sourceQuestionIds;

  /// 生成的题目 ID 列表
  final List<String>? generatedQuestionIds;

  /// 每题生成的变式数量
  final int variantsPerQuestion;

  /// 总题目数
  final int totalCount;

  /// 已完成数量
  final int completedCount;

  /// 错误信息
  final String? error;

  /// 开始时间
  final DateTime? startedAt;

  /// 完成时间
  final DateTime? completedAt;

  /// Worker 任务 ID
  final String? workerTaskId;

  /// 创建时间
  final DateTime createdAt;

  /// 更新时间
  final DateTime updatedAt;

  QuestionGenerationTask({
    required this.id,
    required this.userId,
    required this.type,
    required this.status,
    required this.sourceQuestionIds,
    this.generatedQuestionIds,
    this.variantsPerQuestion = 1,
    this.totalCount = 0,
    this.completedCount = 0,
    this.error,
    this.startedAt,
    this.completedAt,
    this.workerTaskId,
    required this.createdAt,
    required this.updatedAt,
  });

  /// 从 JSON 创建
  factory QuestionGenerationTask.fromJson(Map<String, dynamic> json) {
    return QuestionGenerationTask(
      id: json['\$id'] as String,
      userId: json['userId'] as String,
      type: _typeFromString(json['type'] as String? ?? 'variant'),
      status: _statusFromString(json['status'] as String? ?? 'pending'),
      sourceQuestionIds: (json['sourceQuestionIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      generatedQuestionIds: (json['generatedQuestionIds'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      variantsPerQuestion: json['variantsPerQuestion'] as int? ?? 1,
      totalCount: json['totalCount'] as int? ?? 0,
      completedCount: json['completedCount'] as int? ?? 0,
      error: json['error'] as String?,
      startedAt: json['startedAt'] != null
          ? DateTime.parse(json['startedAt'] as String).toLocal()
          : null,
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String).toLocal()
          : null,
      workerTaskId: json['workerTaskId'] as String?,
      createdAt: json['\$createdAt'] != null
          ? DateTime.parse(json['\$createdAt'] as String).toLocal()
          : DateTime.now(),
      updatedAt: json['\$updatedAt'] != null
          ? DateTime.parse(json['\$updatedAt'] as String).toLocal()
          : DateTime.now(),
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      '\$id': id,
      'userId': userId,
      'type': _typeToString(type),
      'status': _statusToString(status),
      'sourceQuestionIds': sourceQuestionIds,
      'generatedQuestionIds': generatedQuestionIds,
      'variantsPerQuestion': variantsPerQuestion,
      'totalCount': totalCount,
      'completedCount': completedCount,
      'error': error,
      'startedAt': startedAt?.toUtc().toIso8601String(),
      'completedAt': completedAt?.toUtc().toIso8601String(),
      'workerTaskId': workerTaskId,
      '\$createdAt': createdAt.toUtc().toIso8601String(),
      '\$updatedAt': updatedAt.toUtc().toIso8601String(),
    };
  }

  /// 从字符串转换为任务类型
  static QuestionGenerationTaskType _typeFromString(String type) {
    switch (type) {
      case 'variant':
        return QuestionGenerationTaskType.variant;
      default:
        return QuestionGenerationTaskType.variant;
    }
  }

  /// 任务类型转换为字符串
  static String _typeToString(QuestionGenerationTaskType type) {
    switch (type) {
      case QuestionGenerationTaskType.variant:
        return 'variant';
    }
  }

  /// 从字符串转换为任务状态
  static QuestionGenerationTaskStatus _statusFromString(String status) {
    switch (status) {
      case 'pending':
        return QuestionGenerationTaskStatus.pending;
      case 'processing':
        return QuestionGenerationTaskStatus.processing;
      case 'completed':
        return QuestionGenerationTaskStatus.completed;
      case 'failed':
        return QuestionGenerationTaskStatus.failed;
      default:
        return QuestionGenerationTaskStatus.pending;
    }
  }

  /// 任务状态转换为字符串
  static String _statusToString(QuestionGenerationTaskStatus status) {
    switch (status) {
      case QuestionGenerationTaskStatus.pending:
        return 'pending';
      case QuestionGenerationTaskStatus.processing:
        return 'processing';
      case QuestionGenerationTaskStatus.completed:
        return 'completed';
      case QuestionGenerationTaskStatus.failed:
        return 'failed';
    }
  }

  /// 是否完成（成功或失败）
  bool get isFinished =>
      status == QuestionGenerationTaskStatus.completed ||
      status == QuestionGenerationTaskStatus.failed;

  /// 是否成功
  bool get isSuccess => status == QuestionGenerationTaskStatus.completed;

  /// 是否失败
  bool get isFailed => status == QuestionGenerationTaskStatus.failed;

  /// 是否处理中
  bool get isProcessing => status == QuestionGenerationTaskStatus.processing;

  /// 是否待处理
  bool get isPending => status == QuestionGenerationTaskStatus.pending;

  /// 进度百分比（0-100）
  double get progress {
    if (totalCount == 0) return 0.0;
    return (completedCount / totalCount * 100).clamp(0.0, 100.0);
  }

  /// 任务类型描述
  String get typeDescription {
    switch (type) {
      case QuestionGenerationTaskType.variant:
        return '变式题生成';
    }
  }

  /// 状态描述
  String get statusDescription {
    switch (status) {
      case QuestionGenerationTaskStatus.pending:
        return '等待处理';
      case QuestionGenerationTaskStatus.processing:
        return '生成中';
      case QuestionGenerationTaskStatus.completed:
        return '已完成';
      case QuestionGenerationTaskStatus.failed:
        return '失败';
    }
  }

  /// 复制并修改部分字段
  QuestionGenerationTask copyWith({
    String? id,
    String? userId,
    QuestionGenerationTaskType? type,
    QuestionGenerationTaskStatus? status,
    List<String>? sourceQuestionIds,
    List<String>? generatedQuestionIds,
    int? variantsPerQuestion,
    int? totalCount,
    int? completedCount,
    String? error,
    DateTime? startedAt,
    DateTime? completedAt,
    String? workerTaskId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return QuestionGenerationTask(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      status: status ?? this.status,
      sourceQuestionIds: sourceQuestionIds ?? this.sourceQuestionIds,
      generatedQuestionIds: generatedQuestionIds ?? this.generatedQuestionIds,
      variantsPerQuestion: variantsPerQuestion ?? this.variantsPerQuestion,
      totalCount: totalCount ?? this.totalCount,
      completedCount: completedCount ?? this.completedCount,
      error: error ?? this.error,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      workerTaskId: workerTaskId ?? this.workerTaskId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

