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
  ocrOK('OCR完成'),
  ocrWrong('识别有误'),
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
  final String? questionId; // 关联题目ID列表（分析完成后填充，支持多道题）
  
  // 学科和知识点
  final Subject? subject; // AI 自动识别，可为空
  final List<String>? moduleIds; // 模块ID列表
  final List<String>? knowledgePointIds; // 知识点ID列表
  
  // 错题信息
  final String? errorReason; // 错因（可以是预定义的枚举值或自定义文本）
  final String? note; // 用户笔记
  final String? userAnswer; // 用户的错误答案
  final bool isImportant; // 用户标记为重要
  
  // AI 分析相关
  final AnalysisStatus analysisStatus; // 分析状态
  final String? analysisError; // 分析错误信息
  final String? wrongReason; // OCR 识别错误原因（用户反馈）
  final DateTime? analyzedAt; // 分析完成时间
  final DateTime? accumulatedAnalyzedAt; // 积累错题分析时间
  
  // 状态
  final MasteryStatus masteryStatus;
  final int reviewCount; // 复习次数
  final int correctCount; // 正确次数
  
  // 原始图片（拍照录入的）- 存储 fileId 列表（支持多图题）
  final List<String>? originalImageIds;
  
  // 时间戳
  final DateTime createdAt; // 错题时间
  final DateTime? lastReviewAt; // 最后复习时间
  final DateTime? masteredAt; // 掌握时间

  const MistakeRecord({
    required this.id,
    required this.userId,
    this.questionId,
    this.subject, // 改为可选，由 AI 自动识别
    this.moduleIds,
    this.knowledgePointIds,
    this.errorReason,
    this.note,
    this.userAnswer,
    this.isImportant = false,
    this.analysisStatus = AnalysisStatus.pending,
    this.analysisError,
    this.wrongReason,
    this.analyzedAt,
    this.accumulatedAnalyzedAt,
    this.masteryStatus = MasteryStatus.notStarted,
    this.reviewCount = 0,
    this.correctCount = 0,
    this.originalImageIds,
    required this.createdAt,
    this.lastReviewAt,
    this.masteredAt,
  });
  
  /// 是否为多图题
  bool get isMultiPhoto => originalImageIds != null && originalImageIds!.length > 1;
  
  /// 获取第一张原图ID
  String? get originalImageId => originalImageIds?.isNotEmpty == true ? originalImageIds!.first : null;

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

  /// 获取错因的枚举对象（如果是预定义的）
  ErrorReason? get errorReasonEnum {
    if (errorReason == null) return null;
    return ErrorReason.fromString(errorReason!);
  }

  /// 获取显示的错因文本
  String? get errorReasonDisplay {
    if (errorReason == null) return null;
    // 尝试匹配预定义的枚举
    final enumValue = ErrorReason.fromString(errorReason!);
    if (enumValue != null) {
      return enumValue.displayName;
    }
    // 否则直接返回自定义文本
    return errorReason;
  }

  /// JSON 序列化
  Map<String, dynamic> toJson() => {
    'userId': userId,
    'questionId': questionId,
    if (subject != null) 'subject': subject!.name, // 只在有值时才包含
    'moduleIds': moduleIds,
    'knowledgePointIds': knowledgePointIds,
    'errorReason': errorReason,
    'note': note,
    'userAnswer': userAnswer,
    'isImportant': isImportant,
    'analysisStatus': analysisStatus.name,
    'analysisError': analysisError,
    'wrongReason': wrongReason,
    'analyzedAt': analyzedAt?.toIso8601String(),
    'accumulatedAnalyzedAt': accumulatedAnalyzedAt?.toIso8601String(),
    'masteryStatus': masteryStatus.name,
    'reviewCount': reviewCount,
    'correctCount': correctCount,
    'originalImageIds': originalImageIds,
    'lastReviewAt': lastReviewAt?.toIso8601String(),
    'masteredAt': masteredAt?.toIso8601String(),
  };

  /// JSON 反序列化
  factory MistakeRecord.fromJson(Map<String, dynamic> json) {
    // 处理 errorReason：兼容旧数据（可能是枚举值）和新数据（字符串）
    String? errorReasonValue;
    if (json['errorReason'] != null) {
      final rawValue = json['errorReason'];
      if (rawValue is String) {
        errorReasonValue = rawValue;
      } else {
        // 如果是其他类型（如旧的枚举），转换为字符串
        errorReasonValue = rawValue.toString();
      }
    }
    
    // 处理 subject - 容错处理，OCR 阶段可能是 "unknown"
    Subject? subject;
    try {
      final subjectStr = json['subject'] as String?;
      if (subjectStr != null && subjectStr != 'unknown') {
        subject = Subject.values.byName(subjectStr);
      }
    } catch (e) {
      // 如果解析失败（比如遇到未知的学科名），subject 保持为 null
      subject = null;
    }
    
    return MistakeRecord(
      id: json['id'] as String? ?? json['\$id'] as String,
      userId: json['userId'] as String,
      questionId: json['questionId'] as String?,
      subject: subject, // subject 可为空，由 AI 分析后填充
      moduleIds: (json['moduleIds'] as List<dynamic>?)?.cast<String>(),
      knowledgePointIds: (json['knowledgePointIds'] as List<dynamic>?)?.cast<String>(),
      errorReason: errorReasonValue,
      note: json['note'] as String?,
      userAnswer: json['userAnswer'] as String?,
      isImportant: json['isImportant'] as bool? ?? false,
      analysisStatus: json['analysisStatus'] != null
          ? AnalysisStatus.values.byName(json['analysisStatus'] as String)
          : AnalysisStatus.pending,
      analysisError: json['analysisError'] as String?,
      wrongReason: json['wrongReason'] as String?,
      analyzedAt: json['analyzedAt'] != null 
          ? DateTime.parse(json['analyzedAt'] as String).toLocal()
          : null,
      accumulatedAnalyzedAt: json['accumulatedAnalyzedAt'] != null 
          ? DateTime.parse(json['accumulatedAnalyzedAt'] as String).toLocal()
          : null,
      masteryStatus: json['masteryStatus'] != null
          ? MasteryStatus.values.byName(json['masteryStatus'] as String)
          : MasteryStatus.notStarted,
      reviewCount: json['reviewCount'] as int? ?? 0,
      correctCount: json['correctCount'] as int? ?? 0,
      originalImageIds: json['originalImageIds'] != null
          ? (json['originalImageIds'] as List<dynamic>).cast<String>()
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String).toLocal()
          : (json['\$createdAt'] != null 
              ? DateTime.parse(json['\$createdAt'] as String).toLocal()
              : DateTime.now()),
      lastReviewAt: json['lastReviewAt'] != null 
          ? DateTime.parse(json['lastReviewAt'] as String).toLocal() 
          : null,
      masteredAt: json['masteredAt'] != null 
          ? DateTime.parse(json['masteredAt'] as String).toLocal() 
          : null,
    );
  }

  /// 复制并更新
  MistakeRecord copyWith({
    String? id,
    String? userId,
    String? questionId,
    Subject? Function()? subject, // 使用函数类型以支持设置为 null
    List<String>? moduleIds,
    List<String>? knowledgePointIds,
    String? errorReason,
    String? note,
    String? userAnswer,
    bool? isImportant,
    AnalysisStatus? analysisStatus,
    String? analysisError,
    String? wrongReason,
    DateTime? analyzedAt,
    DateTime? accumulatedAnalyzedAt,
    MasteryStatus? masteryStatus,
    int? reviewCount,
    int? correctCount,
    List<String>? originalImageIds,
    DateTime? createdAt,
    DateTime? lastReviewAt,
    DateTime? masteredAt,
  }) => MistakeRecord(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    questionId: questionId ?? this.questionId,
    subject: subject != null ? subject() : this.subject,
    moduleIds: moduleIds ?? this.moduleIds,
    knowledgePointIds: knowledgePointIds ?? this.knowledgePointIds,
    errorReason: errorReason ?? this.errorReason,
    note: note ?? this.note,
    userAnswer: userAnswer ?? this.userAnswer,
    isImportant: isImportant ?? this.isImportant,
    analysisStatus: analysisStatus ?? this.analysisStatus,
    analysisError: analysisError ?? this.analysisError,
    wrongReason: wrongReason ?? this.wrongReason,
    analyzedAt: analyzedAt ?? this.analyzedAt,
    accumulatedAnalyzedAt: accumulatedAnalyzedAt ?? this.accumulatedAnalyzedAt,
    masteryStatus: masteryStatus ?? this.masteryStatus,
    reviewCount: reviewCount ?? this.reviewCount,
    correctCount: correctCount ?? this.correctCount,
    originalImageIds: originalImageIds ?? this.originalImageIds,
    createdAt: createdAt ?? this.createdAt,
    lastReviewAt: lastReviewAt ?? this.lastReviewAt,
    masteredAt: masteredAt ?? this.masteredAt,
  );
}

