import 'package:flutter/foundation.dart';
import '../services/auth_service.dart';
import '../models/user_profile.dart';

/// 认证状态提供者 - 管理全局登录状态
class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  
  bool _isInitialized = false;
  bool _isLoggedIn = false;
  UserProfile? _userProfile;
  
  bool get isInitialized => _isInitialized;
  bool get isLoggedIn => _isLoggedIn;
  UserProfile? get userProfile => _userProfile;
  AuthService get authService => _authService;
  
  AuthProvider() {
    _initialize();
  }
  
  /// 初始化 - 静默尝试恢复会话
  Future<void> _initialize() async {
    try {
      // 初始化 AuthService（包括本地存储）
      await _authService.initialize();
      
      // 尝试恢复之前的会话
      final hasSession = await _authService.tryRestoreSession();
      _isLoggedIn = hasSession;
      if (hasSession) {
        _userProfile = _authService.currentProfile;
      }
    } catch (e) {
      _isLoggedIn = false;
      _userProfile = null;
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }
  
  /// 登录成功后调用
  Future<void> onLoginSuccess() async {
    _isLoggedIn = true;
    _userProfile = _authService.currentProfile;
    notifyListeners();
  }
  
  /// 刷新用户档案（从数据库重新加载）
  Future<void> refreshProfile() async {
    if (!_isLoggedIn) return;
    
    try {
      final userId = _authService.userId;
      if (userId != null) {
        // 从数据库重新加载用户档案
        await _authService.reloadUserProfile();
        _userProfile = _authService.currentProfile;
        
        // 如果档案仍然为空，为老用户创建默认档案
        if (_userProfile == null) {
          print('用户档案不存在，创建默认档案...');
          final phone = _authService.userPhone;
          final phoneSuffix = phone != null && phone.length >= 4 
              ? phone.substring(phone.length - 4) 
              : '0000';
          
          await _authService.createUserProfile(
            name: '用户$phoneSuffix',
            grade: null,
            focusSubjects: [],
          );
          
          _userProfile = _authService.currentProfile;
        }
        
        notifyListeners();
      }
    } catch (e) {
      print('刷新档案失败：$e');
      // 静默失败，不影响用户体验
    }
  }
  
  /// 登出
  Future<void> logout() async {
    try {
      await _authService.logout();
      _isLoggedIn = false;
      _userProfile = null;
      notifyListeners();
    } catch (e) {
      throw Exception('登出失败：$e');
    }
  }
  
  /// 更新用户档案
  Future<void> updateProfile({
    String? name,
    String? avatar,
    int? grade,
    List<String>? focusSubjects,
    String? dailyTaskDifficulty,
    bool? dailyTaskReminderEnabled,
    bool? reviewReminderEnabled,
    String? reviewReminderTime,
  }) async {
    try {
      await _authService.updateUserProfile(
        name: name,
        avatar: avatar,
        grade: grade,
        focusSubjects: focusSubjects,
        dailyTaskDifficulty: dailyTaskDifficulty,
        dailyTaskReminderEnabled: dailyTaskReminderEnabled,
        reviewReminderEnabled: reviewReminderEnabled,
        reviewReminderTime: reviewReminderTime,
      );
      // 重新加载用户档案
      _userProfile = _authService.currentProfile;
      notifyListeners();
    } catch (e) {
      print('更新档案失败：$e');
      
      // 检查是否是会话过期错误
      final errorMessage = e.toString();
      if (errorMessage.contains('登录已过期') || 
          errorMessage.contains('401') ||
          errorMessage.contains('Unauthorized')) {
        // 会话过期，自动登出
        print('检测到会话过期，自动登出');
        await logout();
        throw Exception('登录已过期，请重新登录');
      }
      
      throw Exception('更新档案失败：$e');
    }
  }
  
  /// 检查会话是否有效
  bool get hasValidSession => _isLoggedIn && _userProfile != null;
}

