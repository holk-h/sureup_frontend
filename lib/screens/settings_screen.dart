import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../config/colors.dart';
import '../config/constants.dart';
import '../providers/auth_provider.dart';
import '../services/notification_service.dart';

/// 设置页面
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _notificationService = NotificationService();
  
  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemBackground,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: CupertinoColors.systemBackground,
        border: null,
        middle: const Text('设置'),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppConstants.spacingM),
          children: [
            const SizedBox(height: AppConstants.spacingS),
            
            // 提示信息
            Container(
              margin: const EdgeInsets.only(bottom: AppConstants.spacingM),
              padding: const EdgeInsets.all(AppConstants.spacingM),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    CupertinoIcons.info_circle_fill,
                    size: 20,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: AppConstants.spacingS),
                  Expanded(
                    child: Text(
                      '个人信息、学科等设置请在"我的"页面点击相应区域修改',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // 通知设置部分
            _buildSectionTitle('通知设置'),
            const SizedBox(height: AppConstants.spacingM),
            _buildSettingsCard([
              _buildSettingItem(
                icon: CupertinoIcons.bell,
                title: '每日任务提醒',
                subtitle: '提醒你完成每日学习任务',
                color: AppColors.warning,
                trailing: Consumer<AuthProvider>(
                  builder: (context, authProvider, child) {
                    // 这里可以添加通知开关的状态管理
                    return CupertinoSwitch(
                      value: true,
                      onChanged: (value) {
                        // TODO: 实现通知开关功能
                      },
                    );
                  },
                ),
              ),
              Container(
                height: 1,
                margin: const EdgeInsets.only(left: AppConstants.spacingM),
                color: AppColors.divider.withOpacity(0.3),
              ),
              Consumer<AuthProvider>(
                builder: (context, authProvider, child) {
                  final isEnabled = authProvider.userProfile?.reviewReminderEnabled ?? false;
                  final reminderTime = authProvider.userProfile?.reviewReminderTime;
                  
                  // 构建副标题：显示状态和时间
                  String subtitle;
                  if (isEnabled && reminderTime != null) {
                    subtitle = '每天 $reminderTime 提醒 · 点击调整时间';
                  } else if (isEnabled) {
                    subtitle = '已启用 · 点击设置时间';
                  } else {
                    subtitle = '关闭状态 · 打开开关启用提醒';
                  }
                  
                  return _buildSettingItem(
                    icon: CupertinoIcons.alarm,
                    title: '复习提醒',
                    subtitle: subtitle,
                    color: AppColors.mistake,
                    trailing: CupertinoSwitch(
                      value: isEnabled,
                      onChanged: (value) async {
                        await _toggleReviewReminder(value, authProvider);
                      },
                    ),
                    onTap: isEnabled ? () {
                      // 只有在启用状态下才能点击调整时间
                      _showReviewReminderTimePicker(context);
                    } : null,
                  );
                },
              ),
            ]),
            
            const SizedBox(height: AppConstants.spacingL),
            
            // 学习设置部分
            _buildSectionTitle('学习设置'),
            const SizedBox(height: AppConstants.spacingM),
            _buildDifficultySelector(),
            
            
            const SizedBox(height: AppConstants.spacingL),
            
            // 其他设置部分
            _buildSectionTitle('其他'),
            const SizedBox(height: AppConstants.spacingM),
            _buildSettingsCard([
              _buildSettingItem(
                icon: CupertinoIcons.info_circle,
                title: '关于我们',
                subtitle: '了解更多关于 SureUp',
                color: AppColors.textSecondary,
                onTap: () {
                  _showAboutDialog(context);
                },
              ),
              Container(
                height: 1,
                margin: const EdgeInsets.only(left: AppConstants.spacingM),
                color: AppColors.divider.withOpacity(0.3),
              ),
              _buildSettingItem(
                icon: CupertinoIcons.doc_text,
                title: '隐私政策',
                subtitle: '查看隐私政策',
                color: AppColors.textSecondary,
                onTap: () {
                  // TODO: 显示隐私政策
                },
              ),
              Container(
                height: 1,
                margin: const EdgeInsets.only(left: AppConstants.spacingM),
                color: AppColors.divider.withOpacity(0.3),
              ),
              _buildSettingItem(
                icon: CupertinoIcons.checkmark_shield,
                title: '用户协议',
                subtitle: '查看用户协议',
                color: AppColors.textSecondary,
                onTap: () {
                  // TODO: 显示用户协议
                },
              ),
            ]),
            
            const SizedBox(height: AppConstants.spacingXL),
            
            // 版本信息
            Center(
              child: Text(
                'SureUp 版本 1.0.0',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textTertiary,
                ),
              ),
            ),
            
            const SizedBox(height: AppConstants.spacingXXL),
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
  
  Widget _buildSettingsCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(
          color: AppColors.divider.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: AppColors.shadowSoft,
      ),
      child: Column(
        children: children,
      ),
    );
  }
  
  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingM),
        child: Row(
          children: [
            // 图标
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 22,
                color: color,
              ),
            ),
            
            const SizedBox(width: AppConstants.spacingM),
            
            // 标题和副标题
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            
            // 右侧内容（箭头或自定义 widget）
            if (trailing != null)
              trailing
            else if (onTap != null)
              Icon(
                CupertinoIcons.chevron_right,
                size: 18,
                color: AppColors.textTertiary.withOpacity(0.5),
              ),
          ],
        ),
      ),
    );
  }
  
  // 每日任务难度选择器
  Widget _buildDifficultySelector() {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        final currentDifficulty = authProvider.userProfile?.dailyTaskDifficulty ?? 'normal';
        
        return Container(
          padding: const EdgeInsets.all(AppConstants.spacingL),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
            border: Border.all(
              color: AppColors.divider.withOpacity(0.3),
              width: 1,
            ),
            boxShadow: AppColors.shadowSoft,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题和图标
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      CupertinoIcons.chart_bar_fill,
                      size: 22,
                      color: AppColors.success,
                    ),
                  ),
                  const SizedBox(width: AppConstants.spacingM),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '每日任务难度',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '选择适合你的学习强度',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: AppConstants.spacingL),
              
              // 三个难度按钮
              Row(
                children: [
                  Expanded(
                    child: _buildDifficultyButton(
                      difficulty: 'easy',
                      label: '轻松',
                      icon: CupertinoIcons.smiley,
                      isSelected: currentDifficulty == 'easy',
                      color: AppColors.success,
                      authProvider: authProvider,
                    ),
                  ),
                  const SizedBox(width: AppConstants.spacingM),
                  Expanded(
                    child: _buildDifficultyButton(
                      difficulty: 'normal',
                      label: '正常',
                      icon: CupertinoIcons.checkmark_shield,
                      isSelected: currentDifficulty == 'normal',
                      color: AppColors.accent,
                      authProvider: authProvider,
                    ),
                  ),
                  const SizedBox(width: AppConstants.spacingM),
                  Expanded(
                    child: _buildDifficultyButton(
                      difficulty: 'hard',
                      label: '努力',
                      icon: CupertinoIcons.flame_fill,
                      isSelected: currentDifficulty == 'hard',
                      color: AppColors.warning,
                      authProvider: authProvider,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: AppConstants.spacingM),
              
              // 难度说明
              Container(
                padding: const EdgeInsets.all(AppConstants.spacingM),
                decoration: BoxDecoration(
                  color: _getDifficultyColor(currentDifficulty).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                  border: Border.all(
                    color: _getDifficultyColor(currentDifficulty).withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      CupertinoIcons.lightbulb_fill,
                      size: 16,
                      color: _getDifficultyColor(currentDifficulty),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _getDifficultyDescription(currentDifficulty),
                        style: TextStyle(
                          fontSize: 12,
                          color: _getDifficultyColor(currentDifficulty),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  
  // 难度选择按钮
  Widget _buildDifficultyButton({
    required String difficulty,
    required String label,
    required IconData icon,
    required bool isSelected,
    required Color color,
    required AuthProvider authProvider,
  }) {
    return GestureDetector(
      onTap: () async {
        if (!isSelected) {
          try {
            await authProvider.updateProfile(
              dailyTaskDifficulty: difficulty,
            );
          } catch (e) {
            if (mounted) {
              showCupertinoDialog(
                context: context,
                builder: (context) => CupertinoAlertDialog(
                  title: const Text('设置失败'),
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
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.15) : AppColors.background,
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          border: Border.all(
            color: isSelected ? color : AppColors.divider.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 28,
              color: isSelected ? color : AppColors.textTertiary,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? color : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Color _getDifficultyColor(String difficulty) {
    switch (difficulty) {
      case 'easy':
        return AppColors.success;
      case 'hard':
        return AppColors.warning;
      default:
        return AppColors.accent;
    }
  }
  
  String _getDifficultyDescription(String difficulty) {
    switch (difficulty) {
      case 'easy':
        return '轻松模式：每日任务量较少，适合初学者';
      case 'hard':
        return '努力模式：每日任务量较多，适合想要快速提升的同学';
      default:
        return '正常模式：每日任务量适中，适合大部分同学';
    }
  }
  
  // 切换复习提醒
  Future<void> _toggleReviewReminder(bool enabled, AuthProvider authProvider) async {
    try {
      if (enabled) {
        // 如果开启，直接使用默认时间或上次设置的时间
        final currentTime = TimeOfDay.fromString(
          authProvider.userProfile?.reviewReminderTime,
        ) ?? const TimeOfDay(hour: 20, minute: 0);
        
        // 更新为启用状态
        await authProvider.updateProfile(
          reviewReminderEnabled: true,
          reviewReminderTime: currentTime.toString(),
        );
        
        // 设置通知
        await _notificationService.scheduleReviewReminder(
          enabled: true,
          time: currentTime,
        );
        
        // 不显示对话框，让用户通过副标题看到提示
      } else {
        // 如果关闭，直接取消通知
        await _notificationService.scheduleReviewReminder(
          enabled: false,
          time: const TimeOfDay(hour: 20, minute: 0),
        );
        
        // 更新用户配置
        await authProvider.updateProfile(
          reviewReminderEnabled: false,
        );
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('设置失败', '$e');
      }
    }
  }
  
  // 显示复习提醒时间选择器
  Future<void> _showReviewReminderTimePicker(BuildContext context) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentTime = TimeOfDay.fromString(
      authProvider.userProfile?.reviewReminderTime,
    ) ?? const TimeOfDay(hour: 20, minute: 0);
    
    TimeOfDay? selectedTime = currentTime;
    
    await showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        height: 300,
        color: CupertinoColors.systemBackground,
        child: Column(
          children: [
            // 标题栏
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: AppColors.divider.withOpacity(0.3),
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    child: Text(
                      '取消',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Text(
                    '选择复习提醒时间',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    child: Text(
                      '确定',
                      style: TextStyle(color: AppColors.primary),
                    ),
                    onPressed: () async {
                      Navigator.of(context).pop();
                      await _saveReviewReminderTime(selectedTime!, authProvider);
                    },
                  ),
                ],
              ),
            ),
            // 时间选择器
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.time,
                use24hFormat: true,
                initialDateTime: DateTime(
                  2024,
                  1,
                  1,
                  currentTime.hour,
                  currentTime.minute,
                ),
                onDateTimeChanged: (DateTime newTime) {
                  selectedTime = TimeOfDay(
                    hour: newTime.hour,
                    minute: newTime.minute,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // 保存复习提醒时间
  Future<void> _saveReviewReminderTime(
    TimeOfDay time,
    AuthProvider authProvider,
  ) async {
    try {
      // 设置通知
      await _notificationService.scheduleReviewReminder(
        enabled: true,
        time: time,
      );
      
      // 更新用户配置
      await authProvider.updateProfile(
        reviewReminderEnabled: true,
        reviewReminderTime: time.toString(),
      );
      
      if (mounted) {
        _showSuccessMessage('复习提醒已设置为 ${time.toString()}');
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('设置失败', '$e');
      }
    }
  }
  
  // 显示成功消息
  void _showSuccessMessage(String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('成功'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: const Text('确定'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
  
  // 显示错误对话框
  void _showErrorDialog(String title, String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: const Text('确定'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
  
  
  void _showAboutDialog(BuildContext context) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('关于 SureUp'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 16),
            Text(
              'SureUp 是一款智能错题管理应用',
              style: TextStyle(fontSize: 14),
            ),
            SizedBox(height: 8),
            Text(
              '帮助学生记录、分析和复习错题',
              style: TextStyle(fontSize: 14),
            ),
            SizedBox(height: 8),
            Text(
              '让学习更高效！',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ],
        ),
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

