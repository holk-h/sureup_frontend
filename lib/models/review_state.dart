/// 复习状态
enum ReviewStatus {
  newLearning('新学习'),
  reviewing('复习中'),
  mastered('已掌握');

  const ReviewStatus(this.displayName);
  final String displayName;
}

/// 知识点复习状态
class ReviewState {
  final String id;
  final String userId;
  final String knowledgePointId;
  
  final ReviewStatus status;
  final int masteryScore; // 掌握度 0-100
  
  final int currentInterval; // 当前间隔（天）
  final DateTime? nextReviewDate;
  final DateTime? lastReviewDate;
  
  final int totalReviews;
  final int consecutiveCorrect; // 连续答对次数
  final int totalCorrect;
  final int totalWrong;
  
  final bool isActive; // 是否激活
  
  final DateTime createdAt;
  final DateTime? updatedAt;

  const ReviewState({
    required this.id,
    required this.userId,
    required this.knowledgePointId,
    this.status = ReviewStatus.newLearning,
    this.masteryScore = 0,
    this.currentInterval = 1,
    this.nextReviewDate,
    this.lastReviewDate,
    this.totalReviews = 0,
    this.consecutiveCorrect = 0,
    this.totalCorrect = 0,
    this.totalWrong = 0,
    this.isActive = true,
    required this.createdAt,
    this.updatedAt,
  });

  /// 是否需要复习（到期）
  bool get needsReview {
    if (!isActive) return false;
    if (nextReviewDate == null) return true;
    return DateTime.now().isAfter(nextReviewDate!);
  }

  /// 是否逾期
  bool get isOverdue {
    if (!isActive || nextReviewDate == null) return false;
    return DateTime.now().difference(nextReviewDate!).inDays > 0;
  }

  /// 逾期天数
  int get overdueDays {
    if (!isOverdue) return 0;
    return DateTime.now().difference(nextReviewDate!).inDays;
  }

  /// 正确率
  double get accuracy {
    final total = totalCorrect + totalWrong;
    if (total == 0) return 0.0;
    return totalCorrect / total;
  }

  /// JSON 序列化
  Map<String, dynamic> toJson() => {
    'userId': userId,
    'knowledgePointId': knowledgePointId,
    'status': status.name,
    'masteryScore': masteryScore,
    'currentInterval': currentInterval,
    'nextReviewDate': nextReviewDate?.toIso8601String(),
    'lastReviewDate': lastReviewDate?.toIso8601String(),
    'totalReviews': totalReviews,
    'consecutiveCorrect': consecutiveCorrect,
    'totalCorrect': totalCorrect,
    'totalWrong': totalWrong,
    'isActive': isActive,
  };

  /// JSON 反序列化
  factory ReviewState.fromJson(Map<String, dynamic> json) => ReviewState(
    id: json['id'] as String? ?? json['\$id'] as String,
    userId: json['userId'] as String,
    knowledgePointId: json['knowledgePointId'] as String,
    status: json['status'] != null
        ? ReviewStatus.values.byName(json['status'] as String)
        : ReviewStatus.newLearning,
    masteryScore: json['masteryScore'] as int? ?? 0,
    currentInterval: json['currentInterval'] as int? ?? 1,
    nextReviewDate: json['nextReviewDate'] != null
        ? DateTime.parse(json['nextReviewDate'] as String)
        : null,
    lastReviewDate: json['lastReviewDate'] != null
        ? DateTime.parse(json['lastReviewDate'] as String)
        : null,
    totalReviews: json['totalReviews'] as int? ?? 0,
    consecutiveCorrect: json['consecutiveCorrect'] as int? ?? 0,
    totalCorrect: json['totalCorrect'] as int? ?? 0,
    totalWrong: json['totalWrong'] as int? ?? 0,
    isActive: json['isActive'] as bool? ?? true,
    createdAt: json['createdAt'] != null
        ? DateTime.parse(json['createdAt'] as String)
        : (json['\$createdAt'] != null
            ? DateTime.parse(json['\$createdAt'] as String)
            : DateTime.now()),
    updatedAt: json['updatedAt'] != null
        ? DateTime.parse(json['updatedAt'] as String)
        : (json['\$updatedAt'] != null
            ? DateTime.parse(json['\$updatedAt'] as String)
            : null),
  );

  /// 复制并更新
  ReviewState copyWith({
    String? id,
    String? userId,
    String? knowledgePointId,
    ReviewStatus? status,
    int? masteryScore,
    int? currentInterval,
    DateTime? nextReviewDate,
    DateTime? lastReviewDate,
    int? totalReviews,
    int? consecutiveCorrect,
    int? totalCorrect,
    int? totalWrong,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => ReviewState(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    knowledgePointId: knowledgePointId ?? this.knowledgePointId,
    status: status ?? this.status,
    masteryScore: masteryScore ?? this.masteryScore,
    currentInterval: currentInterval ?? this.currentInterval,
    nextReviewDate: nextReviewDate ?? this.nextReviewDate,
    lastReviewDate: lastReviewDate ?? this.lastReviewDate,
    totalReviews: totalReviews ?? this.totalReviews,
    consecutiveCorrect: consecutiveCorrect ?? this.consecutiveCorrect,
    totalCorrect: totalCorrect ?? this.totalCorrect,
    totalWrong: totalWrong ?? this.totalWrong,
    isActive: isActive ?? this.isActive,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}

