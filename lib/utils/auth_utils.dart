import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../screens/auth/login_screen.dart';

/// 认证工具函数

/// 检查是否已登录，如果未登录则跳转到登录页
/// 返回 true 表示已登录，可以继续操作
/// 返回 false 表示未登录，已跳转到登录页
Future<bool> requireLogin(BuildContext context, {String? message}) async {
  final authProvider = Provider.of<AuthProvider>(context, listen: false);
  
  if (authProvider.isLoggedIn) {
    return true;
  }
  
  // 显示登录提示
  final shouldLogin = await showCupertinoDialog<bool>(
    context: context,
    builder: (context) => CupertinoAlertDialog(
      title: const Text('需要登录'),
      content: Text(message ?? '该功能需要登录后使用'),
      actions: [
        CupertinoDialogAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('去登录'),
        ),
      ],
    ),
  );
  
  if (shouldLogin == true && context.mounted) {
    // 跳转到登录页
    final result = await Navigator.of(context).push<bool>(
      CupertinoPageRoute(
        builder: (context) => const LoginScreen(),
        fullscreenDialog: true,
      ),
    );
    
    return result == true;
  }
  
  return false;
}

/// 静默检查是否已登录（不弹窗）
bool isLoggedIn(BuildContext context) {
  final authProvider = Provider.of<AuthProvider>(context, listen: false);
  return authProvider.isLoggedIn;
}

/// 获取当前用户档案
dynamic getCurrentUser(BuildContext context) {
  final authProvider = Provider.of<AuthProvider>(context, listen: false);
  return authProvider.userProfile;
}

