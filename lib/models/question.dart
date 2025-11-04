import 'subject.dart';

/// 题目类型
enum QuestionType {
  choice('选择题'),
  fillBlank('填空题'),
  shortAnswer('简答题'),
  calculation('计算题'),
  prove('证明题');

  const QuestionType(this.displayName);
  final String displayName;
}

/// 题目难度
enum Difficulty {
  veryEasy(1, '很简单'),
  easy(2, '简单'),
  medium(3, '中等'),
  hard(4, '困难'),
  veryHard(5, '很难');

  const Difficulty(this.level, this.displayName);
  final int level;
  final String displayName;
}

/// 题目模型（统一的题目实体，适用于错题和练习题）
class Question {
  final String id;
  final Subject subject;
  
  // 支持多模块和多知识点
  final List<String> moduleIds; // 关联模块ID列表（支持综合题）
  final List<String> knowledgePointIds; // 关联知识点ID列表
  
  // 以下为兼容性保留（实际使用列表中的第一个）
  @Deprecated('Use knowledgePointIds instead')
  String get knowledgePointId => knowledgePointIds.isNotEmpty ? knowledgePointIds.first : '';
  @Deprecated('Use knowledgePointNames instead')
  String get knowledgePointName => ''; // 已移除存储，需从知识点服务获取
  
  final QuestionType type;
  final Difficulty difficulty;
  
  // 题目内容
  final String content; // 题目正文
  final List<String>? options; // 选项（选择题使用）
  final String? answer; // 答案
  final String? explanation; // 解析
  final List<String>? imageIds; // 题目图片文件ID（支持多张，存储在bucket中）
  
  // 元数据
  final DateTime createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic>? metadata; // 扩展字段

  const Question({
    required this.id,
    required this.subject,
    required this.moduleIds,
    required this.knowledgePointIds,
    required this.type,
    required this.difficulty,
    required this.content,
    this.options,
    this.answer,
    this.explanation,
    this.imageIds,
    required this.createdAt,
    this.updatedAt,
    this.metadata,
  });

  /// 是否为综合题（跨多个模块）
  bool get isComprehensive => moduleIds.length > 1;

  /// JSON 序列化
  Map<String, dynamic> toJson() => {
    'id': id,
    'subject': subject.name,
    'moduleIds': moduleIds,
    'knowledgePointIds': knowledgePointIds,
    'type': type.name,
    'difficulty': difficulty.level,
    'content': content,
    'options': options,
    'answer': answer,
    'explanation': explanation,
    'imageIds': imageIds,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
    'metadata': metadata,
  };

  /// JSON 反序列化
  factory Question.fromJson(Map<String, dynamic> json) {
    // 处理 moduleIds - 支持旧格式
    List<String> moduleIds = [];
    if (json['moduleIds'] is List) {
      moduleIds = (json['moduleIds'] as List<dynamic>).cast<String>();
    } else if (json['moduleId'] != null) {
      // 兼容旧的单个 moduleId 字段
      moduleIds = [json['moduleId'] as String];
    }
    
    // 处理 knowledgePointIds - 支持旧格式
    List<String> knowledgePointIds = [];
    if (json['knowledgePointIds'] is List) {
      knowledgePointIds = (json['knowledgePointIds'] as List<dynamic>).cast<String>();
    } else if (json['knowledgePointId'] != null) {
      // 兼容旧的单个 knowledgePointId 字段
      knowledgePointIds = [json['knowledgePointId'] as String];
    }
    
    return Question(
      id: json['id'] as String? ?? json['\$id'] as String,
    subject: Subject.values.byName(json['subject'] as String),
      moduleIds: moduleIds,
      knowledgePointIds: knowledgePointIds,
    type: QuestionType.values.byName(json['type'] as String),
    difficulty: Difficulty.values.firstWhere((d) => d.level == json['difficulty']),
    content: json['content'] as String,
    options: (json['options'] as List<dynamic>?)?.cast<String>(),
    answer: json['answer'] as String?,
    explanation: json['explanation'] as String?,
    imageIds: (json['imageIds'] as List<dynamic>?)?.cast<String>(),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : (json['\$createdAt'] != null
              ? DateTime.parse(json['\$createdAt'] as String)
              : DateTime.now()),
    updatedAt: json['updatedAt'] != null 
        ? DateTime.parse(json['updatedAt'] as String) 
        : null,
    metadata: json['metadata'] as Map<String, dynamic>?,
  );
  }

  /// 复制并更新
  Question copyWith({
    String? id,
    Subject? subject,
    List<String>? moduleIds,
    List<String>? knowledgePointIds,
    QuestionType? type,
    Difficulty? difficulty,
    String? content,
    List<String>? options,
    String? answer,
    String? explanation,
    List<String>? imageIds,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? metadata,
  }) => Question(
    id: id ?? this.id,
    subject: subject ?? this.subject,
    moduleIds: moduleIds ?? this.moduleIds,
    knowledgePointIds: knowledgePointIds ?? this.knowledgePointIds,
    type: type ?? this.type,
    difficulty: difficulty ?? this.difficulty,
    content: content ?? this.content,
    options: options ?? this.options,
    answer: answer ?? this.answer,
    explanation: explanation ?? this.explanation,
    imageIds: imageIds ?? this.imageIds,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    metadata: metadata ?? this.metadata,
  );
}
