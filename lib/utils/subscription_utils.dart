import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../services/subscription_service.dart';

/// 订阅权限检查工具类
class SubscriptionUtils {
  /// 检查用户是否有权限执行操作
  /// 返回 true 表示有权限，false 表示无权限
  static bool checkPermission(BuildContext context) {
    try {
      final subscriptionService = Provider.of<SubscriptionService>(
        context,
        listen: false,
      );
      return subscriptionService.status?.isActive ?? false;
    } catch (e) {
      // 如果无法获取订阅状态，默认返回 false（需要权限）
      return false;
    }
  }

  /// 检查用户档案中的订阅状态
  /// 更可靠的方式，直接从用户档案获取
  static bool checkPermissionFromProfile(UserProfile? profile) {
    if (profile == null) return false;

    final subscriptionStatus = profile.subscriptionStatus ?? 'free';
    final expiryDate = profile.subscriptionExpiryDate;

    if (subscriptionStatus != 'active') return false;
    if (expiryDate == null) return false;

    return expiryDate.isAfter(DateTime.now());
  }

  /// 检查每日错题记录限制
  /// 返回 [isAllowed, remainingCount, profile]
  static (bool, int, UserProfile?) checkDailyMistakeLimit(
    UserProfile? profile,
  ) {
    if (profile == null) return (false, 0, null);

    // 会员无限制
    if (checkPermissionFromProfile(profile)) {
      return (true, 999, profile);
    }

    // 免费用户每天最多 3 个
    const dailyLimit = 3;
    final todayCount = profile.todayMistakeRecords ?? 0;
    final remaining = dailyLimit - todayCount;

    return (remaining > 0, remaining, profile);
  }

  /// 检查每日积累分析限制
  /// 返回 [isAllowed, remainingCount, profile]
  static (bool, int, UserProfile?) checkDailyAnalysisLimit(
    UserProfile? profile,
  ) {
    if (profile == null) return (false, 0, null);

    // 会员无限制
    if (checkPermissionFromProfile(profile)) {
      return (true, 999, profile);
    }

    // 免费用户每天最多 1 次
    const dailyLimit = 1;
    final todayCount = profile.todayAccumulatedAnalysis ?? 0;
    final remaining = dailyLimit - todayCount;

    return (remaining > 0, remaining, profile);
  }

  /// 显示升级会员对话框
  static void showUpgradeDialog(
    BuildContext context, {
    required String feature,
    String? message,
  }) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('需要升级会员'),
        content: Text(message ?? '$feature功能仅限会员使用\n升级会员即可解锁'),
        actions: [
          CupertinoDialogAction(
            child: const Text('暂不升级'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('立即升级'),
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushNamed('/subscription');
            },
          ),
        ],
      ),
    );
  }

  /// 显示每日限制已用完对话框
  static void showDailyLimitDialog(
    BuildContext context, {
    required String feature,
    required int limit,
  }) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('今日次数已用完'),
        content: Text(
          '免费版每天最多使用$limit次$feature\n\n升级会员即可无限使用',
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('知道了'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('升级会员'),
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushNamed('/subscription');
            },
          ),
        ],
      ),
    );
  }
}
