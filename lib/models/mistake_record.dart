import 'error_reason.dart';
import 'subject.dart';

/// 掌握状态
enum MasteryStatus {
  notStarted('未开始'),
  practicing('练习中'),
  mastered('已掌握');

  const MasteryStatus(this.displayName);
  final String displayName;
}

/// 错题记录（用户与题目的关联记录）
class MistakeRecord {
  final String id;
  final String userId; // 用户ID
  final String questionId; // 关联题目ID
  
  // 冗余字段（方便查询和显示，避免频繁join）
  final Subject subject;
  final String knowledgePointId;
  final String knowledgePointName;
  
  // 错题信息
  final ErrorReason errorReason;
  final String? note; // 用户备注
  final String? userAnswer; // 用户的错误答案
  
  // 状态
  final MasteryStatus masteryStatus;
  final int reviewCount; // 复习次数
  final int correctCount; // 正确次数
  
  // 原始图片（拍照录入的）
  final List<String>? originalImageUrls;
  
  // 时间戳
  final DateTime createdAt; // 错题时间
  final DateTime? lastReviewAt; // 最后复习时间
  final DateTime? masteredAt; // 掌握时间

  const MistakeRecord({
    required this.id,
    required this.userId,
    required this.questionId,
    required this.subject,
    required this.knowledgePointId,
    required this.knowledgePointName,
    required this.errorReason,
    this.note,
    this.userAnswer,
    this.masteryStatus = MasteryStatus.notStarted,
    this.reviewCount = 0,
    this.correctCount = 0,
    this.originalImageUrls,
    required this.createdAt,
    this.lastReviewAt,
    this.masteredAt,
  });

  /// 掌握率（正确次数/复习次数）
  double get masteryRate {
    if (reviewCount == 0) return 0.0;
    return correctCount / reviewCount;
  }

  /// JSON 序列化
  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'questionId': questionId,
    'subject': subject.name,
    'knowledgePointId': knowledgePointId,
    'knowledgePointName': knowledgePointName,
    'errorReason': errorReason.name,
    'note': note,
    'userAnswer': userAnswer,
    'masteryStatus': masteryStatus.name,
    'reviewCount': reviewCount,
    'correctCount': correctCount,
    'originalImageUrls': originalImageUrls,
    'createdAt': createdAt.toIso8601String(),
    'lastReviewAt': lastReviewAt?.toIso8601String(),
    'masteredAt': masteredAt?.toIso8601String(),
  };

  /// JSON 反序列化
  factory MistakeRecord.fromJson(Map<String, dynamic> json) => MistakeRecord(
    id: json['id'] as String,
    userId: json['userId'] as String,
    questionId: json['questionId'] as String,
    subject: Subject.values.byName(json['subject'] as String),
    knowledgePointId: json['knowledgePointId'] as String,
    knowledgePointName: json['knowledgePointName'] as String,
    errorReason: ErrorReason.values.byName(json['errorReason'] as String),
    note: json['note'] as String?,
    userAnswer: json['userAnswer'] as String?,
    masteryStatus: MasteryStatus.values.byName(json['masteryStatus'] as String),
    reviewCount: json['reviewCount'] as int,
    correctCount: json['correctCount'] as int,
    originalImageUrls: (json['originalImageUrls'] as List<dynamic>?)?.cast<String>(),
    createdAt: DateTime.parse(json['createdAt'] as String),
    lastReviewAt: json['lastReviewAt'] != null 
        ? DateTime.parse(json['lastReviewAt'] as String) 
        : null,
    masteredAt: json['masteredAt'] != null 
        ? DateTime.parse(json['masteredAt'] as String) 
        : null,
  );

  /// 复制并更新
  MistakeRecord copyWith({
    String? id,
    String? userId,
    String? questionId,
    Subject? subject,
    String? knowledgePointId,
    String? knowledgePointName,
    ErrorReason? errorReason,
    String? note,
    String? userAnswer,
    MasteryStatus? masteryStatus,
    int? reviewCount,
    int? correctCount,
    List<String>? originalImageUrls,
    DateTime? createdAt,
    DateTime? lastReviewAt,
    DateTime? masteredAt,
  }) => MistakeRecord(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    questionId: questionId ?? this.questionId,
    subject: subject ?? this.subject,
    knowledgePointId: knowledgePointId ?? this.knowledgePointId,
    knowledgePointName: knowledgePointName ?? this.knowledgePointName,
    errorReason: errorReason ?? this.errorReason,
    note: note ?? this.note,
    userAnswer: userAnswer ?? this.userAnswer,
    masteryStatus: masteryStatus ?? this.masteryStatus,
    reviewCount: reviewCount ?? this.reviewCount,
    correctCount: correctCount ?? this.correctCount,
    originalImageUrls: originalImageUrls ?? this.originalImageUrls,
    createdAt: createdAt ?? this.createdAt,
    lastReviewAt: lastReviewAt ?? this.lastReviewAt,
    masteredAt: masteredAt ?? this.masteredAt,
  );
}

