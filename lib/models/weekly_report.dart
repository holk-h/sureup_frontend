import 'error_reason.dart';
import 'subject.dart';

/// 知识点统计项
class KnowledgePointStats {
  final String knowledgePointId;
  final String knowledgePointName;
  final Subject subject;
  final int mistakeCount;
  final double accuracy;

  const KnowledgePointStats({
    required this.knowledgePointId,
    required this.knowledgePointName,
    required this.subject,
    required this.mistakeCount,
    required this.accuracy,
  });

  Map<String, dynamic> toJson() => {
    'knowledgePointId': knowledgePointId,
    'knowledgePointName': knowledgePointName,
    'subject': subject.name,
    'mistakeCount': mistakeCount,
    'accuracy': accuracy,
  };

  factory KnowledgePointStats.fromJson(Map<String, dynamic> json) =>
      KnowledgePointStats(
        knowledgePointId: json['knowledgePointId'] as String,
        knowledgePointName: json['knowledgePointName'] as String,
        subject: Subject.values.byName(json['subject'] as String),
        mistakeCount: json['mistakeCount'] as int,
        accuracy: json['accuracy'] as double,
      );
}

/// 错因统计
class ErrorReasonStats {
  final ErrorReason reason;
  final int count;
  final double percentage;

  const ErrorReasonStats({
    required this.reason,
    required this.count,
    required this.percentage,
  });

  Map<String, dynamic> toJson() => {
    'reason': reason.name,
    'count': count,
    'percentage': percentage,
  };

  factory ErrorReasonStats.fromJson(Map<String, dynamic> json) =>
      ErrorReasonStats(
        reason: ErrorReason.values.byName(json['reason'] as String),
        count: json['count'] as int,
        percentage: json['percentage'] as double,
      );
}

/// 周报
class WeeklyReport {
  final String id;
  final String userId;
  final DateTime weekStart; // 周一
  final DateTime weekEnd; // 周日
  
  // 基础统计
  final int totalMistakes; // 本周错题总数
  final int totalReviews; // 本周复习次数
  final int totalPracticeSessions; // 本周练习次数
  final double practiceCompletionRate; // 练习完成率
  final double overallAccuracy; // 整体正确率
  
  // TOP数据
  final List<KnowledgePointStats> topMistakePoints; // 错题最多的知识点TOP3
  final List<ErrorReasonStats> errorReasonDistribution; // 错因分布
  
  // AI分析
  final String? aiSummary; // AI生成的总结
  final List<String>? suggestions; // 改进建议
  
  // 时间戳
  final DateTime generatedAt;

  const WeeklyReport({
    required this.id,
    required this.userId,
    required this.weekStart,
    required this.weekEnd,
    required this.totalMistakes,
    required this.totalReviews,
    required this.totalPracticeSessions,
    required this.practiceCompletionRate,
    required this.overallAccuracy,
    required this.topMistakePoints,
    required this.errorReasonDistribution,
    this.aiSummary,
    this.suggestions,
    required this.generatedAt,
  });

  /// JSON 序列化
  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'weekStart': weekStart.toIso8601String(),
    'weekEnd': weekEnd.toIso8601String(),
    'totalMistakes': totalMistakes,
    'totalReviews': totalReviews,
    'totalPracticeSessions': totalPracticeSessions,
    'practiceCompletionRate': practiceCompletionRate,
    'overallAccuracy': overallAccuracy,
    'topMistakePoints': topMistakePoints.map((k) => k.toJson()).toList(),
    'errorReasonDistribution': errorReasonDistribution.map((e) => e.toJson()).toList(),
    'aiSummary': aiSummary,
    'suggestions': suggestions,
    'generatedAt': generatedAt.toIso8601String(),
  };

  /// JSON 反序列化
  factory WeeklyReport.fromJson(Map<String, dynamic> json) => WeeklyReport(
    id: json['id'] as String,
    userId: json['userId'] as String,
    weekStart: DateTime.parse(json['weekStart'] as String).toLocal(),
    weekEnd: DateTime.parse(json['weekEnd'] as String).toLocal(),
    totalMistakes: json['totalMistakes'] as int,
    totalReviews: json['totalReviews'] as int,
    totalPracticeSessions: json['totalPracticeSessions'] as int,
    practiceCompletionRate: json['practiceCompletionRate'] as double,
    overallAccuracy: json['overallAccuracy'] as double,
    topMistakePoints: (json['topMistakePoints'] as List<dynamic>)
        .map((k) => KnowledgePointStats.fromJson(k as Map<String, dynamic>))
        .toList(),
    errorReasonDistribution: (json['errorReasonDistribution'] as List<dynamic>)
        .map((e) => ErrorReasonStats.fromJson(e as Map<String, dynamic>))
        .toList(),
    aiSummary: json['aiSummary'] as String?,
    suggestions: (json['suggestions'] as List<dynamic>?)?.cast<String>(),
    generatedAt: DateTime.parse(json['generatedAt'] as String).toLocal(),
  );

  /// 复制并更新
  WeeklyReport copyWith({
    String? id,
    String? userId,
    DateTime? weekStart,
    DateTime? weekEnd,
    int? totalMistakes,
    int? totalReviews,
    int? totalPracticeSessions,
    double? practiceCompletionRate,
    double? overallAccuracy,
    List<KnowledgePointStats>? topMistakePoints,
    List<ErrorReasonStats>? errorReasonDistribution,
    String? aiSummary,
    List<String>? suggestions,
    DateTime? generatedAt,
  }) => WeeklyReport(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    weekStart: weekStart ?? this.weekStart,
    weekEnd: weekEnd ?? this.weekEnd,
    totalMistakes: totalMistakes ?? this.totalMistakes,
    totalReviews: totalReviews ?? this.totalReviews,
    totalPracticeSessions: totalPracticeSessions ?? this.totalPracticeSessions,
    practiceCompletionRate: practiceCompletionRate ?? this.practiceCompletionRate,
    overallAccuracy: overallAccuracy ?? this.overallAccuracy,
    topMistakePoints: topMistakePoints ?? this.topMistakePoints,
    errorReasonDistribution: errorReasonDistribution ?? this.errorReasonDistribution,
    aiSummary: aiSummary ?? this.aiSummary,
    suggestions: suggestions ?? this.suggestions,
    generatedAt: generatedAt ?? this.generatedAt,
  );
}

