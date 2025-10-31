/// 用户档案
class UserProfile {
  final String id;
  final String name; // 用户名/昵称
  final String? avatar; // 头像URL
  final String? email;
  final String? phone;
  
  // 学习偏好
  final int? grade; // 年级（如7-12代表初一到高三）
  final List<String>? focusSubjects; // 关注的学科
  
  // 统计数据（缓存，定期更新）
  final int totalMistakes; // 总错题数
  final int masteredMistakes; // 已掌握数
  final int totalPracticeSessions; // 总练习次数
  final int completedSessions; // 已完成的练习次数
  final int continuousDays; // 连续学习天数
  final int weekMistakes; // 本周错题数（每周一重置）
  
  // 时间戳
  final DateTime createdAt;
  final DateTime? lastActiveAt;
  final DateTime? lastPracticeDate; // 最后练习日期（用于快速计算连续天数）
  final DateTime? statsUpdatedAt; // 统计数据最后更新时间
  
  const UserProfile({
    required this.id,
    required this.name,
    this.avatar,
    this.email,
    this.phone,
    this.grade,
    this.focusSubjects,
    this.totalMistakes = 0,
    this.masteredMistakes = 0,
    this.totalPracticeSessions = 0,
    this.completedSessions = 0,
    this.continuousDays = 0,
    this.weekMistakes = 0,
    required this.createdAt,
    this.lastActiveAt,
    this.lastPracticeDate,
    this.statsUpdatedAt,
  });

  /// 掌握率
  double get masteryRate {
    if (totalMistakes == 0) return 0.0;
    return masteredMistakes / totalMistakes;
  }

  /// JSON 序列化
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'avatar': avatar,
    'email': email,
    'phone': phone,
    'grade': grade,
    'focusSubjects': focusSubjects,
    'totalMistakes': totalMistakes,
    'masteredMistakes': masteredMistakes,
    'totalPracticeSessions': totalPracticeSessions,
    'completedSessions': completedSessions,
    'continuousDays': continuousDays,
    'weekMistakes': weekMistakes,
    'createdAt': createdAt.toIso8601String(),
    'lastActiveAt': lastActiveAt?.toIso8601String(),
    'lastPracticeDate': lastPracticeDate?.toIso8601String(),
    'statsUpdatedAt': statsUpdatedAt?.toIso8601String(),
  };

  /// JSON 反序列化
  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    id: json['id'] as String,
    name: json['name'] as String,
    avatar: json['avatar'] as String?,
    email: json['email'] as String?,  // 邮箱
    phone: json['phone'] as String?,  // 手机号
    grade: json['grade'] as int?,
    focusSubjects: (json['focusSubjects'] as List<dynamic>?)?.cast<String>(),
    totalMistakes: (json['totalMistakes'] as int?) ?? 0,
    masteredMistakes: (json['masteredMistakes'] as int?) ?? 0,
    totalPracticeSessions: (json['totalPracticeSessions'] as int?) ?? 0,
    completedSessions: (json['completedSessions'] as int?) ?? 0,
    continuousDays: (json['continuousDays'] as int?) ?? 0,
    weekMistakes: (json['weekMistakes'] as int?) ?? 0,
    // 使用 Appwrite 的自动时间戳 $createdAt 作为创建时间
    createdAt: json['createdAt'] != null 
        ? DateTime.parse(json['createdAt'] as String)
        : (json['\$createdAt'] != null 
            ? DateTime.parse(json['\$createdAt'] as String)
            : DateTime.now()),
    lastActiveAt: json['lastActiveAt'] != null 
        ? DateTime.parse(json['lastActiveAt'] as String) 
        : null,
    lastPracticeDate: json['lastPracticeDate'] != null 
        ? DateTime.parse(json['lastPracticeDate'] as String) 
        : null,
    statsUpdatedAt: json['statsUpdatedAt'] != null 
        ? DateTime.parse(json['statsUpdatedAt'] as String) 
        : null,
  );

  /// 复制并更新
  UserProfile copyWith({
    String? id,
    String? name,
    String? avatar,
    String? email,
    String? phone,
    int? grade,
    List<String>? focusSubjects,
    int? totalMistakes,
    int? masteredMistakes,
    int? totalPracticeSessions,
    int? completedSessions,
    int? continuousDays,
    int? weekMistakes,
    DateTime? createdAt,
    DateTime? lastActiveAt,
    DateTime? lastPracticeDate,
    DateTime? statsUpdatedAt,
  }) => UserProfile(
    id: id ?? this.id,
    name: name ?? this.name,
    avatar: avatar ?? this.avatar,
    email: email ?? this.email,
    phone: phone ?? this.phone,
    grade: grade ?? this.grade,
    focusSubjects: focusSubjects ?? this.focusSubjects,
    totalMistakes: totalMistakes ?? this.totalMistakes,
    masteredMistakes: masteredMistakes ?? this.masteredMistakes,
    totalPracticeSessions: totalPracticeSessions ?? this.totalPracticeSessions,
    completedSessions: completedSessions ?? this.completedSessions,
    continuousDays: continuousDays ?? this.continuousDays,
    weekMistakes: weekMistakes ?? this.weekMistakes,
    createdAt: createdAt ?? this.createdAt,
    lastActiveAt: lastActiveAt ?? this.lastActiveAt,
    lastPracticeDate: lastPracticeDate ?? this.lastPracticeDate,
    statsUpdatedAt: statsUpdatedAt ?? this.statsUpdatedAt,
  );
}

