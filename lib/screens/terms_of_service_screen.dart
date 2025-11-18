import 'package:flutter/cupertino.dart';
import '../config/colors.dart';
import '../config/constants.dart';

/// 用户协议页面
class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemBackground,
      navigationBar: const CupertinoNavigationBar(
        backgroundColor: CupertinoColors.systemBackground,
        border: null,
        middle: Text('用户协议'),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppConstants.spacingL),
          children: [
            // 标题
            const Text(
              '用户协议',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '最后更新：2024年1月1日',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textTertiary,
              ),
            ),
            
            const SizedBox(height: AppConstants.spacingXL),
            
            // 引言
            _buildSection(
              title: '引言',
              content: '''欢迎使用"稳了!"APP！使用本服务即表示您同意本协议。

如您不同意本协议，请停止使用。我们可能会更新本协议，重大变更时会通知您。''',
            ),
            
            // 服务描述
            _buildSection(
              title: '1. 服务说明',
              content: '''"稳了!"APP提供智能错题管理服务，包括：错题记录、AI分析、个性化学习任务、进度追踪和复习提醒。

我们保留修改、暂停或终止服务功能的权利。''',
            ),
            
            // 账户注册
            _buildSection(
              title: '2. 账户使用',
              content: '''• 必须年满13周岁，14周岁以下需监护人同意
• 提供真实准确的注册信息
• 妥善保管账户和密码，不得转让给他人
• 账户安全由您负责

遗忘密码可通过手机号或邮箱找回。''',
            ),
            
            // 用户行为规范
            _buildSection(
              title: '3. 使用规范',
              content: '''您应当：
• 遵守法律法规
• 不发布违法违规内容
• 不侵犯他人权利
• 不破坏服务正常运行

违反规定，我们有权终止您的账户。''',
            ),
            
            // 知识产权
            _buildSection(
              title: '4. 知识产权',
              content: '''• "稳了!"APP的所有内容归我们所有
• 您上传的内容归您所有，但您授予我们使用、存储和处理的权利
• 未经许可，不得复制或分发我们的服务内容''',
            ),
            
            // 订阅与付费
            _buildSection(
              title: '5. 付费服务',
              content: '''• 服务分为免费和付费两种
• 订阅到期前24小时自动续订，可随时取消
• 付费通过Apple内购，价格以应用内展示为准
• 一般情况下，订阅费用不予退还
• 如因我们原因导致服务无法使用，可申请退款
• 未成年人未经监护人同意的付费，监护人可申请退款''',
            ),
            
            // 免责声明
            _buildSection(
              title: '6. 免责声明',
              content: '''• 服务"按原样"提供，我们不保证绝对无错误
• 学习建议仅供参考，不保证学习效果
• 服务可能因维护、升级等原因暂停
• 我们不对服务中断造成的损失负责''',
            ),
            
            // 账户终止
            _buildSection(
              title: '7. 账户终止',
              content: '''您可以随时注销账户。注销后我们将删除您的个人信息。

我们有权在以下情况终止您的账户：
• 违反本协议
• 从事违法违规行为
• 长期未使用（超过12个月）

终止前我们会通知您，您可导出学习数据。''',
            ),
            
            // 争议解决
            _buildSection(
              title: '8. 争议解决',
              content: '''本协议适用中国法律。如发生争议，双方应协商解决。协商不成的，可向我们所在地人民法院提起诉讼。''',
            ),
            
            // 联系我们
            _buildSection(
              title: '9. 联系我们',
              content: '''如有任何疑问或投诉，请通过邮箱联系我们：

• 邮箱：support@delvetech.cn

我们将在15个工作日内回复您。''',
            ),
            
            const SizedBox(height: AppConstants.spacingXXL),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSection({
    required String title,
    required String content,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppConstants.spacingXL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppConstants.spacingM),
          Text(
            content,
            style: const TextStyle(
              fontSize: 15,
              height: 1.6,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

