import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../config/colors.dart';
import '../config/constants.dart';
import '../config/text_styles.dart';
import '../models/models.dart';
import '../providers/auth_provider.dart';
import '../services/subscription_service.dart';
import 'auth/login_screen.dart';
import 'settings_screen.dart';

/// 我的页 - 个人信息
class ProfileScreen extends StatefulWidget {
  /// 刷新触发器 - 当这个值改变时，触发内容刷新
  final int refreshTrigger;

  const ProfileScreen({super.key, this.refreshTrigger = 0});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    // 页面加载时刷新用户档案
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshProfileData();
    });
  }

  @override
  void didUpdateWidget(ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 检查刷新触发器是否改变
    if (widget.refreshTrigger != oldWidget.refreshTrigger) {
      print('👤 收到个人界面刷新触发器: ${widget.refreshTrigger}');
      _refreshProfileData();
    }
  }

  /// 刷新个人档案数据
  void _refreshProfileData() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.isLoggedIn) {
      print('📊 开始后台刷新个人档案数据...');
      // 异步刷新，不阻塞UI
      authProvider
          .refreshProfile()
          .then((_) {
            print('✅ 个人档案数据刷新完成');
          })
          .catchError((e) {
            print('❌ 个人档案数据刷新失败: $e');
          });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        final isLoggedIn = authProvider.isLoggedIn;
        final userProfile = authProvider.userProfile;

        print(
          'ProfileScreen: isLoggedIn=$isLoggedIn, userProfile=$userProfile',
        ); // 调试

        // 未登录时显示登录提示
        if (!isLoggedIn) {
          return _buildLoginPrompt(context);
        }

        // 已登录显示完整个人页面
        return _buildProfileContent(context, userProfile);
      },
    );
  }

  // 未登录时的登录提示页面
  Widget _buildLoginPrompt(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: const Color(0x00000000),
      child: CustomScrollView(
        slivers: [
          const CupertinoSliverNavigationBar(
            backgroundColor: Color(0x00000000),
            border: null,
            largeTitle: Text('我的'),
            heroTag: 'profile_nav_bar',
          ),
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo - 更大更精致
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.primary,
                          AppColors.primary.withOpacity(0.7),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.3),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      CupertinoIcons.person_crop_circle,
                      color: CupertinoColors.white,
                      size: 56,
                    ),
                  ),

                  const SizedBox(height: 32),

                  Text(
                    '登录后查看个人数据',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.8,
                    ),
                  ),

                  const SizedBox(height: 12),

                  Text(
                    '记录错题、查看进步、智能复盘',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.textTertiary,
                      height: 1.5,
                    ),
                  ),

                  const SizedBox(height: 48),

                  // 登录按钮 - 更大更突出
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () async {
                      await Navigator.of(context).push(
                        CupertinoPageRoute(
                          builder: (context) => const LoginScreen(),
                          fullscreenDialog: true,
                        ),
                      );
                    },
                    child: Container(
                      width: double.infinity,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary,
                            AppColors.primary.withOpacity(0.8),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text(
                          '登录 / 注册',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: CupertinoColors.white,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 功能列表预览 - 更现代的设计
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.cardBackground,
                          AppColors.cardBackground.withOpacity(0.8),
                        ],
                      ),
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
                        Text(
                          '登录后你可以：',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 20),
                        _buildFeatureItem('📸', '拍照记录错题，生成解析'),
                        _buildFeatureItem('📊', '查看学习数据'),
                        _buildFeatureItem('🎯', '个性化练习推荐'),
                        _buildFeatureItem('📈', '追踪学习进步'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(String emoji, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withOpacity(0.1),
                  AppColors.primary.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 20)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
                letterSpacing: -0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 已登录时的完整个人页面
  Widget _buildProfileContent(BuildContext context, UserProfile? userProfile) {
    // 如果用户资料为空，显示提示信息
    if (userProfile == null) {
      return CupertinoPageScaffold(
        backgroundColor: const Color(0x00000000),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CupertinoActivityIndicator(),
              const SizedBox(height: 16),
              Text('正在加载用户信息...', style: AppTextStyles.body),
              const SizedBox(height: 24),
              CupertinoButton(
                onPressed: () {
                  final authProvider = Provider.of<AuthProvider>(
                    context,
                    listen: false,
                  );
                  authProvider.refreshProfile();
                },
                child: const Text('重新加载'),
              ),
            ],
          ),
        ),
      );
    }

    return CupertinoPageScaffold(
      backgroundColor: const Color(0x00000000),
      child: CustomScrollView(
        slivers: [
          // 导航栏
          const CupertinoSliverNavigationBar(
            backgroundColor: Color(0x00000000),
            border: null,
            largeTitle: Text('我的'),
            heroTag: 'profile_nav_bar',
          ),

          SliverToBoxAdapter(
            child: Column(
              children: [
                // 渐变顶部区域 - 个人信息
                _buildProfileHeader(userProfile),

                // 会员状态卡片
                _buildSubscriptionCard(context),

                // 主要内容区域
                Padding(
                  padding: const EdgeInsets.all(AppConstants.spacingM),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 学习概况
                      _buildQuickStats(userProfile),

                      const SizedBox(height: AppConstants.spacingL),

                      // 个人信息
                      _buildSectionTitle('个人信息'),
                      const SizedBox(height: AppConstants.spacingM),
                      _buildInfoCard(userProfile),

                      const SizedBox(height: AppConstants.spacingL),

                      // 关注的学科
                      _buildSectionTitle('关注的学科'),
                      const SizedBox(height: AppConstants.spacingM),
                      _buildSubjectsCard(userProfile.focusSubjects ?? []),

                      const SizedBox(height: AppConstants.spacingL),

                      // 账号管理
                      _buildSectionTitle('账号管理'),
                      const SizedBox(height: AppConstants.spacingM),
                      _buildAccountActions(context),

                      const SizedBox(height: AppConstants.spacingXXL),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 简约现代的头部卡片
  Widget _buildProfileHeader(UserProfile user) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.cardBackground,
              AppColors.cardBackground.withOpacity(0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AppColors.divider.withOpacity(0.1),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.08),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            // 头像 - 更大更突出的渐变圆形背景
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary,
                    AppColors.primary.withOpacity(0.7),
                  ],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  user.name.isNotEmpty ? user.name[0].toUpperCase() : '用',
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: CupertinoColors.white,
                    letterSpacing: -1,
                  ),
                ),
              ),
            ),

            const SizedBox(width: 20),

            // 用户信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 昵称 - 可编辑
                  GestureDetector(
                    onTap: () => _showEditNicknameDialog(user.name),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            user.name,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                              letterSpacing: -0.8,
                              height: 1.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            CupertinoIcons.pencil,
                            size: 14,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  // 年级和学习天数
                  Row(
                    children: [
                      // 年级标签 - 可编辑
                      if (user.grade != null) ...[
                        GestureDetector(
                          onTap: () => _showEditGradeDialog(user.grade!),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.primary,
                                  AppColors.primary.withOpacity(0.8),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(0.2),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _getGradeText(user.grade!),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: CupertinoColors.white,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(
                                  CupertinoIcons.pencil,
                                  size: 10,
                                  color: CupertinoColors.white,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],

                      // 学习天数标签
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.accentUltraLight,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.accent.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              CupertinoIcons.calendar,
                              size: 12,
                              color: AppColors.accent,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '已学${user.activeDays}天',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.accent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 将年级数字转换为文字
  String _getGradeText(int grade) {
    const gradeMap = {
      1: '小学一年级',
      2: '小学二年级',
      3: '小学三年级',
      4: '小学四年级',
      5: '小学五年级',
      6: '小学六年级',
      7: '初一',
      8: '初二',
      9: '初三',
      10: '高一',
      11: '高二',
      12: '高三',
    };
    return gradeMap[grade] ?? '学生';
  }

  // 学习概况 - 彩色渐变背景统计卡片
  Widget _buildQuickStats(UserProfile user) {
    return Row(
      children: [
        Expanded(
          child: _buildCompactStatBox(
            label: '学习天数',
            value: '${user.activeDays}',
            icon: CupertinoIcons.calendar,
            color: AppColors.accent,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildCompactStatBox(
            label: '连续打卡',
            value: '${user.continuousDays}',
            icon: CupertinoIcons.flame_fill,
            color: AppColors.warning,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildCompactStatBox(
            label: '掌握率',
            value: '${(user.masteryRate * 100).toStringAsFixed(0)}%',
            icon: CupertinoIcons.chart_pie_fill,
            color: AppColors.success,
          ),
        ),
      ],
    );
  }

  // 精致统计卡片 - 现代简洁设计
  Widget _buildCompactStatBox({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withOpacity(0.08), color.withOpacity(0.04)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.15), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // 图标
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [color.withOpacity(0.2), color.withOpacity(0.15)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 22, color: color),
          ),
          const SizedBox(height: 12),
          // 数值
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
                height: 1.0,
                letterSpacing: -0.5,
              ),
              maxLines: 1,
            ),
          ),
          const SizedBox(height: 6),
          // 标签
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textTertiary,
              fontWeight: FontWeight.w600,
              height: 1.0,
            ),
            maxLines: 1,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // 个人信息卡片 - 只显示手机号和学习数据
  Widget _buildInfoCard(UserProfile user) {
    return Column(
      children: [
        // 手机号卡片
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.cardBackground,
                AppColors.cardBackground.withOpacity(0.8),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.divider.withOpacity(0.1),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withOpacity(0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: _buildInfoRow(
            icon: _getContactIcon(user.phone, user.email),
            label: _getContactLabel(user.phone, user.email),
            value: _formatContactInfo(user.phone, user.email) ?? '未绑定',
            iconColor: AppColors.accent,
          ),
        ),

        const SizedBox(height: AppConstants.spacingM),

        // 学习数据卡片（网格布局）
        Row(
          children: [
            Expanded(
              child: _buildCompactDataCard(
                icon: CupertinoIcons.book_fill,
                label: '错题总数',
                value: '${user.totalMistakes}',
                color: AppColors.mistake,
              ),
            ),
            const SizedBox(width: AppConstants.spacingM),
            Expanded(
              child: _buildCompactDataCard(
                icon: CupertinoIcons.checkmark_seal_fill,
                label: '已掌握',
                value: '${user.masteredMistakes}',
                color: AppColors.success,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // 信息行组件
  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required Color iconColor,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [iconColor.withOpacity(0.15), iconColor.withOpacity(0.1)],
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, size: 22, color: iconColor),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textTertiary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 关注的学科卡片 - 可编辑版本
  Widget _buildSubjectsCard(List<String> subjects) {
    return GestureDetector(
      onTap: () => _showSubjectEditor(subjects),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.cardBackground,
              AppColors.cardBackground.withOpacity(0.8),
            ],
          ),
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
        child: subjects.isEmpty
            ? _buildEmptySubjects()
            : _buildSubjectsList(subjects),
      ),
    );
  }

  // 空状态显示
  Widget _buildEmptySubjects() {
    return Column(
      children: [
        Icon(CupertinoIcons.add_circled, size: 40, color: AppColors.primary),
        const SizedBox(height: 12),
        Text(
          '点击添加关注学科',
          style: AppTextStyles.body.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '长按学科标签可以删除',
          style: AppTextStyles.caption.copyWith(color: AppColors.textTertiary),
        ),
      ],
    );
  }

  // 学科列表显示
  Widget _buildSubjectsList(List<String> subjects) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 提示文字和编辑按钮
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '长按学科可删除，点击可编辑',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textTertiary,
                fontSize: 11,
              ),
            ),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                CupertinoIcons.pencil_circle_fill,
                size: 18,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        // 学科标签
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: subjects.map((subjectId) {
            // 将学科ID转换为中文显示名称
            final subject = Subject.fromString(subjectId);
            final displayName = subject?.displayName ?? subjectId;

            return GestureDetector(
              onLongPress: () => _removeSubject(subjectId),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  gradient: _getSubjectGradient(displayName),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _getSubjectBorderColor(displayName),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _getSubjectBorderColor(
                        displayName,
                      ).withOpacity(0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _getSubjectEmoji(displayName),
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      displayName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _getSubjectTextColor(displayName),
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // 显示学科编辑器
  void _showSubjectEditor(List<String> currentSubjects) {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) {
        return CupertinoActionSheet(
          title: const Text('选择要添加的学科'),
          message: const Text('长按已选学科可以删除'),
          actions: Subject.values.map((subject) {
            final isSelected = currentSubjects.contains(subject.name);
            return CupertinoActionSheetAction(
              onPressed: () async {
                Navigator.pop(context);
                if (isSelected) {
                  _removeSubject(subject.name);
                } else {
                  await _addSubject(subject.name);
                }
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isSelected)
                    const Icon(
                      CupertinoIcons.checkmark_circle_fill,
                      color: AppColors.success,
                      size: 20,
                    ),
                  if (isSelected) const SizedBox(width: 8),
                  Text(
                    '${_getSubjectEmoji(subject.displayName)} ${subject.displayName}',
                    style: TextStyle(
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                      color: isSelected
                          ? AppColors.success
                          : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context),
            isDefaultAction: true,
            child: const Text('取消'),
          ),
        );
      },
    );
  }

  // 添加学科
  Future<void> _addSubject(String subjectId) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentSubjects = List<String>.from(
      authProvider.userProfile?.focusSubjects ?? [],
    );

    if (currentSubjects.contains(subjectId)) {
      // 已经添加过了
      return;
    }

    currentSubjects.add(subjectId);

    try {
      // 调用 AuthProvider 更新用户档案
      await authProvider.updateProfile(focusSubjects: currentSubjects);

      // 显示成功提示
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('添加成功'),
            content: Text(
              '已添加 ${Subject.fromString(subjectId)?.displayName ?? subjectId}',
            ),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(context),
                child: const Text('确定'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      // 显示错误提示
      if (mounted) {
        final errorMessage = e.toString();

        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('添加失败'),
            content: Text(errorMessage.replaceAll('Exception: ', '')),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(context),
                child: const Text('确定'),
              ),
            ],
          ),
        );
      }
    }
  }

  // 删除学科
  void _removeSubject(String subjectId) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('删除学科'),
        content: Text(
          '确定要删除 ${Subject.fromString(subjectId)?.displayName ?? subjectId} 吗？',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(context);

              final authProvider = Provider.of<AuthProvider>(
                context,
                listen: false,
              );
              final currentSubjects = List<String>.from(
                authProvider.userProfile?.focusSubjects ?? [],
              );
              currentSubjects.remove(subjectId);

              try {
                // 调用 AuthProvider 更新用户档案
                await authProvider.updateProfile(
                  focusSubjects: currentSubjects,
                );

                // 显示成功提示（可选）
                if (mounted) {
                  // 简单的toast提示，不需要用户确认
                  // 这里使用简单的 SnackBar 替代对话框
                }
              } catch (e) {
                // 显示错误提示
                if (mounted) {
                  final errorMessage = e.toString();

                  showCupertinoDialog(
                    context: context,
                    builder: (context) => CupertinoAlertDialog(
                      title: const Text('删除失败'),
                      content: Text(errorMessage.replaceAll('Exception: ', '')),
                      actions: [
                        CupertinoDialogAction(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('确定'),
                        ),
                      ],
                    ),
                  );
                }
              }
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  // 学科渐变背景
  LinearGradient _getSubjectGradient(String subject) {
    switch (subject) {
      case '数学':
        return AppColors.mathGradient;
      case '物理':
        return AppColors.physicsGradient;
      case '化学':
        return AppColors.chemistryGradient;
      case '英语':
        return AppColors.englishGradient;
      case '生物':
        return const LinearGradient(
          colors: [
            Color(0xFFF0FDF4),
            Color(0xFFDCFCE7),
          ], // green-50 to green-100
        );
      case '语文':
        return const LinearGradient(
          colors: [
            Color(0xFFFFFBEB),
            Color(0xFFFEF3C7),
          ], // amber-50 to amber-100
        );
      case '历史':
        return const LinearGradient(
          colors: [Color(0xFFFEF2F2), Color(0xFFFEE2E2)], // red-50 to red-100
        );
      case '地理':
        return const LinearGradient(
          colors: [Color(0xFFF0FDFA), Color(0xFFCCFBF1)], // teal-50 to teal-100
        );
      case '政治':
        return const LinearGradient(
          colors: [
            Color(0xFFFFFBEB),
            Color(0xFFFEF3C7),
          ], // amber-50 to amber-100
        );
      default:
        return const LinearGradient(
          colors: [Color(0xFFF9FAFB), Color(0xFFF3F4F6)], // gray-50 to gray-100
        );
    }
  }

  // 学科边框颜色
  Color _getSubjectBorderColor(String subject) {
    switch (subject) {
      case '数学':
        return const Color(0xFF93C5FD); // blue-300
      case '物理':
        return const Color(0xFFD8B4FE); // purple-300
      case '化学':
        return const Color(0xFFFCA5A5); // red-300
      case '英语':
        return const Color(0xFF6EE7B7); // emerald-300
      case '生物':
        return const Color(0xFF86EFAC); // green-300
      case '语文':
        return const Color(0xFFFCD34D); // amber-300
      case '历史':
        return const Color(0xFFFCA5A5); // red-300
      case '地理':
        return const Color(0xFF5EEAD4); // teal-300
      case '政治':
        return const Color(0xFFFCD34D); // amber-300
      default:
        return const Color(0xFFD1D5DB); // gray-300
    }
  }

  // 学科文字颜色
  Color _getSubjectTextColor(String subject) {
    switch (subject) {
      case '数学':
        return const Color(0xFF1E40AF); // blue-800
      case '物理':
        return const Color(0xFF6B21A8); // purple-800
      case '化学':
        return const Color(0xFF991B1B); // red-800
      case '英语':
        return const Color(0xFF065F46); // emerald-800
      case '生物':
        return const Color(0xFF166534); // green-800
      case '语文':
        return const Color(0xFF92400E); // amber-800
      case '历史':
        return const Color(0xFF991B1B); // red-800
      case '地理':
        return const Color(0xFF115E59); // teal-800
      case '政治':
        return const Color(0xFF92400E); // amber-800
      default:
        return const Color(0xFF374151); // gray-700
    }
  }

  // 学科emoji
  String _getSubjectEmoji(String subject) {
    switch (subject) {
      case '数学':
        return '📐';
      case '物理':
        return '⚛️';
      case '化学':
        return '🧪';
      case '英语':
        return '🔤';
      case '生物':
        return '🧬';
      case '语文':
        return '📖';
      case '历史':
        return '📜';
      case '地理':
        return '🌍';
      case '政治':
        return '⚖️';
      default:
        return '📚';
    }
  }

  // 账号管理按钮组
  Widget _buildAccountActions(BuildContext context) {
    return Column(
      children: [
        _buildActionButton(
          icon: CupertinoIcons.settings,
          title: '账号设置',
          color: AppColors.accent,
          onTap: () {
            Navigator.of(context).push(
              CupertinoPageRoute(builder: (context) => const SettingsScreen()),
            );
          },
        ),
        const SizedBox(height: AppConstants.spacingM),
        _buildActionButton(
          icon: CupertinoIcons.arrow_right_square,
          title: '退出登录',
          color: AppColors.error,
          onTap: () => _handleLogout(context),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.cardBackground,
              AppColors.cardBackground.withOpacity(0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppColors.divider.withOpacity(0.1),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [color.withOpacity(0.15), color.withOpacity(0.1)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 22, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            Icon(
              CupertinoIcons.chevron_right,
              size: 18,
              color: AppColors.textTertiary.withOpacity(0.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
          letterSpacing: -0.3,
        ),
      ),
    );
  }

  // 处理登出
  void _handleLogout(BuildContext context) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('退出登录'),
        content: const Text('确定要退出登录吗？'),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                await Provider.of<AuthProvider>(
                  context,
                  listen: false,
                ).logout();
              } catch (e) {
                // 显示错误提示
                if (context.mounted) {
                  showCupertinoDialog(
                    context: context,
                    builder: (context) => CupertinoAlertDialog(
                      title: const Text('退出失败'),
                      content: Text(e.toString()),
                      actions: [
                        CupertinoDialogAction(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('确定'),
                        ),
                      ],
                    ),
                  );
                }
              }
            },
            child: const Text('退出'),
          ),
        ],
      ),
    );
  }

  // 紧凑版数据卡片
  Widget _buildCompactDataCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withOpacity(0.08), color.withOpacity(0.04)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.15), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [color.withOpacity(0.2), color.withOpacity(0.15)],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 22, color: color),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textTertiary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // 智能格式化联系方式（手机号或邮箱）
  String? _formatContactInfo(String? phone, String? email) {
    // 优先使用 phone 字段
    final contact = phone ?? email;

    if (contact == null || contact.isEmpty) {
      return null;
    }

    // 判断是否为邮箱（包含 @ 符号）
    if (contact.contains('@')) {
      return contact; // 邮箱直接返回
    }

    // 手机号处理：如果以+86开头，去掉+86前缀
    if (contact.startsWith('+86')) {
      return contact.substring(3);
    }

    return contact;
  }

  // 获取联系方式标签
  String _getContactLabel(String? phone, String? email) {
    final contact = phone ?? email;
    if (contact == null || contact.isEmpty) {
      return '联系方式';
    }
    // 判断是否为邮箱
    if (contact.contains('@')) {
      return '邮箱';
    }
    return '手机号';
  }

  // 获取联系方式图标
  IconData _getContactIcon(String? phone, String? email) {
    final contact = phone ?? email;
    if (contact == null || contact.isEmpty) {
      return CupertinoIcons.person_circle_fill;
    }
    // 判断是否为邮箱
    if (contact.contains('@')) {
      return CupertinoIcons.mail;
    }
    return CupertinoIcons.phone_circle_fill;
  }

  // 显示编辑昵称对话框
  void _showEditNicknameDialog(String currentName) {
    final controller = TextEditingController(text: currentName);

    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('修改昵称'),
        content: Container(
          height: 60,
          padding: const EdgeInsets.only(top: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CupertinoTextField(
                controller: controller,
                placeholder: '请输入新昵称',
                autofocus: true,
                maxLength: 20,
                style: const TextStyle(fontSize: 16),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
            ],
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('取消'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('确定'),
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isEmpty) {
                return;
              }

              Navigator.of(context).pop();
              await _updateNickname(newName);
            },
          ),
        ],
      ),
    );
  }

  // 显示编辑年级对话框
  void _showEditGradeDialog(int currentGrade) {
    final grades = [
      {'value': 1, 'label': '小学一年级'},
      {'value': 2, 'label': '小学二年级'},
      {'value': 3, 'label': '小学三年级'},
      {'value': 4, 'label': '小学四年级'},
      {'value': 5, 'label': '小学五年级'},
      {'value': 6, 'label': '小学六年级'},
      {'value': 7, 'label': '初一'},
      {'value': 8, 'label': '初二'},
      {'value': 9, 'label': '初三'},
      {'value': 10, 'label': '高一'},
      {'value': 11, 'label': '高二'},
      {'value': 12, 'label': '高三'},
    ];

    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('选择年级'),
        actions: grades.map((grade) {
          return CupertinoActionSheetAction(
            child: Text(grade['label'] as String),
            onPressed: () {
              Navigator.of(context).pop();
              _updateGrade(grade['value'] as int);
            },
          );
        }).toList(),
        cancelButton: CupertinoActionSheetAction(
          child: const Text('取消'),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  // 更新昵称
  Future<void> _updateNickname(String newName) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.updateProfile(name: newName);

      if (mounted) {
        // 显示成功提示
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('修改成功'),
            content: const Text('昵称已更新'),
            actions: [
              CupertinoDialogAction(
                child: const Text('确定'),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('修改失败'),
            content: Text('$e'),
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

  // 更新年级
  Future<void> _updateGrade(int newGrade) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.updateProfile(grade: newGrade);

      if (mounted) {
        // 显示成功提示
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('修改成功'),
            content: const Text('年级已更新'),
            actions: [
              CupertinoDialogAction(
                child: const Text('确定'),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('修改失败'),
            content: Text('$e'),
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

  /// 会员状态卡片
  Widget _buildSubscriptionCard(BuildContext context) {
    return Consumer<SubscriptionService>(
      builder: (context, subscriptionService, child) {
        final status = subscriptionService.status;
        final isPremium = status?.isActive ?? false;

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () {
              Navigator.of(context).pushNamed('/subscription');
            },
            child: Container(
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
                    color:
                        (isPremium
                                ? const Color(0xFFFFB300)
                                : const Color(0xFFBDBDBD))
                            .withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: CupertinoColors.white.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isPremium ? CupertinoIcons.sparkles : CupertinoIcons.star,
                      color: CupertinoColors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isPremium ? '会员已激活' : '升级会员',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: CupertinoColors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isPremium ? '享受完整功能' : '解锁无限错题、变式题',
                          style: TextStyle(
                            fontSize: 14,
                            color: CupertinoColors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    CupertinoIcons.chevron_right,
                    color: CupertinoColors.white.withOpacity(0.8),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
