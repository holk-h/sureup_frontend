import 'subject.dart';

/// 知识点重要程度枚举
enum KnowledgePointImportance {
  high('high', '高频考点', '考试常考的核心重点'),
  basic('basic', '基础知识', '前置必会的基础内容'),
  normal('normal', '普通考点', '一般重要程度');

  const KnowledgePointImportance(this.value, this.displayName, this.description);
  final String value;
  final String displayName;
  final String description;

  static KnowledgePointImportance fromString(String? value) {
    switch (value) {
      case 'high':
        return KnowledgePointImportance.high;
      case 'basic':
        return KnowledgePointImportance.basic;
      case 'normal':
      default:
        return KnowledgePointImportance.normal;
    }
  }
}

/// 知识点模型（对应数据库表 user_knowledge_points）
class KnowledgePoint {
  final String id;
  final String userId; // 用户ID
  final String moduleId; // 知识点模块ID（关联到 knowledge_points_library）
  final Subject subject; // 学科
  final String name; // 知识点名称
  final String? description; // 知识点描述
  final KnowledgePointImportance importance; // 知识点重要程度（新增）
  
  // 统计数据
  final int mistakeCount; // 错题总数
  final int masteredCount; // 已掌握数量
  final int? masteryScore; // 掌握度分数 (0-100)，由后端从 review_states 同步
  
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
    this.importance = KnowledgePointImportance.normal,
    this.mistakeCount = 0,
    this.masteredCount = 0,
    this.masteryScore,
    this.questionIds = const [],
    this.lastMistakeAt,
  });

  /// 掌握率（0-100）
  /// 优先使用后端计算的 masteryScore，如果没有则回退到简单计算
  int get masteryLevel {
    // 如果有后端同步的 masteryScore，优先使用
    if (masteryScore != null) {
      return masteryScore!;
    }
    
    // 回退到基于错题数和掌握数的简单计算
    // 如果没有错题记录，说明还没有开始学习，返回 0 而不是 100
    if (mistakeCount == 0) return 0;
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
    'importance': importance.value,
    'mistakeCount': mistakeCount,
    'masteredCount': masteredCount,
    'masteryScore': masteryScore,
    'questionIds': questionIds,
    'lastMistakeAt': lastMistakeAt?.toIso8601String(),
  };

  /// JSON 反序列化（从数据库字段）
  factory KnowledgePoint.fromJson(Map<String, dynamic> json) {
    // 处理 subject 字段 - 支持枚举名称或中文显示名
    final subjectStr = json['subject'] as String;
    final subject = Subject.fromString(subjectStr) ?? Subject.math;
    
    // 处理 importance 字段
    final importance = KnowledgePointImportance.fromString(
      json['importance'] as String?
    );
    
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
      importance: importance,
      mistakeCount: (json['mistakeCount'] as int?) ?? 0,
      masteredCount: (json['masteredCount'] as int?) ?? 0,
      masteryScore: json['masteryScore'] as int?,
      questionIds: questionIds,
      lastMistakeAt: json['lastMistakeAt'] != null 
          ? DateTime.parse(json['lastMistakeAt'] as String).toLocal() 
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
    KnowledgePointImportance? importance,
    int? mistakeCount,
    int? masteredCount,
    int? masteryScore,
    List<String>? questionIds,
    DateTime? lastMistakeAt,
  }) => KnowledgePoint(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    moduleId: moduleId ?? this.moduleId,
    subject: subject ?? this.subject,
    name: name ?? this.name,
    description: description ?? this.description,
    importance: importance ?? this.importance,
    mistakeCount: mistakeCount ?? this.mistakeCount,
    masteredCount: masteredCount ?? this.masteredCount,
    masteryScore: masteryScore ?? this.masteryScore,
    questionIds: questionIds ?? this.questionIds,
    lastMistakeAt: lastMistakeAt ?? this.lastMistakeAt,
  );
}
