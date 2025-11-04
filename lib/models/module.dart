import 'subject.dart';

/// 学科模块模型（对应数据库表 knowledge_points_library）
class Module {
  final String id;
  final Subject subject; // 学科
  final String educationLevel; // 教育阶段（middle_school, high_school）
  final List<int>? grades; // 适用年级
  final String name; // 模块名称
  final String? description; // 模块描述
  final int order; // 排序
  final int usageCount; // 使用次数
  final bool isActive; // 是否激活
  
  // 统计数据（从用户知识点聚合）
  final int mistakeCount; // 该模块下的错题总数
  final int knowledgePointCount; // 该模块下的知识点数量
  
  const Module({
    required this.id,
    required this.subject,
    required this.educationLevel,
    this.grades,
    required this.name,
    this.description,
    this.order = 0,
    this.usageCount = 0,
    this.isActive = true,
    this.mistakeCount = 0,
    this.knowledgePointCount = 0,
  });

  /// JSON 序列化（数据库中 subject 字段存储中文名称）
  Map<String, dynamic> toJson() => {
    'subject': subject.displayName, // 使用中文名称以匹配数据库格式
    'educationLevel': educationLevel,
    'grades': grades,
    'name': name,
    'description': description,
    'order': order,
    'usageCount': usageCount,
    'isActive': isActive,
    'mistakeCount': mistakeCount,
    'knowledgePointCount': knowledgePointCount,
  };

  /// JSON 反序列化（从数据库字段）
  factory Module.fromJson(Map<String, dynamic> json) {
    // 处理 subject 字段 - 支持枚举名称或中文显示名
    final subjectStr = json['subject'] as String;
    final subject = Subject.fromString(subjectStr) ?? Subject.math;
    
    // 处理 grades 字段
    List<int>? grades;
    if (json['grades'] != null) {
      if (json['grades'] is List) {
        grades = (json['grades'] as List).map((e) => e as int).toList();
      }
    }
    
    return Module(
      id: json['id'] as String,
      subject: subject,
      educationLevel: json['educationLevel'] as String,
      grades: grades,
      name: json['name'] as String,
      description: json['description'] as String?,
      order: (json['order'] as int?) ?? 0,
      usageCount: (json['usageCount'] as int?) ?? 0,
      isActive: (json['isActive'] as bool?) ?? true,
      mistakeCount: (json['mistakeCount'] as int?) ?? 0,
      knowledgePointCount: (json['knowledgePointCount'] as int?) ?? 0,
    );
  }

  /// 复制并更新
  Module copyWith({
    String? id,
    Subject? subject,
    String? educationLevel,
    List<int>? grades,
    String? name,
    String? description,
    int? order,
    int? usageCount,
    bool? isActive,
    int? mistakeCount,
    int? knowledgePointCount,
  }) => Module(
    id: id ?? this.id,
    subject: subject ?? this.subject,
    educationLevel: educationLevel ?? this.educationLevel,
    grades: grades ?? this.grades,
    name: name ?? this.name,
    description: description ?? this.description,
    order: order ?? this.order,
    usageCount: usageCount ?? this.usageCount,
    isActive: isActive ?? this.isActive,
    mistakeCount: mistakeCount ?? this.mistakeCount,
    knowledgePointCount: knowledgePointCount ?? this.knowledgePointCount,
  );
}

