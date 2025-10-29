import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../config/colors.dart';
import '../../services/auth_service.dart';
import '../../providers/auth_provider.dart';

/// 用户信息完善页面（首次注册）
class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _nameController = TextEditingController();
  final _authService = AuthService();
  
  int? _selectedGrade;
  final List<String> _selectedSubjects = [];
  bool _isLoading = false;
  String? _errorMessage;

  // 年级选项
  final List<Map<String, dynamic>> _grades = [
    {'value': 7, 'label': '初一'},
    {'value': 8, 'label': '初二'},
    {'value': 9, 'label': '初三'},
    {'value': 10, 'label': '高一'},
    {'value': 11, 'label': '高二'},
    {'value': 12, 'label': '高三'},
  ];

  // 学科选项
  final List<Map<String, dynamic>> _subjects = [
    {'id': 'math', 'name': '数学', 'icon': '📐', 'color': AppColors.accent},
    {'id': 'physics', 'name': '物理', 'icon': '⚛️', 'color': Color(0xFF8B5CF6)},
    {'id': 'chemistry', 'name': '化学', 'icon': '🧪', 'color': AppColors.error},
    {'id': 'english', 'name': '英语', 'icon': '🔤', 'color': AppColors.primary},
    {'id': 'chinese', 'name': '语文', 'icon': '📖', 'color': Color(0xFFEC4899)},
    {'id': 'biology', 'name': '生物', 'icon': '🌱', 'color': Color(0xFF10B981)},
  ];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // 完成设置
  Future<void> _completeSetup() async {
    final name = _nameController.text.trim();
    
    // 验证
    if (name.isEmpty) {
      setState(() {
        _errorMessage = '请输入昵称';
      });
      return;
    }
    
    if (_selectedGrade == null) {
      setState(() {
        _errorMessage = '请选择年级';
      });
      return;
    }
    
    if (_selectedSubjects.isEmpty) {
      setState(() {
        _errorMessage = '请至少选择一个学科';
      });
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      print('开始创建用户档案，name: $name, grade: $_selectedGrade'); // 调试
      
      // 创建用户档案（首次注册）
      await _authService.createUserProfile(
        name: name,
        grade: _selectedGrade,
        focusSubjects: _selectedSubjects,
      );
      
      print('用户档案创建成功'); // 调试
      
      if (!mounted) return;
      
      // 更新全局登录状态
      await Provider.of<AuthProvider>(context, listen: false).onLoginSuccess();
      
      // 返回到主页（关闭登录流程）
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      print('创建用户档案失败: $e'); // 调试
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      child: SafeArea(
        child: CustomScrollView(
          slivers: [
            // 顶部标题
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 进度指示
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '最后一步',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: CupertinoColors.white,
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    Text(
                      '完善个人信息',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    
                    const SizedBox(height: 8),
                    
                    Text(
                      '让我们更了解你，提供更个性化的学习建议',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // 表单内容
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 昵称输入
                    _buildNameInput(),
                    
                    const SizedBox(height: 32),
                    
                    // 年级选择
                    _buildGradeSelector(),
                    
                    const SizedBox(height: 32),
                    
                    // 学科选择
                    _buildSubjectSelector(),
                    
                    const SizedBox(height: 24),
                    
                    // 错误提示
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.error.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              CupertinoIcons.exclamationmark_circle_fill,
                              size: 20,
                              color: AppColors.error,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.error,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                    
                    // 完成按钮
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: _isLoading ? null : _completeSetup,
                      child: Container(
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: _isLoading ? null : AppColors.primaryGradient,
                          color: _isLoading ? AppColors.textDisabled : null,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: _isLoading ? null : AppColors.coloredShadow(
                            AppColors.primary,
                            opacity: 0.3,
                          ),
                        ),
                        child: Center(
                          child: _isLoading
                              ? const CupertinoActivityIndicator(
                                  color: CupertinoColors.white,
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      '开始使用',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: CupertinoColors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(
                                      CupertinoIcons.arrow_right,
                                      color: CupertinoColors.white,
                                      size: 20,
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 48),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 昵称输入
  Widget _buildNameInput() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.shadowSoft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '😊',
                style: TextStyle(fontSize: 24),
              ),
              const SizedBox(width: 12),
              Text(
                '你的昵称',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          CupertinoTextField(
            controller: _nameController,
            placeholder: '请输入昵称',
            placeholderStyle: TextStyle(
              color: AppColors.textTertiary,
            ),
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textPrimary,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.divider,
                width: 1,
              ),
            ),
            onChanged: (value) {
              if (_errorMessage != null) {
                setState(() {
                  _errorMessage = null;
                });
              }
            },
          ),
        ],
      ),
    );
  }

  // 年级选择
  Widget _buildGradeSelector() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.shadowSoft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '🎓',
                style: TextStyle(fontSize: 24),
              ),
              const SizedBox(width: 12),
              Text(
                '你的年级',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _grades.map((grade) {
              final isSelected = _selectedGrade == grade['value'];
              return CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () {
                  setState(() {
                    _selectedGrade = grade['value'];
                    _errorMessage = null;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    gradient: isSelected ? AppColors.primaryGradient : null,
                    color: isSelected ? null : AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? const Color(0x00000000) : AppColors.divider,
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    grade['label'],
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? CupertinoColors.white : AppColors.textPrimary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // 学科选择
  Widget _buildSubjectSelector() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.shadowSoft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '📚',
                style: TextStyle(fontSize: 24),
              ),
              const SizedBox(width: 12),
              Text(
                '关注的学科',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          Text(
            '可多选',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textTertiary,
            ),
          ),
          
          const SizedBox(height: 16),
          
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _subjects.map((subject) {
              final isSelected = _selectedSubjects.contains(subject['id']);
              return CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () {
                  setState(() {
                    if (isSelected) {
                      _selectedSubjects.remove(subject['id']);
                    } else {
                      _selectedSubjects.add(subject['id']);
                    }
                    _errorMessage = null;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (subject['color'] as Color).withOpacity(0.15)
                        : AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? (subject['color'] as Color)
                          : AppColors.divider,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        subject['icon'],
                        style: TextStyle(fontSize: 20),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        subject['name'],
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? (subject['color'] as Color)
                              : AppColors.textPrimary,
                        ),
                      ),
                      if (isSelected) ...[
                        const SizedBox(width: 6),
                        Icon(
                          CupertinoIcons.checkmark_circle_fill,
                          size: 18,
                          color: subject['color'] as Color,
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

