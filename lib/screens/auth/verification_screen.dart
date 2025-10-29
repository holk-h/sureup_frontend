import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../config/colors.dart';
import '../../services/auth_service.dart';
import '../../providers/auth_provider.dart';
import 'profile_setup_screen.dart';

/// 验证码输入页面
class VerificationScreen extends StatefulWidget {
  final String phone;

  const VerificationScreen({
    super.key,
    required this.phone,
  });

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  final _codeControllers = List.generate(6, (_) => TextEditingController());
  final _focusNodes = List.generate(6, (_) => FocusNode());
  final _authService = AuthService();
  
  bool _isLoading = false;
  String? _errorMessage;
  int _countdown = 60;
  Timer? _timer;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _startCountdown();
    
    // 自动聚焦到第一个输入框
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes[0].requestFocus();
    });
  }

  @override
  void dispose() {
    for (var controller in _codeControllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    _timer?.cancel();
    super.dispose();
  }

  // 开始倒计时
  void _startCountdown() {
    setState(() {
      _countdown = 60;
      _canResend = false;
    });
    
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 0) {
        setState(() {
          _countdown--;
        });
      } else {
        setState(() {
          _canResend = true;
        });
        timer.cancel();
      }
    });
  }

  // 重新发送验证码
  Future<void> _resendCode() async {
    if (!_canResend) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      await _authService.sendPhoneVerification(widget.phone);
      _startCountdown();
      
      if (mounted) {
        _showToast('验证码已重新发送');
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

  // 验证并登录
  Future<void> _verifyAndLogin() async {
    final code = _codeControllers.map((c) => c.text).join();
    
    if (code.length != 6) {
      setState(() {
        _errorMessage = '请输入完整的验证码';
      });
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      // 验证验证码并登录
      final needsProfileSetup = await _authService.verifyPhoneAndLogin(
        widget.phone,
        code,
      );
      
      if (!mounted) return;
      
      print('验证成功，needsProfileSetup: $needsProfileSetup'); // 调试
      
      // 检查用户档案
      final hasProfile = _authService.currentProfile != null;
      print('用户档案状态: hasProfile=$hasProfile, profile=${_authService.currentProfile}'); // 调试
      
      if (needsProfileSetup || !hasProfile) {
        // 首次注册或档案不完整，跳转到完善信息页面
        Navigator.of(context).pushReplacement(
          CupertinoPageRoute(
            builder: (context) => const ProfileSetupScreen(),
          ),
        );
      } else {
        // 已有账号且档案完整，更新全局状态并返回
        await Provider.of<AuthProvider>(context, listen: false).onLoginSuccess();
        
        // 返回到之前的页面（关闭登录流程）
        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
      // 清空输入
      for (var controller in _codeControllers) {
        controller.clear();
      }
      _focusNodes[0].requestFocus();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showToast(String message) {
    showCupertinoDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => CupertinoAlertDialog(
        content: Text(message),
      ),
    ).then((_) {
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          Navigator.of(context, rootNavigator: true).pop();
        }
      });
    });
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
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              
              // 标题
              Text(
                '输入验证码',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              
              const SizedBox(height: 12),
              
              // 提示文字
              Text(
                '验证码已发送至',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textTertiary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '+86 ${widget.phone}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              
              const SizedBox(height: 48),
              
              // 验证码输入框
              _buildCodeInputs(),
              
              const SizedBox(height: 24),
              
              // 错误提示
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
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
              
              // 重新发送
              _buildResendButton(),
              
              const Spacer(),
              
              // 确认按钮
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _isLoading ? null : _verifyAndLogin,
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
                        : Text(
                            '确认',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: CupertinoColors.white,
                            ),
                          ),
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // 验证码输入框
  Widget _buildCodeInputs() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(6, (index) {
        return _buildCodeInput(index);
      }),
    );
  }

  Widget _buildCodeInput(int index) {
    return Container(
      width: 48,
      height: 56,
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _codeControllers[index].text.isNotEmpty
              ? AppColors.primary
              : AppColors.divider,
          width: 1.5,
        ),
        boxShadow: _codeControllers[index].text.isNotEmpty
            ? AppColors.coloredShadow(AppColors.primary, opacity: 0.1)
            : null,
      ),
      child: Center(
        child: CupertinoTextField(
          controller: _codeControllers[index],
          focusNode: _focusNodes[index],
          textAlign: TextAlign.center,
          textAlignVertical: TextAlignVertical.center,
          keyboardType: TextInputType.number,
          maxLength: 1,
          decoration: const BoxDecoration(),
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
            height: 1.0, // 设置行高为1，确保文本垂直居中
          ),
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
          ],
          onChanged: (value) {
            if (value.isNotEmpty) {
              // 自动跳转到下一个输入框
              if (index < 5) {
                _focusNodes[index + 1].requestFocus();
              } else {
                // 最后一个输入框，自动验证
                _focusNodes[index].unfocus();
                _verifyAndLogin();
              }
            }
            setState(() {
              _errorMessage = null;
            });
          },
          onTap: () {
            // 清空当前输入框
            _codeControllers[index].clear();
          },
        ),
      ),
    );
  }

  // 重新发送按钮
  Widget _buildResendButton() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          _canResend ? '没收到验证码？' : '重新发送',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textTertiary,
          ),
        ),
        const SizedBox(width: 8),
        CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _canResend && !_isLoading ? _resendCode : null,
          child: Text(
            _canResend ? '点击重新发送' : '${_countdown}s',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _canResend ? AppColors.primary : AppColors.textTertiary,
            ),
          ), minimumSize: Size(0, 0),
        ),
      ],
    );
  }
}

