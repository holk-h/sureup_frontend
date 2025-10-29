/// 错因类型
enum ErrorReason {
  conceptUnclear('概念不清楚'),
  logicBlocked('思路断了'),
  calculationError('计算错误'),
  careless('粗心'),
  unfamiliar('没见过这种题'),
  timeInsufficient('时间不够'),
  other('其他');

  const ErrorReason(this.displayName);
  
  final String displayName;

  /// 从字符串解析
  static ErrorReason? fromString(String value) {
    return ErrorReason.values
        .where((e) => e.name == value || e.displayName == value)
        .firstOrNull;
  }
}

