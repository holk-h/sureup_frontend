import 'dart:convert';

/// 积累错题分析记录模型
class AccumulatedAnalysis {
  final String id;
  final String userId;
  final String status;
  final int mistakeCount;
  final int daysSinceLastReview;
  final String? analysisContent;
  final Map<String, dynamic>? summary;
  final List<String>? mistakeIds;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  AccumulatedAnalysis({
    required this.id,
    required this.userId,
    required this.status,
    this.mistakeCount = 0,
    this.daysSinceLastReview = 0,
    this.analysisContent,
    this.summary,
    this.mistakeIds,
    this.startedAt,
    this.completedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  /// 从 Appwrite 文档数据创建实例
  factory AccumulatedAnalysis.fromJson(Map<String, dynamic> json) {
    // 解析 summary
    Map<String, dynamic>? summaryData;
    final summaryStr = json['summary'];
    if (summaryStr is String && summaryStr.isNotEmpty && summaryStr != '{}') {
      try {
        summaryData = jsonDecode(summaryStr) as Map<String, dynamic>?;
      } catch (e) {
        print('解析 summary 失败: $e');
      }
    } else if (summaryStr is Map) {
      summaryData = summaryStr as Map<String, dynamic>;
    }

    return AccumulatedAnalysis(
      id: json['\$id'] as String,
      userId: json['userId'] as String,
      status: json['status'] as String? ?? 'pending',
      mistakeCount: json['mistakeCount'] as int? ?? 0,
      daysSinceLastReview: json['daysSinceLastReview'] as int? ?? 0,
      analysisContent: json['analysisContent'] as String?,
      summary: summaryData,
      mistakeIds: (json['mistakeIds'] as List<dynamic>?)?.map((e) => e.toString()).toList(),
      startedAt: json['startedAt'] != null ? DateTime.parse(json['startedAt']).toLocal() : null,
      completedAt: json['completedAt'] != null ? DateTime.parse(json['completedAt']).toLocal() : null,
      createdAt: DateTime.parse(json['\$createdAt']).toLocal(),
      updatedAt: DateTime.parse(json['\$updatedAt']).toLocal(),
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      '\$id': id,
      'userId': userId,
      'status': status,
      'mistakeCount': mistakeCount,
      'daysSinceLastReview': daysSinceLastReview,
      'analysisContent': analysisContent,
      'summary': summary != null ? jsonEncode(summary) : null,
      'mistakeIds': mistakeIds,
      'startedAt': startedAt?.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      '\$createdAt': createdAt.toIso8601String(),
      '\$updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// 是否已完成
  bool get isCompleted => status == 'completed';

  /// 是否失败
  bool get isFailed => status == 'failed';

  /// 是否进行中
  bool get isProcessing => status == 'processing';

  /// 是否等待中
  bool get isPending => status == 'pending';

  /// 获取状态显示文本
  String get statusText {
    switch (status) {
      case 'completed':
        return '已完成';
      case 'failed':
        return '失败';
      case 'processing':
        return '分析中';
      case 'pending':
        return '等待中';
      default:
        return '未知';
    }
  }

  /// 获取分析时长（如果已完成）
  Duration? get analysisDuration {
    if (startedAt != null && completedAt != null) {
      return completedAt!.difference(startedAt!);
    }
    return null;
  }
}

