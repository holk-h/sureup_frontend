import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../services/subscription_service.dart';
import '../config/colors.dart';
import 'package:intl/intl.dart';

/// 订阅管理页面
class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  @override
  void initState() {
    super.initState();
    // 刷新订阅状态
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<SubscriptionService>(
        context,
        listen: false,
      ).loadSubscriptionStatus();
    });
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('会员订阅')),
      child: SafeArea(
        child: Consumer<SubscriptionService>(
          builder: (context, subscriptionService, child) {
            final status = subscriptionService.status;
            final isPremium = status?.isActive ?? false;

            return SingleChildScrollView(
              child: Column(
                children: [
                  // 订阅状态卡片
                  _buildStatusCard(context, isPremium, status),

                  const SizedBox(height: 24),

                  // 订阅产品（放在会员特权之前）
                  if (!isPremium) ...[
                    _buildSubscriptionPlans(context, subscriptionService),
                    const SizedBox(height: 24),
                  ],

                  // 会员特权
                  _buildPrivilegesSection(),

                  // 恢复购买按钮
                  if (!isPremium) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: CupertinoButton(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      onPressed: subscriptionService.isLoading
                          ? null
                          : () =>
                                _restorePurchases(context, subscriptionService),
                        child: Text(
                          '恢复购买',
                          style: TextStyle(
                            fontSize: 15,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 32),

                  // 说明文字
                  _buildNoticeSection(),

                  const SizedBox(height: 32),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// 订阅状态卡片
  Widget _buildStatusCard(
    BuildContext context,
    bool isPremium,
    SubscriptionStatus? status,
  ) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isPremium
            ? const Color(0xFFFFF8E1) // amber-50 浅金色背景
            : AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isPremium
              ? const Color(0xFFFFB300).withOpacity(0.3) // amber-500 金色边框
              : AppColors.divider.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isPremium
                ? const Color(0xFFFFB300).withOpacity(0.15)
                : AppColors.primary.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // 图标容器
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: isPremium
                      ? const Color(0xFFFFB300) // amber-500 金色
                      : AppColors.textTertiary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: isPremium
                      ? [
                          BoxShadow(
                            color: const Color(0xFFFFB300).withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Icon(
                isPremium
                    ? CupertinoIcons.sparkles
                    : CupertinoIcons.person_circle,
                    color: isPremium
                        ? CupertinoColors.white
                        : AppColors.textTertiary,
                size: 32,
              ),
                ),
              ),
              const SizedBox(width: 16),
              // 文字内容
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
              Text(
                isPremium ? '会员已激活' : '免费版',
                          style: TextStyle(
                  fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: isPremium
                                ? const Color(0xFFE65100) // amber-900 深金色文字
                                : AppColors.textPrimary,
                            letterSpacing: -0.8,
                          ),
                        ),
                        if (isPremium) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFB300),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'PRO',
                              style: TextStyle(
                                fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: CupertinoColors.white,
                                letterSpacing: 0.5,
                              ),
                ),
              ),
                        ],
            ],
          ),
                    const SizedBox(height: 8),
          if (isPremium && status?.expiryDate != null) ...[
            Text(
              '到期时间: ${DateFormat('yyyy-MM-dd').format(status!.expiryDate!)}',
                        style: TextStyle(
                          fontSize: 14,
                          color: const Color(0xFFF57C00).withOpacity(0.8), // amber-700
                          height: 1.3,
              ),
            ),
                      if (status.autoRenew) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              CupertinoIcons.checkmark_circle_fill,
                              size: 14,
                              color: const Color(0xFF10B981),
                            ),
                            const SizedBox(width: 4),
                            Text(
                '自动续订已开启',
                              style: TextStyle(
                                fontSize: 13,
                                color: const Color(0xFFF57C00).withOpacity(0.8),
                              ),
              ),
                          ],
                        ),
                      ],
          ] else ...[
                      Text(
              '升级会员享受完整功能',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
            ),
          ],
          ),
        ],
      ),
    );
  }

  /// 会员特权区域
  Widget _buildPrivilegesSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.divider.withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFB300).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  CupertinoIcons.sparkles,
                  color: Color(0xFFFFB300),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
          const Text(
            '会员特权',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildPrivilegeItem(CupertinoIcons.camera, '无限错题记录', '每天可记录无限个错题'),
          const SizedBox(height: 12),
          _buildPrivilegeItem(CupertinoIcons.shuffle, '无限变式题', 'AI生成变式题无限制'),
          const SizedBox(height: 12),
          _buildPrivilegeItem(CupertinoIcons.chart_bar, '无限积累分析', '每天可无限次分析错题'),
          const SizedBox(height: 12),
          _buildPrivilegeItem(CupertinoIcons.sparkles, '优先体验', '率先体验新功能'),
        ],
      ),
    );
  }

  Widget _buildPrivilegeItem(IconData icon, String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1).withOpacity(0.5), // amber-50 浅金色背景
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFFB300).withOpacity(0.15),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFFFB300).withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Icon(
                icon,
                color: const Color(0xFFFFB300),
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
            CupertinoIcons.checkmark_circle_fill,
              color: Color(0xFF10B981),
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  /// 订阅方案
  Widget _buildSubscriptionPlans(
    BuildContext context,
    SubscriptionService service,
  ) {
    if (service.products.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.divider.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: const CupertinoActivityIndicator(),
      );
    }

    final product = service.products.first;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primaryUltraLight,
            AppColors.cardBackground,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.15),
          width: 1,
          ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题
          const Text(
            '月度会员',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 12),
          // 价格行
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
          Text(
            product.price,
            style: const TextStyle(
                  fontSize: 28,
              fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.8,
                  height: 1.0,
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '/月',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ),
            ],
          ),
          const SizedBox(height: 8),
          // 说明文字
          Text(
            '每月自动续订，可随时取消',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textTertiary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          // 订阅按钮 - 渐变设计
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primary,
                  AppColors.primaryLight,
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: CupertinoButton(
              padding: const EdgeInsets.symmetric(vertical: 14),
              color: const Color(0x00000000), // 透明，使用容器的渐变
              borderRadius: BorderRadius.circular(12),
              onPressed: service.isLoading
                  ? null
                  : () => _purchaseSubscription(context, service),
              child: service.isLoading
                  ? const CupertinoActivityIndicator(
                      color: CupertinoColors.white,
                    )
                  : const Text(
                      '订阅',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: CupertinoColors.white,
                        letterSpacing: -0.3,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  /// 说明文字
  Widget _buildNoticeSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.divider.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                CupertinoIcons.info_circle,
                size: 18,
                color: AppColors.textTertiary,
              ),
              const SizedBox(width: 8),
          const Text(
            '订阅说明',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildNoticeItem('订阅将自动续订，可随时取消'),
          const SizedBox(height: 10),
          _buildNoticeItem('通过 Apple/Google 账号管理订阅'),
          const SizedBox(height: 10),
          _buildNoticeItem('取消订阅后，会员权益将持续到当前周期结束'),
          const SizedBox(height: 10),
          _buildNoticeItem('换设备请使用"恢复购买"功能'),
        ],
      ),
    );
  }

  Widget _buildNoticeItem(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 6, right: 10),
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: AppColors.textTertiary,
            shape: BoxShape.circle,
          ),
        ),
        Expanded(
      child: Text(
        text,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
      ),
      ],
    );
  }

  /// 购买订阅
  Future<void> _purchaseSubscription(
    BuildContext context,
    SubscriptionService service,
  ) async {
    debugPrint('🎯 [订阅页面] 订阅按钮被点击');
    debugPrint('🎯 [订阅页面] service.isLoading: ${service.isLoading}');
    
    // 发起购买请求
    // 注意：这只是发起请求，实际购买结果会通过监听回调处理
    // 购买成功后 UI 会自动更新显示会员状态
    debugPrint('🎯 [订阅页面] 准备调用 service.purchaseSubscription()');
    await service.purchaseSubscription();
    debugPrint('🎯 [订阅页面] service.purchaseSubscription() 调用完成');

    // 只在明确失败时显示错误对话框
    // 用户取消购买不会设置 errorMessage，所以不会显示错误
    if (mounted && service.errorMessage != null) {
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('购买失败'),
          content: Text(service.errorMessage!),
          actions: [
            CupertinoDialogAction(
              child: const Text('确定'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      );
      service.clearError();
    }
    // 购买成功后，UI 会自动更新（因为 Consumer 会监听状态变化）
    // 所以不需要显示成功对话框
  }

  /// 恢复购买
  Future<void> _restorePurchases(
    BuildContext context,
    SubscriptionService service,
  ) async {
    await service.restorePurchases();

    if (mounted && service.errorMessage != null) {
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('恢复失败'),
          content: Text(service.errorMessage!),
          actions: [
            CupertinoDialogAction(
              child: const Text('确定'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      );
      service.clearError();
    } else if (mounted) {
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('恢复成功'),
          content: const Text('购买已恢复'),
          actions: [
            CupertinoDialogAction(
              child: const Text('确定'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      );
    }
  }
}

