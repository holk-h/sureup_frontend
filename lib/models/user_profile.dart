import 'dart:convert';

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
  final String? dailyTaskDifficulty; // 每日任务难度：'easy' | 'normal' | 'hard'
  
  // 通知偏好
  final bool? dailyTaskReminderEnabled; // 每日任务提醒开关
  final bool? reviewReminderEnabled; // 复习提醒开关
  final String? reviewReminderTime; // 复习提醒时间（格式：HH:mm）
  
  // 时区设置
  final String? timezone; // 用户时区（如 'Asia/Shanghai', 'America/New_York'）
  
  // 统计数据（缓存，定期更新）
  final int totalMistakes; // 总错题数
  final int masteredMistakes; // 已掌握数
  final int totalPracticeSessions; // 总练习次数
  final int completedSessions; // 已完成的练习次数
  final int continuousDays; // 连续学习天数
  final int weekMistakes; // 本周错题数（每周一重置）
  final int activeDays; // 实际学习天数（有活动的天数）
  final int todayPracticeSessions; // 今日练习次数
  final int weekPracticeSessions; // 本周练习次数
  final int todayMistakes; // 今日错题数
  final int totalQuestions; // 总答题数
  final int totalCorrectAnswers; // 总正确答题数
  
  // 图表数据
  final String? weeklyMistakesData; // 过去一周错题数据（JSON格式）
  final String? weeklyReviewData; // 过去一周复习数据（JSON格式）
  
  // 学科掌握度（由后端聚合计算）
  final Map<String, int>? subjectMasteryScores; // 学科掌握度分数，格式: {"数学": 75, "物理": 60}
  
  // 订阅相关
  final String? subscriptionStatus; // 订阅状态：'free' | 'active' | 'expired'
  final DateTime? subscriptionExpiryDate; // 订阅到期时间
  final DateTime? dailyLimitsResetDate; // 每日限制重置日期
  final int? todayMistakeRecords; // 今日错题记录数
  final int? todayAccumulatedAnalysis; // 今日积累分析次数
  
  // 时间戳
  final DateTime createdAt;
  final DateTime? lastActiveAt;
  final DateTime? lastPracticeDate; // 最后练习日期（用于快速计算连续天数）
  final DateTime? statsUpdatedAt; // 统计数据最后更新时间
  final DateTime? lastReviewAt; // 上次AI复盘时间
  final DateTime? lastResetDate; // 上次重置日期（用于每日数据重置）
  
  const UserProfile({
    required this.id,
    required this.name,
    this.avatar,
    this.email,
    this.phone,
    this.grade,
    this.focusSubjects,
    this.dailyTaskDifficulty,
    this.dailyTaskReminderEnabled,
    this.reviewReminderEnabled,
    this.reviewReminderTime,
    this.timezone,
    this.totalMistakes = 0,
    this.masteredMistakes = 0,
    this.totalPracticeSessions = 0,
    this.completedSessions = 0,
    this.continuousDays = 0,
    this.weekMistakes = 0,
    this.activeDays = 0,
    this.todayPracticeSessions = 0,
    this.weekPracticeSessions = 0,
    this.todayMistakes = 0,
    this.totalQuestions = 0,
    this.totalCorrectAnswers = 0,
    this.weeklyMistakesData,
    this.weeklyReviewData,
    this.subjectMasteryScores,
    this.subscriptionStatus,
    this.subscriptionExpiryDate,
    this.dailyLimitsResetDate,
    this.todayMistakeRecords,
    this.todayAccumulatedAnalysis,
    required this.createdAt,
    this.lastActiveAt,
    this.lastPracticeDate,
    this.statsUpdatedAt,
    this.lastReviewAt,
    this.lastResetDate,
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
    'dailyTaskDifficulty': dailyTaskDifficulty,
    'dailyTaskReminderEnabled': dailyTaskReminderEnabled,
    'reviewReminderEnabled': reviewReminderEnabled,
    'reviewReminderTime': reviewReminderTime,
    'timezone': timezone,
    'totalMistakes': totalMistakes,
    'masteredMistakes': masteredMistakes,
    'totalPracticeSessions': totalPracticeSessions,
    'completedSessions': completedSessions,
    'continuousDays': continuousDays,
    'weekMistakes': weekMistakes,
    'activeDays': activeDays,
    'todayPracticeSessions': todayPracticeSessions,
    'weekPracticeSessions': weekPracticeSessions,
    'todayMistakes': todayMistakes,
    'totalQuestions': totalQuestions,
    'totalCorrectAnswers': totalCorrectAnswers,
    'weeklyMistakesData': weeklyMistakesData,
    'weeklyReviewData': weeklyReviewData,
    'subjectMasteryScores': subjectMasteryScores != null ? jsonEncode(subjectMasteryScores) : null,
    'createdAt': createdAt.toIso8601String(),
    'lastActiveAt': lastActiveAt?.toIso8601String(),
    'lastPracticeDate': lastPracticeDate?.toIso8601String(),
    'statsUpdatedAt': statsUpdatedAt?.toIso8601String(),
    'lastReviewAt': lastReviewAt?.toIso8601String(),
    'lastResetDate': lastResetDate?.toIso8601String(),
  };

  /// JSON 反序列化
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    // 处理 weeklyMistakesData - 可能是字符串或已解析的List
    String? weeklyMistakesDataStr;
    final weeklyDataRaw = json['weeklyMistakesData'];
    if (weeklyDataRaw != null) {
      if (weeklyDataRaw is String) {
        weeklyMistakesDataStr = weeklyDataRaw;
      } else if (weeklyDataRaw is List) {
        // 如果已经是List，转换回JSON字符串
        try {
          weeklyMistakesDataStr = jsonEncode(weeklyDataRaw);
        } catch (e) {
          print('⚠️ 转换 weeklyMistakesData 为字符串失败: $e');
        }
      }
    }
    
    // 处理 weeklyReviewData - 可能是字符串或已解析的List
    String? weeklyReviewDataStr;
    final weeklyReviewDataRaw = json['weeklyReviewData'];
    if (weeklyReviewDataRaw != null) {
      if (weeklyReviewDataRaw is String) {
        weeklyReviewDataStr = weeklyReviewDataRaw;
      } else if (weeklyReviewDataRaw is List) {
        // 如果已经是List，转换回JSON字符串
        try {
          weeklyReviewDataStr = jsonEncode(weeklyReviewDataRaw);
        } catch (e) {
          print('⚠️ 转换 weeklyReviewData 为字符串失败: $e');
        }
      }
    }
    
    // 处理 subjectMasteryScores - 从后端同步的学科掌握度
    Map<String, int>? subjectMasteryScores;
    final subjectScoresRaw = json['subjectMasteryScores'];
    if (subjectScoresRaw != null) {
      try {
        if (subjectScoresRaw is String) {
          // 从JSON字符串解析
          final decoded = jsonDecode(subjectScoresRaw) as Map;
          subjectMasteryScores = decoded.map((key, value) => 
            MapEntry(key.toString(), (value as num).toInt())
          );
        } else if (subjectScoresRaw is Map) {
          // 直接是Map对象
          subjectMasteryScores = subjectScoresRaw.map((key, value) => 
            MapEntry(key.toString(), (value as num).toInt())
          );
        }
      } catch (e) {
        print('⚠️ 解析 subjectMasteryScores 失败: $e');
      }
    }
    
    return UserProfile(
    id: json['id'] as String,
    name: json['name'] as String,
    avatar: json['avatar'] as String?,
    email: json['email'] as String?,  // 邮箱
    phone: json['phone'] as String?,  // 手机号
    grade: json['grade'] as int?,
    focusSubjects: (json['focusSubjects'] as List<dynamic>?)?.cast<String>(),
    dailyTaskDifficulty: json['dailyTaskDifficulty'] as String?,
    dailyTaskReminderEnabled: json['dailyTaskReminderEnabled'] as bool?,
    reviewReminderEnabled: json['reviewReminderEnabled'] as bool?,
    reviewReminderTime: json['reviewReminderTime'] as String?,
    timezone: json['timezone'] as String?,
    totalMistakes: (json['totalMistakes'] as int?) ?? 0,
    masteredMistakes: (json['masteredMistakes'] as int?) ?? 0,
    totalPracticeSessions: (json['totalPracticeSessions'] as int?) ?? 0,
    completedSessions: (json['completedSessions'] as int?) ?? 0,
    continuousDays: (json['continuousDays'] as int?) ?? 0,
    weekMistakes: (json['weekMistakes'] as int?) ?? 0,
    activeDays: (json['activeDays'] as int?) ?? 0,
    todayPracticeSessions: (json['todayPracticeSessions'] as int?) ?? 0,
    weekPracticeSessions: (json['weekPracticeSessions'] as int?) ?? 0,
    todayMistakes: (json['todayMistakes'] as int?) ?? 0,
    totalQuestions: (json['totalQuestions'] as int?) ?? 0,
    totalCorrectAnswers: (json['totalCorrectAnswers'] as int?) ?? 0,
      weeklyMistakesData: weeklyMistakesDataStr,
      weeklyReviewData: weeklyReviewDataStr,
      subjectMasteryScores: subjectMasteryScores,
      subscriptionStatus: json['subscriptionStatus'] as String?,
      subscriptionExpiryDate: json['subscriptionExpiryDate'] != null
          ? DateTime.parse(json['subscriptionExpiryDate'] as String).toLocal()
          : null,
      dailyLimitsResetDate: json['dailyLimitsResetDate'] != null
          ? DateTime.parse(json['dailyLimitsResetDate'] as String).toLocal()
          : null,
      todayMistakeRecords: (json['todayMistakeRecords'] as int?) ?? 0,
      todayAccumulatedAnalysis: (json['todayAccumulatedAnalysis'] as int?) ?? 0,
    // 使用 Appwrite 的自动时间戳 $createdAt 作为创建时间
    createdAt: json['createdAt'] != null 
        ? DateTime.parse(json['createdAt'] as String).toLocal()
        : (json['\$createdAt'] != null 
            ? DateTime.parse(json['\$createdAt'] as String).toLocal()
            : DateTime.now()),
    lastActiveAt: json['lastActiveAt'] != null 
        ? DateTime.parse(json['lastActiveAt'] as String).toLocal() 
        : null,
    lastPracticeDate: json['lastPracticeDate'] != null 
        ? DateTime.parse(json['lastPracticeDate'] as String).toLocal() 
        : null,
    statsUpdatedAt: json['statsUpdatedAt'] != null 
        ? DateTime.parse(json['statsUpdatedAt'] as String).toLocal() 
        : null,
    lastReviewAt: json['lastReviewAt'] != null 
        ? DateTime.parse(json['lastReviewAt'] as String).toLocal() 
        : null,
    lastResetDate: json['lastResetDate'] != null 
        ? DateTime.parse(json['lastResetDate'] as String).toLocal() 
        : null,
  );
  }

  /// 复制并更新
  UserProfile copyWith({
    String? id,
    String? name,
    String? avatar,
    String? email,
    String? phone,
    int? grade,
    List<String>? focusSubjects,
    String? dailyTaskDifficulty,
    bool? dailyTaskReminderEnabled,
    bool? reviewReminderEnabled,
    String? reviewReminderTime,
    String? timezone,
    int? totalMistakes,
    int? masteredMistakes,
    int? totalPracticeSessions,
    int? completedSessions,
    int? continuousDays,
    int? weekMistakes,
    int? activeDays,
    int? todayPracticeSessions,
    int? weekPracticeSessions,
    int? todayMistakes,
    int? totalQuestions,
    int? totalCorrectAnswers,
    String? weeklyMistakesData,
    String? weeklyReviewData,
    Map<String, int>? subjectMasteryScores,
    DateTime? createdAt,
    DateTime? lastActiveAt,
    DateTime? lastPracticeDate,
    DateTime? statsUpdatedAt,
    DateTime? lastReviewAt,
    DateTime? lastResetDate,
  }  ) => UserProfile(
    id: id ?? this.id,
    name: name ?? this.name,
    avatar: avatar ?? this.avatar,
    email: email ?? this.email,
    phone: phone ?? this.phone,
    grade: grade ?? this.grade,
    focusSubjects: focusSubjects ?? this.focusSubjects,
    dailyTaskDifficulty: dailyTaskDifficulty ?? this.dailyTaskDifficulty,
    dailyTaskReminderEnabled: dailyTaskReminderEnabled ?? this.dailyTaskReminderEnabled,
    reviewReminderEnabled: reviewReminderEnabled ?? this.reviewReminderEnabled,
    reviewReminderTime: reviewReminderTime ?? this.reviewReminderTime,
    timezone: timezone ?? this.timezone,
    totalMistakes: totalMistakes ?? this.totalMistakes,
    masteredMistakes: masteredMistakes ?? this.masteredMistakes,
    totalPracticeSessions: totalPracticeSessions ?? this.totalPracticeSessions,
    completedSessions: completedSessions ?? this.completedSessions,
    continuousDays: continuousDays ?? this.continuousDays,
    weekMistakes: weekMistakes ?? this.weekMistakes,
    activeDays: activeDays ?? this.activeDays,
    todayPracticeSessions: todayPracticeSessions ?? this.todayPracticeSessions,
    weekPracticeSessions: weekPracticeSessions ?? this.weekPracticeSessions,
    todayMistakes: todayMistakes ?? this.todayMistakes,
    totalQuestions: totalQuestions ?? this.totalQuestions,
    totalCorrectAnswers: totalCorrectAnswers ?? this.totalCorrectAnswers,
    weeklyMistakesData: weeklyMistakesData ?? this.weeklyMistakesData,
    weeklyReviewData: weeklyReviewData ?? this.weeklyReviewData,
    subjectMasteryScores: subjectMasteryScores ?? this.subjectMasteryScores,
    createdAt: createdAt ?? this.createdAt,
    lastActiveAt: lastActiveAt ?? this.lastActiveAt,
    lastPracticeDate: lastPracticeDate ?? this.lastPracticeDate,
    statsUpdatedAt: statsUpdatedAt ?? this.statsUpdatedAt,
    lastReviewAt: lastReviewAt ?? this.lastReviewAt,
    lastResetDate: lastResetDate ?? this.lastResetDate,
  );
}

