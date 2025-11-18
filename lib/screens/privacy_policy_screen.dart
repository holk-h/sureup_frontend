import 'package:flutter/cupertino.dart';
import '../config/colors.dart';
import '../config/constants.dart';

/// 隐私政策页面
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemBackground,
      navigationBar: const CupertinoNavigationBar(
        backgroundColor: CupertinoColors.systemBackground,
        border: null,
        middle: Text('隐私政策'),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppConstants.spacingL),
          children: [
            // 标题
            const Text(
              '隐私政策',
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
              content: '''"稳了!"APP非常重视您的隐私保护。本隐私政策说明了我们如何收集、使用和保护您的个人信息。

使用本服务即表示您同意本隐私政策。如有疑问，请通过邮箱联系我们。''',
            ),
            
            // 信息收集
            _buildSection(
              title: '1. 我们收集的信息',
              content: '''我们仅收集必要的信息以提供服务：

• 账户信息：手机号/邮箱（用于注册登录）、用户名和头像（可选）
• 学习内容：您上传的错题图片、文字、学习进度、每日任务完成情况
• 日志信息：操作记录和错误日志（用于改进服务，已脱敏处理）

我们不会收集：
• 设备标识符（IMEI、IDFA等）
• 地理位置信息
• 通讯录、相册（除您主动上传的错题图片）
• 身份证、生物识别等敏感信息''',
            ),
            
            // 信息使用
            _buildSection(
              title: '2. 如何使用信息',
              content: '''我们使用这些信息用于：

• 提供核心功能：账户管理、错题记录、学习数据同步
• 智能分析：AI分析学习模式、生成个性化学习任务
• 安全保障：账户安全验证、防范违规行为
• 服务通知：学习提醒、系统通知（可在设置中关闭）
• 产品改进：分析使用情况、修复问题（已脱敏）

我们承诺：
• 不用于营销推广
• 不推送商业广告
• 不用于本政策外的其他目的''',
            ),
            
            // 信息共享
            _buildSection(
              title: '3. 信息共享',
              content: '''我们不会出售、出租或交易您的个人信息。

我们使用以下第三方服务：
• Appwrite云服务：存储账户和学习数据（数据存储在中国境内）
• Apple服务：Apple ID登录、内购支付
• 火山引擎：AI分析功能（仅在您使用时，不存储数据）

除非法律要求或获得您的同意，我们不会向其他第三方共享您的信息。''',
            ),
            
            // 数据安全
            _buildSection(
              title: '4. 数据安全',
              content: '''我们采取安全措施保护您的信息：

• 使用HTTPS加密传输
• 敏感数据加密存储
• 访问权限控制
• 定期安全审计和数据备份

如发生数据泄露等安全事件，我们会及时通知您并采取补救措施。''',
            ),
            
            // 数据保留
            _buildSection(
              title: '5. 数据保留与删除',
              content: '''• 账户信息：在您使用服务期间保留
• 学习数据：您可随时在应用内删除
• 账户注销：注销后我们将删除您的个人信息（法律要求保留的除外）

您可以通过设置-账户管理来管理或删除您的数据。''',
            ),
            
            // 您的权利
            _buildSection(
              title: '6. 您的权利',
              content: '''您对自己的个人信息享有以下权利：

• 查阅和导出：在应用内查看和导出您的数据
• 更正：更新不准确的个人信息
• 删除：删除学习数据或注销账户
• 撤回同意：关闭推送通知等可选功能
• 投诉：向我们或主管部门投诉

如需帮助，请通过邮箱 support@delvetech.cn 联系我们。''',
            ),
            
            // 未成年人保护
            _buildSection(
              title: '7. 未成年人保护',
              content: '''• 本服务面向13周岁以上用户
• 14周岁以下未成年人使用需征得监护人同意
• 如您是监护人，发现未成年人未经同意使用服务，请联系我们''',
            ),
            
            // 政策变更
            _buildSection(
              title: '8. 政策变更',
              content: '''我们可能会更新本隐私政策。重大变更时会通过应用通知您。

继续使用服务即表示您接受更新后的政策。''',
            ),
            
            // 联系我们
            _buildSection(
              title: '9. 联系我们',
              content: '''如有任何疑问或投诉，请通过邮箱联系我们：

• 邮箱：support@delvetech.cn

我们将在15个工作日内回复您的请求。''',
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

