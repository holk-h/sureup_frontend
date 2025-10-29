import 'subject.dart';

/// 知识点模型（聚合数据，通常从错题记录计算得出）
class KnowledgePoint {
  final String id;
  final Subject subject;
  final String name; // 知识点名称
  final String? parentId; // 父知识点ID（支持层级结构）
  final int level; // 层级（1=一级知识点，2=二级...）
  
  // 统计数据（可从MistakeRecord聚合计算）
  final int mistakeCount; // 错题总数
  final int masteredCount; // 已掌握数量
  final int reviewCount; // 复习总次数
  final int correctCount; // 正确总次数
  
  // 时间信息
  final DateTime? firstMistakeAt; // 第一次错题时间
  final DateTime? lastMistakeAt; // 最近错题时间
  final DateTime? lastReviewAt; // 最近复习时间
  
  const KnowledgePoint({
    required this.id,
    required this.subject,
    required this.name,
    this.parentId,
    this.level = 1,
    this.mistakeCount = 0,
    this.masteredCount = 0,
    this.reviewCount = 0,
    this.correctCount = 0,
    this.firstMistakeAt,
    this.lastMistakeAt,
    this.lastReviewAt,
  });

  /// 掌握率（0-100）
  int get masteryLevel {
    if (mistakeCount == 0) return 100;
    return ((masteredCount / mistakeCount) * 100).round();
  }

  /// 练习正确率（0-1）
  double get accuracy {
    if (reviewCount == 0) return 0.0;
    return correctCount / reviewCount;
  }

  /// 是否需要重点复习
  bool get needsReview {
    return mistakeCount > 0 && 
           masteryLevel < 80 && 
           (lastReviewAt == null || 
            DateTime.now().difference(lastReviewAt!) > const Duration(days: 3));
  }

  /// JSON 序列化
  Map<String, dynamic> toJson() => {
    'id': id,
    'subject': subject.name,
    'name': name,
    'parentId': parentId,
    'level': level,
    'mistakeCount': mistakeCount,
    'masteredCount': masteredCount,
    'reviewCount': reviewCount,
    'correctCount': correctCount,
    'firstMistakeAt': firstMistakeAt?.toIso8601String(),
    'lastMistakeAt': lastMistakeAt?.toIso8601String(),
    'lastReviewAt': lastReviewAt?.toIso8601String(),
  };

  /// JSON 反序列化
  factory KnowledgePoint.fromJson(Map<String, dynamic> json) => KnowledgePoint(
    id: json['id'] as String,
    subject: Subject.values.byName(json['subject'] as String),
    name: json['name'] as String,
    parentId: json['parentId'] as String?,
    level: json['level'] as int,
    mistakeCount: json['mistakeCount'] as int,
    masteredCount: json['masteredCount'] as int,
    reviewCount: json['reviewCount'] as int,
    correctCount: json['correctCount'] as int,
    firstMistakeAt: json['firstMistakeAt'] != null 
        ? DateTime.parse(json['firstMistakeAt'] as String) 
        : null,
    lastMistakeAt: json['lastMistakeAt'] != null 
        ? DateTime.parse(json['lastMistakeAt'] as String) 
        : null,
    lastReviewAt: json['lastReviewAt'] != null 
        ? DateTime.parse(json['lastReviewAt'] as String) 
        : null,
  );

  /// 复制并更新
  KnowledgePoint copyWith({
    String? id,
    Subject? subject,
    String? name,
    String? parentId,
    int? level,
    int? mistakeCount,
    int? masteredCount,
    int? reviewCount,
    int? correctCount,
    DateTime? firstMistakeAt,
    DateTime? lastMistakeAt,
    DateTime? lastReviewAt,
  }) => KnowledgePoint(
    id: id ?? this.id,
    subject: subject ?? this.subject,
    name: name ?? this.name,
    parentId: parentId ?? this.parentId,
    level: level ?? this.level,
    mistakeCount: mistakeCount ?? this.mistakeCount,
    masteredCount: masteredCount ?? this.masteredCount,
    reviewCount: reviewCount ?? this.reviewCount,
    correctCount: correctCount ?? this.correctCount,
    firstMistakeAt: firstMistakeAt ?? this.firstMistakeAt,
    lastMistakeAt: lastMistakeAt ?? this.lastMistakeAt,
    lastReviewAt: lastReviewAt ?? this.lastReviewAt,
  );
}
