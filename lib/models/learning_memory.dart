/// 学习记忆（用户薄弱点记录）
class LearningMemory {
  final String id;
  final String userId;
  final List<String> weakPoints; // 用户提到的问题，例如：["不知道应用场景", "列式后不会解"]
  
  final DateTime createdAt;
  final DateTime? updatedAt;

  const LearningMemory({
    required this.id,
    required this.userId,
    this.weakPoints = const [],
    required this.createdAt,
    this.updatedAt,
  });

  /// 是否有薄弱点
  bool get hasWeakPoints => weakPoints.isNotEmpty;

  /// JSON 序列化
  Map<String, dynamic> toJson() => {
    'userId': userId,
    'weakPoints': weakPoints,
  };

  /// JSON 反序列化
  factory LearningMemory.fromJson(Map<String, dynamic> json) => LearningMemory(
    id: json['id'] as String? ?? json['\$id'] as String,
    userId: json['userId'] as String,
    weakPoints: (json['weakPoints'] as List<dynamic>?)?.cast<String>() ?? [],
    createdAt: json['createdAt'] != null
        ? DateTime.parse(json['createdAt'] as String).toLocal()
        : (json['\$createdAt'] != null
            ? DateTime.parse(json['\$createdAt'] as String).toLocal()
            : DateTime.now()),
    updatedAt: json['updatedAt'] != null
        ? DateTime.parse(json['updatedAt'] as String).toLocal()
        : (json['\$updatedAt'] != null
            ? DateTime.parse(json['\$updatedAt'] as String).toLocal()
            : null),
  );

  /// 复制并更新
  LearningMemory copyWith({
    String? id,
    String? userId,
    List<String>? weakPoints,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => LearningMemory(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    weakPoints: weakPoints ?? this.weakPoints,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}

