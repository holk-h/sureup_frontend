import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import '../../config/colors.dart';
import '../../services/auth_service.dart';
import 'verification_screen.dart';

/// 登录页面 - 手机号登录
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _phoneController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;
  String? _errorMessage;
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  // 前端限流：记录上次发送时间
  DateTime? _lastSendTime;
  static const _rateLimitSeconds = 60;
  
  // 倒计时相关
  Timer? _countdownTimer;
  int _countdown = 0;
  bool get _canSend => _countdown == 0;

  @override
  void initState() {
    super.initState();
    
    // 初始化动画
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
    
    _animationController.forward();
    
    // 检查是否需要恢复倒计时状态
    _checkAndRestoreCountdown();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _animationController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  // 检查并恢复倒计时状态
  void _checkAndRestoreCountdown() {
    if (_lastSendTime != null) {
      final elapsed = DateTime.now().difference(_lastSendTime!).inSeconds;
      if (elapsed < _rateLimitSeconds) {
        // 还在限流期间，恢复倒计时
        _startCountdown(_rateLimitSeconds - elapsed);
      }
    }
  }

  // 开始倒计时
  void _startCountdown(int seconds) {
    setState(() {
      _countdown = seconds;
    });
    
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 0) {
        setState(() {
          _countdown--;
        });
      } else {
        timer.cancel();
      }
    });
  }

  // 发送验证码
  Future<void> _sendVerificationCode() async {
    final phone = _phoneController.text.trim();
    
    // 验证手机号
    if (phone.isEmpty) {
      setState(() {
        _errorMessage = '请输入手机号';
      });
      return;
    }
    
    if (!_isValidPhone(phone)) {
      setState(() {
        _errorMessage = '请输入正确的手机号';
      });
      return;
    }
    
    // 前端限流检查
    if (!_canSend) {
      setState(() {
        _errorMessage = '请求过于频繁，请${_countdown}秒后再试';
      });
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      // 发送验证码
      await _authService.sendPhoneVerification(phone);
      
      // 记录发送时间并开始倒计时
      _lastSendTime = DateTime.now();
      _startCountdown(_rateLimitSeconds);
      
      if (mounted) {
        // 跳转到验证码页面
        Navigator.of(context).push(
          CupertinoPageRoute(
            builder: (context) => VerificationScreen(
              phone: phone.startsWith('+') ? phone : '+86$phone',
            ),
          ),
        );
      }
    } catch (e) {
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

  // 验证手机号格式
  bool _isValidPhone(String phone) {
    // 中国手机号：11位数字，1开头
    final phoneRegex = RegExp(r'^1[3-9]\d{9}$');
    return phoneRegex.hasMatch(phone);
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: AppColors.background.withOpacity(0.9),
        border: null,
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(),
          child: Icon(
            CupertinoIcons.back,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      child: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: CustomScrollView(
              slivers: [
                // 顶部装饰区域
                SliverToBoxAdapter(
                  child: _buildHeader(),
                ),
                
                // 表单区域
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        const SizedBox(height: 8),
                        _buildLoginForm(),
                        const SizedBox(height: 32),
                        _buildFooter(),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 顶部装饰
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 欢迎文案
          Text(
            '欢迎回来',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '快乐和科学的学习，成绩稳了！',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  // 登录表单
  Widget _buildLoginForm() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.shadowMedium,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 标题
          Text(
            '登录 / 注册',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '新用户自动注册，老用户直接登录',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textTertiary,
            ),
          ),
          
          const SizedBox(height: 24),
          
          // 手机号输入框
          Container(
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _errorMessage != null 
                    ? AppColors.error.withOpacity(0.3)
                    : AppColors.divider,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                // 国旗和区号
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Text(
                        '🇨🇳',
                        style: TextStyle(fontSize: 24),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '+86',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 1,
                        height: 24,
                        color: AppColors.divider,
                      ),
                    ],
                  ),
                ),
                
                // 手机号输入
                Expanded(
                  child: CupertinoTextField(
                    controller: _phoneController,
                    placeholder: '请输入手机号',
                    placeholderStyle: TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 16,
                    ),
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: const BoxDecoration(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(11),
                    ],
                    onChanged: (value) {
                      if (_errorMessage != null) {
                        setState(() {
                          _errorMessage = null;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          
          // 错误提示
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  CupertinoIcons.exclamationmark_circle_fill,
                  size: 16,
                  color: AppColors.error,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.error,
                    ),
                  ),
                ),
              ],
            ),
          ],
          
          const SizedBox(height: 24),
          
          // 获取验证码按钮
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: (_isLoading || !_canSend) ? null : _sendVerificationCode,
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                gradient: (_isLoading || !_canSend) ? null : AppColors.primaryGradient,
                color: (_isLoading || !_canSend) ? AppColors.textDisabled : null,
                borderRadius: BorderRadius.circular(12),
                boxShadow: (_isLoading || !_canSend) ? null : AppColors.coloredShadow(
                  AppColors.primary,
                  opacity: 0.3,
                ),
              ),
              child: Center(
                child: _isLoading
                    ? const CupertinoActivityIndicator(
                        color: CupertinoColors.white,
                      )
                    : Text(
                        _canSend ? '获取验证码' : '重新发送 (${_countdown}s)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: CupertinoColors.white,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 底部说明
  Widget _buildFooter() {
    return Column(
      children: [
        Text(
          '登录即表示同意',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textTertiary,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () {
                // TODO: 打开用户协议
              },
              child: Text(
                '《用户协议》',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w500,
                ),
              ), minimumSize: Size(0, 0),
            ),
            Text(
              '和',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textTertiary,
              ),
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () {
                // TODO: 打开隐私政策
              },
              child: Text(
                '《隐私政策》',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w500,
                ),
              ), minimumSize: Size(0, 0),
            ),
          ],
        ),
      ],
    );
  }
}

