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

/// AI 分析状态
enum AnalysisStatus {
  pending('待分析'),
  processing('分析中'),
  completed('已完成'),
  failed('失败');

  const AnalysisStatus(this.displayName);
  final String displayName;
}

/// 错题记录（用户与题目的关联记录）
class MistakeRecord {
  final String id;
  final String userId; // 用户ID
  final String? questionId; // 关联题目ID（分析完成后填充）
  
  // 学科和知识点
  final Subject subject;
  final List<String>? moduleIds; // 模块ID列表
  final List<String>? knowledgePointIds; // 知识点ID列表
  
  // 错题信息
  final ErrorReason? errorReason; // 分析完成后填充
  final String? note; // 用户备注
  final String? userAnswer; // 用户的错误答案
  
  // AI 分析相关
  final AnalysisStatus analysisStatus; // 分析状态
  final String? analysisError; // 分析错误信息
  final DateTime? analyzedAt; // 分析完成时间
  
  // 状态
  final MasteryStatus masteryStatus;
  final int reviewCount; // 复习次数
  final int correctCount; // 正确次数
  
  // 原始图片（拍照录入的）- 存储 fileId
  final List<String>? originalImageUrls;
  
  // 时间戳
  final DateTime createdAt; // 错题时间
  final DateTime? lastReviewAt; // 最后复习时间
  final DateTime? masteredAt; // 掌握时间

  const MistakeRecord({
    required this.id,
    required this.userId,
    this.questionId,
    required this.subject,
    this.moduleIds,
    this.knowledgePointIds,
    this.errorReason,
    this.note,
    this.userAnswer,
    this.analysisStatus = AnalysisStatus.pending,
    this.analysisError,
    this.analyzedAt,
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

  /// 是否分析完成
  bool get isAnalyzed => analysisStatus == AnalysisStatus.completed;
  
  /// 是否分析失败
  bool get isAnalysisFailed => analysisStatus == AnalysisStatus.failed;
  
  /// 是否分析中
  bool get isAnalyzing => analysisStatus == AnalysisStatus.processing;

  /// JSON 序列化
  Map<String, dynamic> toJson() => {
    'userId': userId,
    'questionId': questionId,
    'subject': subject.name,
    'moduleIds': moduleIds,
    'knowledgePointIds': knowledgePointIds,
    'errorReason': errorReason?.name,
    'note': note,
    'userAnswer': userAnswer,
    'analysisStatus': analysisStatus.name,
    'analysisError': analysisError,
    'analyzedAt': analyzedAt?.toIso8601String(),
    'masteryStatus': masteryStatus.name,
    'reviewCount': reviewCount,
    'correctCount': correctCount,
    'originalImageUrls': originalImageUrls,
    'lastReviewAt': lastReviewAt?.toIso8601String(),
    'masteredAt': masteredAt?.toIso8601String(),
  };

  /// JSON 反序列化
  factory MistakeRecord.fromJson(Map<String, dynamic> json) {
    return MistakeRecord(
      id: json['id'] as String? ?? json['\$id'] as String,
      userId: json['userId'] as String,
      questionId: json['questionId'] as String?,
      subject: Subject.values.byName(json['subject'] as String),
      moduleIds: (json['moduleIds'] as List<dynamic>?)?.cast<String>(),
      knowledgePointIds: (json['knowledgePointIds'] as List<dynamic>?)?.cast<String>(),
      errorReason: json['errorReason'] != null 
          ? ErrorReason.values.byName(json['errorReason'] as String)
          : null,
      note: json['note'] as String?,
      userAnswer: json['userAnswer'] as String?,
      analysisStatus: json['analysisStatus'] != null
          ? AnalysisStatus.values.byName(json['analysisStatus'] as String)
          : AnalysisStatus.pending,
      analysisError: json['analysisError'] as String?,
      analyzedAt: json['analyzedAt'] != null 
          ? DateTime.parse(json['analyzedAt'] as String)
          : null,
      masteryStatus: json['masteryStatus'] != null
          ? MasteryStatus.values.byName(json['masteryStatus'] as String)
          : MasteryStatus.notStarted,
      reviewCount: json['reviewCount'] as int? ?? 0,
      correctCount: json['correctCount'] as int? ?? 0,
      originalImageUrls: (json['originalImageUrls'] as List<dynamic>?)?.cast<String>(),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : (json['\$createdAt'] != null 
              ? DateTime.parse(json['\$createdAt'] as String)
              : DateTime.now()),
      lastReviewAt: json['lastReviewAt'] != null 
          ? DateTime.parse(json['lastReviewAt'] as String) 
          : null,
      masteredAt: json['masteredAt'] != null 
          ? DateTime.parse(json['masteredAt'] as String) 
          : null,
    );
  }

  /// 复制并更新
  MistakeRecord copyWith({
    String? id,
    String? userId,
    String? questionId,
    Subject? subject,
    List<String>? moduleIds,
    List<String>? knowledgePointIds,
    ErrorReason? errorReason,
    String? note,
    String? userAnswer,
    AnalysisStatus? analysisStatus,
    String? analysisError,
    DateTime? analyzedAt,
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
    moduleIds: moduleIds ?? this.moduleIds,
    knowledgePointIds: knowledgePointIds ?? this.knowledgePointIds,
    errorReason: errorReason ?? this.errorReason,
    note: note ?? this.note,
    userAnswer: userAnswer ?? this.userAnswer,
    analysisStatus: analysisStatus ?? this.analysisStatus,
    analysisError: analysisError ?? this.analysisError,
    analyzedAt: analyzedAt ?? this.analyzedAt,
    masteryStatus: masteryStatus ?? this.masteryStatus,
    reviewCount: reviewCount ?? this.reviewCount,
    correctCount: correctCount ?? this.correctCount,
    originalImageUrls: originalImageUrls ?? this.originalImageUrls,
    createdAt: createdAt ?? this.createdAt,
    lastReviewAt: lastReviewAt ?? this.lastReviewAt,
    masteredAt: masteredAt ?? this.masteredAt,
  );
}

