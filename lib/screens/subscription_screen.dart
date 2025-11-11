import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../services/subscription_service.dart';
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

                  // 会员特权
                  _buildPrivilegesSection(),

                  const SizedBox(height: 24),

                  // 订阅产品
                  if (!isPremium) ...[
                    _buildSubscriptionPlans(context, subscriptionService),
                    const SizedBox(height: 16),
                  ],

                  // 恢复购买按钮
                  if (!isPremium) ...[
                    CupertinoButton(
                      onPressed: subscriptionService.isLoading
                          ? null
                          : () =>
                                _restorePurchases(context, subscriptionService),
                      child: const Text('恢复购买'),
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isPremium
              ? [const Color(0xFFFFB300), const Color(0xFFFFA726)]
              : [const Color(0xFFBDBDBD), const Color(0xFFE0E0E0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isPremium
                    ? CupertinoIcons.sparkles
                    : CupertinoIcons.person_circle,
                color: CupertinoColors.white,
                size: 32,
              ),
              const SizedBox(width: 12),
              Text(
                isPremium ? '会员已激活' : '免费版',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: CupertinoColors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (isPremium && status?.expiryDate != null) ...[
            Text(
              '到期时间: ${DateFormat('yyyy-MM-dd').format(status!.expiryDate!)}',
              style: const TextStyle(
                fontSize: 16,
                color: CupertinoColors.white,
              ),
            ),
            if (status.autoRenew)
              const Text(
                '自动续订已开启',
                style: TextStyle(fontSize: 14, color: CupertinoColors.white),
              ),
          ] else ...[
            const Text(
              '升级会员享受完整功能',
              style: TextStyle(fontSize: 16, color: CupertinoColors.white),
            ),
          ],
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
        color: CupertinoColors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '会员特权',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildPrivilegeItem(CupertinoIcons.camera, '无限错题记录', '每天可记录无限个错题'),
          _buildPrivilegeItem(CupertinoIcons.shuffle, '无限变式题', 'AI生成变式题无限制'),
          _buildPrivilegeItem(CupertinoIcons.chart_bar, '无限积累分析', '每天可无限次分析错题'),
          _buildPrivilegeItem(CupertinoIcons.sparkles, '优先体验', '率先体验新功能'),
        ],
      ),
    );
  }

  Widget _buildPrivilegeItem(IconData icon, String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFFFFB300), size: 24),
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
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 14,
                    color: CupertinoColors.systemGrey,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            CupertinoIcons.checkmark_circle_fill,
            color: CupertinoColors.activeGreen,
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
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: CupertinoActivityIndicator(),
        ),
      );
    }

    final product = service.products.first;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CupertinoColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.systemGrey.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            '月度会员',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            product.price,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Color(0xFFFFB300),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '每月自动续订',
            style: TextStyle(fontSize: 14, color: CupertinoColors.systemGrey),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: CupertinoButton(
              color: const Color(0xFFFFB300),
              borderRadius: BorderRadius.circular(12),
              onPressed: service.isLoading
                  ? null
                  : () => _purchaseSubscription(context, service),
              child: service.isLoading
                  ? const CupertinoActivityIndicator(
                      color: CupertinoColors.white,
                    )
                  : const Text(
                      '立即订阅',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: CupertinoColors.white,
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '订阅说明',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildNoticeItem('• 订阅将自动续订，可随时取消'),
          _buildNoticeItem('• 通过 Apple/Google 账号管理订阅'),
          _buildNoticeItem('• 取消订阅后，会员权益将持续到当前周期结束'),
          _buildNoticeItem('• 换设备请使用"恢复购买"功能'),
        ],
      ),
    );
  }

  Widget _buildNoticeItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        text,
        style: const TextStyle(fontSize: 14, color: CupertinoColors.systemGrey),
      ),
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
