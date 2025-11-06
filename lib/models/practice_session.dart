import 'subject.dart';

/// 练习类型
enum PracticeType {
  dailyReview('智能复盘'),
  mistakeDrill('错题变式'),
  knowledgePointDrill('知识点专项'),
  custom('自定义练习');

  const PracticeType(this.displayName);
  final String displayName;
}

/// 单题练习记录
class QuestionResult {
  final String questionId;
  final String? userAnswer; // 用户答案
  final bool isCorrect; // 是否正确
  final int timeSpent; // 答题用时（秒）
  final DateTime answeredAt; // 答题时间

  const QuestionResult({
    required this.questionId,
    this.userAnswer,
    required this.isCorrect,
    this.timeSpent = 0,
    required this.answeredAt,
  });

  Map<String, dynamic> toJson() => {
    'questionId': questionId,
    'userAnswer': userAnswer,
    'isCorrect': isCorrect,
    'timeSpent': timeSpent,
    'answeredAt': answeredAt.toIso8601String(),
  };

  factory QuestionResult.fromJson(Map<String, dynamic> json) => QuestionResult(
    questionId: json['questionId'] as String,
    userAnswer: json['userAnswer'] as String?,
    isCorrect: json['isCorrect'] as bool,
    timeSpent: json['timeSpent'] as int,
    answeredAt: DateTime.parse(json['answeredAt'] as String),
  );
}

/// 练习会话
class PracticeSession {
  final String id;
  final String userId;
  final PracticeType type;
  final Subject? subject; // 可选，跨学科练习时为null
  final String? knowledgePointId; // 知识点专项练习时使用
  
  // 练习内容
  final String title; // 如 "今日复盘"、"二次函数·举一反三"
  final String? subtitle; // 如 "基于你的3道错题生成"
  final List<String> questionIds; // 题目ID列表
  final List<QuestionResult> results; // 答题结果
  
  // 状态
  final DateTime startedAt;
  final DateTime? completedAt;
  final bool isCompleted;
  
  // AI反馈
  final String? aiAnalysis; // AI分析
  final String? aiEncouragement; // AI鼓励语
  
  // 每日任务相关
  final String? dailyTaskId; // 关联的每日任务ID
  final String? taskItemId; // 关联的任务项ID
  final String? userFeedback; // 用户反馈（完全掌握/基本会了/还不会）
  
  const PracticeSession({
    required this.id,
    required this.userId,
    required this.type,
    this.subject,
    this.knowledgePointId,
    required this.title,
    this.subtitle,
    required this.questionIds,
    this.results = const [],
    required this.startedAt,
    this.completedAt,
    this.isCompleted = false,
    this.aiAnalysis,
    this.aiEncouragement,
    this.dailyTaskId,
    this.taskItemId,
    this.userFeedback,
  });

  /// 进度（已完成题数 / 总题数）
  double get progress {
    if (questionIds.isEmpty) return 0.0;
    return results.length / questionIds.length;
  }

  /// 正确率
  double get accuracy {
    if (results.isEmpty) return 0.0;
    final correctCount = results.where((r) => r.isCorrect).length;
    return correctCount / results.length;
  }

  /// 正确题数
  int get correctCount => results.where((r) => r.isCorrect).length;

  /// 错误题数
  int get wrongCount => results.where((r) => !r.isCorrect).length;

  /// 总题数
  int get totalCount => questionIds.length;

  /// 总用时（分钟）
  int get totalTimeMinutes {
    final totalSeconds = results.fold<int>(0, (sum, r) => sum + r.timeSpent);
    return (totalSeconds / 60).ceil();
  }

  /// JSON 序列化
  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'type': type.name,
    'subject': subject?.name,
    'knowledgePointId': knowledgePointId,
    'title': title,
    'subtitle': subtitle,
    'questionIds': questionIds,
    'results': results.map((r) => r.toJson()).toList(),
    'startedAt': startedAt.toIso8601String(),
    'completedAt': completedAt?.toIso8601String(),
    'isCompleted': isCompleted,
    'aiAnalysis': aiAnalysis,
    'aiEncouragement': aiEncouragement,
    'dailyTaskId': dailyTaskId,
    'taskItemId': taskItemId,
    'userFeedback': userFeedback,
  };

  /// JSON 反序列化
  factory PracticeSession.fromJson(Map<String, dynamic> json) => PracticeSession(
    id: json['id'] as String,
    userId: json['userId'] as String,
    type: PracticeType.values.byName(json['type'] as String),
    subject: json['subject'] != null 
        ? Subject.values.byName(json['subject'] as String) 
        : null,
    knowledgePointId: json['knowledgePointId'] as String?,
    title: json['title'] as String,
    subtitle: json['subtitle'] as String?,
    questionIds: (json['questionIds'] as List<dynamic>).cast<String>(),
    results: (json['results'] as List<dynamic>)
        .map((r) => QuestionResult.fromJson(r as Map<String, dynamic>))
        .toList(),
    startedAt: DateTime.parse(json['startedAt'] as String),
    completedAt: json['completedAt'] != null 
        ? DateTime.parse(json['completedAt'] as String) 
        : null,
    isCompleted: json['isCompleted'] as bool,
    aiAnalysis: json['aiAnalysis'] as String?,
    aiEncouragement: json['aiEncouragement'] as String?,
    dailyTaskId: json['dailyTaskId'] as String?,
    taskItemId: json['taskItemId'] as String?,
    userFeedback: json['userFeedback'] as String?,
  );

  /// 复制并更新
  PracticeSession copyWith({
    String? id,
    String? userId,
    PracticeType? type,
    Subject? subject,
    String? knowledgePointId,
    String? title,
    String? subtitle,
    List<String>? questionIds,
    List<QuestionResult>? results,
    DateTime? startedAt,
    DateTime? completedAt,
    bool? isCompleted,
    String? aiAnalysis,
    String? aiEncouragement,
    String? dailyTaskId,
    String? taskItemId,
    String? userFeedback,
  }) => PracticeSession(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    type: type ?? this.type,
    subject: subject ?? this.subject,
    knowledgePointId: knowledgePointId ?? this.knowledgePointId,
    title: title ?? this.title,
    subtitle: subtitle ?? this.subtitle,
    questionIds: questionIds ?? this.questionIds,
    results: results ?? this.results,
    startedAt: startedAt ?? this.startedAt,
    completedAt: completedAt ?? this.completedAt,
    isCompleted: isCompleted ?? this.isCompleted,
    aiAnalysis: aiAnalysis ?? this.aiAnalysis,
    aiEncouragement: aiEncouragement ?? this.aiEncouragement,
    dailyTaskId: dailyTaskId ?? this.dailyTaskId,
    taskItemId: taskItemId ?? this.taskItemId,
    userFeedback: userFeedback ?? this.userFeedback,
  );
}
