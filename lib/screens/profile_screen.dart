import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../config/colors.dart';
import '../config/text_styles.dart';
import '../models/models.dart';
import '../providers/auth_provider.dart';
import '../services/subscription_service.dart';
import '../widgets/common/developer_message_dialog.dart';
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

  /// 显示开发者的话弹窗
  void _showDeveloperMessage() {
    DeveloperMessageDialog.show(context);
  }

  // 未登录时的登录提示页面
  Widget _buildLoginPrompt(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: const Color(0x00000000),
      child: CustomScrollView(
        slivers: [
          CupertinoSliverNavigationBar(
            backgroundColor: const Color(0x00000000),
            border: null,
            largeTitle: const Text('我的'),
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
          CupertinoSliverNavigationBar(
            backgroundColor: const Color(0x00000000),
            border: null,
            largeTitle: const Text('我的'),
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
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 学习概况
                      _buildQuickStats(userProfile),

                      const SizedBox(height: 20),

                      // 个人信息
                      _buildSectionTitle('个人信息'),
                      const SizedBox(height: 12),
                      _buildInfoCard(userProfile),

                      const SizedBox(height: 20),

                      // 关注的学科
                      _buildSectionTitle('关注的学科'),
                      const SizedBox(height: 12),
                      _buildSubjectsCard(userProfile.focusSubjects ?? []),

                      const SizedBox(height: 20),

                      // 账号管理
                      _buildSectionTitle('账号管理'),
                      const SizedBox(height: 12),
                      _buildAccountActions(context),

                      const SizedBox(height: 32),
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
        child: Row(
          children: [
            // 头像
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary,
                    AppColors.primaryLight,
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  user.name.isNotEmpty ? user.name[0].toUpperCase() : '用',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: CupertinoColors.white,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
            ),

            const SizedBox(width: 16),

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
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                              letterSpacing: -0.5,
                              height: 1.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                            CupertinoIcons.pencil,
                            size: 14,
                          color: AppColors.textTertiary,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  // 年级和学习天数
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      // 年级标签 - 可编辑
                      if (user.grade != null)
                        GestureDetector(
                          onTap: () => _showEditGradeDialog(user.grade!),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _getGradeText(user.grade!),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  CupertinoIcons.pencil,
                                  size: 10,
                                  color: AppColors.primary,
                                ),
                              ],
                            ),
                          ),
                        ),

                      // 学习天数标签
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.accentUltraLight,
                          borderRadius: BorderRadius.circular(8),
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

  // 学习概况 - 只显示学习天数、掌握率、错题总数
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
        const SizedBox(width: 12),
        Expanded(
          child: _buildCompactStatBox(
            label: '掌握率',
            value: '${(user.masteryRate * 100).toStringAsFixed(0)}%',
            icon: CupertinoIcons.chart_pie_fill,
            color: AppColors.success,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildCompactStatBox(
            label: '错题总数',
            value: '${user.totalMistakes}',
            icon: CupertinoIcons.book_fill,
            color: AppColors.mistake,
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
          ),
      ),
      child: Column(
        children: [
          // 图标
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(height: 12),
          // 数值
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
                height: 1.0,
                letterSpacing: -0.5,
              ),
              maxLines: 1,
            ),
          ),
          const SizedBox(height: 4),
          // 标签
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textTertiary,
              fontWeight: FontWeight.w500,
              height: 1.0,
            ),
            maxLines: 1,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // 个人信息卡片 - 只显示联系方式（phone字段，可能是邮箱）
  Widget _buildInfoCard(UserProfile user) {
    // 显示 phone 字段，可能是手机号也可能是邮箱
    final contact = user.phone;
    final displayContact = (contact != null && contact.isNotEmpty) 
        ? contact 
        : '未绑定';
    
    // 判断是邮箱还是手机号，用于显示图标和标签
    final isEmail = contact != null && contact.contains('@');
    final icon = isEmail ? CupertinoIcons.mail : CupertinoIcons.phone_circle_fill;
    final label = isEmail ? '邮箱' : '手机号';
    
    return Container(
      padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
            border: Border.all(
          color: AppColors.divider.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: _buildInfoRow(
        icon: icon,
        label: label,
        value: displayContact,
            iconColor: AppColors.accent,
          ),
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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.divider.withOpacity(0.2),
            width: 1,
          ),
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
        const SizedBox(height: 12),
        _buildActionButton(
          icon: CupertinoIcons.question_circle,
          title: '使用帮助',
          color: AppColors.primary,
          onTap: _showDeveloperMessage,
        ),
        const SizedBox(height: 12),
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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.divider.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            Icon(
              CupertinoIcons.chevron_right,
              size: 16,
              color: AppColors.textTertiary.withOpacity(0.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
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
              child: Row(
                children: [
                  // 图标容器 - 金色/灰色背景
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: isPremium
                          ? const Color(0xFFFFB300) // amber-500 金色
                          : AppColors.textTertiary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(16),
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
                            : CupertinoIcons.star_fill,
                        color: isPremium
                            ? CupertinoColors.white
                            : AppColors.textTertiary,
                        size: 28,
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
                          isPremium ? '会员已激活' : '升级会员',
                              style: TextStyle(
                            fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isPremium
                                    ? const Color(0xFFE65100) // amber-900 深金色文字
                                    : AppColors.textPrimary,
                                letterSpacing: -0.5,
                              ),
                            ),
                            if (isPremium) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFB300),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'PRO',
                                  style: TextStyle(
                                    fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: CupertinoColors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          isPremium
                              ? '享受完整功能，无限错题记录'
                              : '解锁无限错题、变式题生成',
                          style: TextStyle(
                            fontSize: 13,
                            color: isPremium
                                ? const Color(0xFFF57C00).withOpacity(0.8) // amber-700
                                : AppColors.textSecondary,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 箭头图标
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isPremium
                          ? const Color(0xFFFFB300).withOpacity(0.1)
                          : AppColors.textTertiary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                    CupertinoIcons.chevron_right,
                      color: isPremium
                          ? const Color(0xFFFFB300)
                          : AppColors.textTertiary,
                      size: 18,
                    ),
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
