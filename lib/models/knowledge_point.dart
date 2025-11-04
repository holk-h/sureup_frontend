import 'subject.dart';

/// 知识点模型（对应数据库表 user_knowledge_points）
class KnowledgePoint {
  final String id;
  final String userId; // 用户ID
  final String moduleId; // 知识点模块ID（关联到 knowledge_points_library）
  final Subject subject; // 学科
  final String name; // 知识点名称
  final String? description; // 知识点描述
  
  // 统计数据
  final int mistakeCount; // 错题总数
  final int masteredCount; // 已掌握数量
  
  // 关联数据
  final List<String> questionIds; // 关联的题目ID列表
  
  // 时间信息
  final DateTime? lastMistakeAt; // 最近错题时间
  
  const KnowledgePoint({
    required this.id,
    required this.userId,
    required this.moduleId,
    required this.subject,
    required this.name,
    this.description,
    this.mistakeCount = 0,
    this.masteredCount = 0,
    this.questionIds = const [],
    this.lastMistakeAt,
  });

  /// 掌握率（0-100）
  int get masteryLevel {
    if (mistakeCount == 0) return 100;
    return ((masteredCount / mistakeCount) * 100).round();
  }

  /// 是否需要重点复习（掌握率低于80%）
  bool get needsReview {
    return mistakeCount > 0 && masteryLevel < 80;
  }

  /// JSON 序列化（数据库中 subject 字段存储中文名称）
  Map<String, dynamic> toJson() => {
    'userId': userId,
    'moduleId': moduleId,
    'subject': subject.displayName, // 使用中文名称以匹配数据库格式
    'name': name,
    'description': description,
    'mistakeCount': mistakeCount,
    'masteredCount': masteredCount,
    'questionIds': questionIds,
    'lastMistakeAt': lastMistakeAt?.toIso8601String(),
  };

  /// JSON 反序列化（从数据库字段）
  factory KnowledgePoint.fromJson(Map<String, dynamic> json) {
    // 处理 subject 字段 - 支持枚举名称或中文显示名
    final subjectStr = json['subject'] as String;
    final subject = Subject.fromString(subjectStr) ?? Subject.math;
    
    // 处理 questionIds 字段
    List<String> questionIds = [];
    if (json['questionIds'] != null) {
      if (json['questionIds'] is List) {
        questionIds = (json['questionIds'] as List)
            .map((e) => e as String)
            .toList();
      }
    }
    
    return KnowledgePoint(
      id: json['id'] as String,
      userId: json['userId'] as String,
      moduleId: json['moduleId'] as String,
      subject: subject,
      name: json['name'] as String,
      description: json['description'] as String?,
      mistakeCount: (json['mistakeCount'] as int?) ?? 0,
      masteredCount: (json['masteredCount'] as int?) ?? 0,
      questionIds: questionIds,
      lastMistakeAt: json['lastMistakeAt'] != null 
          ? DateTime.parse(json['lastMistakeAt'] as String) 
          : null,
    );
  }

  /// 复制并更新
  KnowledgePoint copyWith({
    String? id,
    String? userId,
    String? moduleId,
    Subject? subject,
    String? name,
    String? description,
    int? mistakeCount,
    int? masteredCount,
    List<String>? questionIds,
    DateTime? lastMistakeAt,
  }) => KnowledgePoint(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    moduleId: moduleId ?? this.moduleId,
    subject: subject ?? this.subject,
    name: name ?? this.name,
    description: description ?? this.description,
    mistakeCount: mistakeCount ?? this.mistakeCount,
    masteredCount: masteredCount ?? this.masteredCount,
    questionIds: questionIds ?? this.questionIds,
    lastMistakeAt: lastMistakeAt ?? this.lastMistakeAt,
  );
}
