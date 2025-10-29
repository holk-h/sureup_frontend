import 'dart:convert';
import 'package:appwrite/appwrite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../models/user_profile.dart';

/// 认证服务 - 处理用户登录、注册、会话管理
class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  late Client _client;
  late Account _account;
  late Databases _databases;
  late Functions _functions;
  
  String? _userId;  // 当前用户ID
  String? _userPhone;  // 当前用户手机号
  UserProfile? _currentProfile;
  
  // 初始化Appwrite客户端
  void initialize() {
    _client = Client()
        .setEndpoint(ApiConfig.endpoint)
        .setProject(ApiConfig.projectId);
    
    _account = Account(_client);
    _databases = Databases(_client);
    _functions = Functions(_client);
  }

  /// 获取当前用户ID
  String? get userId => _userId;
  
  /// 获取当前用户手机号
  String? get userPhone => _userPhone;
  
  /// 获取当前用户档案
  UserProfile? get currentProfile => _currentProfile;
  
  /// 检查是否已登录
  bool get isLoggedIn => _userId != null;
  
  /// 获取 Appwrite 客户端（供其他服务使用）
  Client get client => _client;
  
  /// 重新加载用户档案（从数据库）
  Future<void> reloadUserProfile() async {
    if (_userId == null) {
      throw Exception('用户未登录');
    }
    await _checkUserProfile(_userId!);
  }

  /// 使用手机号发送验证码
  /// 
  /// 调用云函数，使用火山引擎短信服务发送验证码
  Future<String> sendPhoneVerification(String phone) async {
    try {
      // 标准化手机号格式
      String formattedPhone = _formatPhoneNumber(phone);
      
      // 构造请求体
      final requestBody = {
        'phone': formattedPhone,
      };
      
      print('发送验证码请求参数: $requestBody'); // 调试日志
      
      // 调用发送短信的云函数
      final execution = await _functions.createExecution(
        functionId: 'sms-send',
        body: jsonEncode(requestBody),
      );
      
      // 解析响应
      final response = jsonDecode(execution.responseBody);
      
      if (response['success'] != true) {
        throw Exception(response['message'] ?? '发送验证码失败');
      }
      
      // 返回标准格式的手机号（用于验证时使用）
      return formattedPhone;
    } catch (e) {
      throw _handleAuthError(e);
    }
  }

  /// 验证手机验证码并登录
  /// 
  /// [phone] 手机号（包含+86）
  /// [code] 用户收到的6位验证码
  Future<bool> verifyPhoneAndLogin(String phone, String code) async {
    try {
      // 确保使用标准格式的手机号
      String formattedPhone = _formatPhoneNumber(phone);
      
      // 构造请求体
      final requestBody = {
        'phone': formattedPhone,
        'code': code,
      };
      
      print('验证请求参数: $requestBody'); // 调试日志
      
      // 调用验证短信的云函数
      final execution = await _functions.createExecution(
        functionId: 'sms-verify',
        body: jsonEncode(requestBody),
      );
      
      // 解析响应
      final response = jsonDecode(execution.responseBody);
      
      if (response['success'] != true) {
        throw Exception(response['message'] ?? '验证失败');
      }
      
      final data = response['data'];
      final userId = data['userId'];
      final isNewUser = data['isNewUser'] ?? false;
      final hasProfile = data['hasProfile'] ?? false;
      final sessionToken = data['sessionToken'];  // Session token（长期有效）
      
      print('验证响应数据: userId=$userId, isNewUser=$isNewUser, hasProfile=$hasProfile'); // 调试
      
      // 如果有 Session token，创建会话
      if (sessionToken != null && sessionToken.toString().isNotEmpty) {
        try {
          print('使用 Session Token 创建会话...'); // 调试
          // 使用 Account SDK 的 createSession 方法创建长期会话
          await _account.createSession(
            userId: userId,
            secret: sessionToken.toString(),
          );
          print('Session 创建成功，用户现在已授权（有效期1年）'); // 调试
        } catch (sessionError) {
          print('创建 Session 失败: $sessionError'); // 调试
        }
      } else {
        print('警告: 没有收到 Session token，用户可能无权创建档案'); // 调试
      }
      
      // 保存用户信息到内存
      _userId = userId;
      _userPhone = formattedPhone;  // 使用标准格式的手机号
      
      print('已保存用户信息: _userId=$_userId, _userPhone=$_userPhone'); // 调试
      
      // 如果有档案，加载档案信息
      if (hasProfile) {
        await _checkUserProfile(userId);
      }
      
      // 保存登录状态到本地（Session会自动管理cookie，不需要保存token）
      await _saveLoginState(userId, formattedPhone);
      
      print('登录状态已保存到本地'); // 调试
      
      // 返回true表示需要完善信息（新用户且没有档案）
      final needsSetup = isNewUser && !hasProfile;
      print('needsSetup: $needsSetup (isNewUser=$isNewUser, hasProfile=$hasProfile)'); // 调试
      return needsSetup;
    } catch (e) {
      throw _handleAuthError(e);
    }
  }

  /// 检查用户档案是否存在
  Future<bool> _checkUserProfile(String userId) async {
    try {
      final document = await _databases.getDocument(
        databaseId: ApiConfig.databaseId,
        collectionId: ApiConfig.usersCollectionId,
        documentId: userId,
      );
      
      // 档案存在，加载到内存（需要包含id字段）
      _currentProfile = UserProfile.fromJson({
        'id': document.$id,
        ...document.data,
      });
      return true;
    } catch (e) {
      // 档案不存在
      return false;
    }
  }

  /// 创建用户档案（首次注册时）
  Future<void> createUserProfile({
    required String name,
    int? grade,
    List<String>? focusSubjects,
  }) async {
    try {
      print('createUserProfile 开始: _userId=$_userId, _userPhone=$_userPhone'); // 调试
      
      if (_userId == null) {
        print('createUserProfile 失败: _userId 为 null'); // 调试
        throw Exception('用户未登录');
      }
      
      final now = DateTime.now();
      // 创建用户档案数据
      final profileData = {
        'userId': _userId!,  // 必需字段
        'name': name,
        'avatar': null,  // 头像URL，可选
        'phone': _userPhone,  // 手机号
        'email': null,  // 邮箱，可选
        'grade': grade,
        'focusSubjects': focusSubjects ?? [],
        'totalMistakes': 0,
        'masteredMistakes': 0,
        'totalPracticeSessions': 0,
        'continuousDays': 0,
        'lastActiveAt': now.toIso8601String(),
      };
      
      print('准备创建档案文档，userId: $_userId'); // 调试
      
      // 创建档案文档，使用userId作为documentId
      // 设置文档权限：用户自己可以读写
      final document = await _databases.createDocument(
        databaseId: ApiConfig.databaseId,
        collectionId: ApiConfig.usersCollectionId,
        documentId: _userId!,
        data: profileData,
        permissions: [
          'read("user:$_userId")',   // 用户自己可以读
          'update("user:$_userId")',  // 用户自己可以更新
          'delete("user:$_userId")',  // 用户自己可以删除
        ],
      );
      
      print('档案文档创建成功: ${document.$id}'); // 调试
      
      _currentProfile = UserProfile.fromJson({
        'id': document.$id,
        ...document.data,
      });
      
      print('用户档案创建成功: $_currentProfile'); // 调试
    } catch (e) {
      print('创建用户档案异常: $e'); // 调试
      throw _handleAuthError(e);
    }
  }

  /// 更新用户档案
  Future<void> updateUserProfile({
    String? name,
    String? avatar,
    int? grade,
    List<String>? focusSubjects,
  }) async {
    try {
      if (_userId == null || _currentProfile == null) {
        throw Exception('用户未登录');
      }
      
      final updateData = <String, dynamic>{};
      if (name != null) updateData['name'] = name;
      if (avatar != null) updateData['avatar'] = avatar;
      if (grade != null) updateData['grade'] = grade;
      if (focusSubjects != null) updateData['focusSubjects'] = focusSubjects;
      updateData['lastActiveAt'] = DateTime.now().toIso8601String();
      
      final document = await _databases.updateDocument(
        databaseId: ApiConfig.databaseId,
        collectionId: ApiConfig.usersCollectionId,
        documentId: _userId!,
        data: updateData,
      );
      
      _currentProfile = UserProfile.fromJson({
        'id': document.$id,
        ...document.data,
      });
    } catch (e) {
      throw _handleAuthError(e);
    }
  }

  /// 尝试从本地恢复登录状态
  Future<bool> tryRestoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      final userPhone = prefs.getString('user_phone');
      
      if (userId == null) {
        return false;
      }
      
      // 检查 Appwrite Session 是否有效
      // Session 由 Appwrite 自动管理（通过 cookie），不需要手动设置
      try {
        // 尝试获取当前账户信息，如果session有效则成功
        final account = await _account.get();
        print('Session 有效，用户ID: ${account.$id}'); // 调试
        
        // 恢复用户信息
        _userId = userId;
        _userPhone = userPhone;
        
        // 加载用户档案
        await _checkUserProfile(userId);
        
        return true;
      } catch (e) {
        print('Session 无效或已过期: $e'); // 调试
        // Session 已过期，清除本地数据
        await prefs.clear();
        return false;
      }
    } catch (e) {
      print('恢复会话失败: $e'); // 调试
      // 会话已过期或不存在，清除本地数据
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
      } catch (_) {}
      return false;
    }
  }

  /// 登出
  Future<void> logout() async {
    try {
      // 删除 Appwrite Session
      try {
        await _account.deleteSession(sessionId: 'current');
        print('Session 已删除'); // 调试
      } catch (e) {
        print('删除 Session 失败（可能已过期）: $e'); // 调试
      }
      
      // 清除内存中的用户数据
      _userId = null;
      _userPhone = null;
      _currentProfile = null;
      
      // 清除本地存储
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } catch (e) {
      throw _handleAuthError(e);
    }
  }

  /// 保存登录状态到本地
  Future<void> _saveLoginState(String userId, String phone) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_id', userId);
    await prefs.setString('user_phone', phone);
    await prefs.setBool('is_logged_in', true);
    
    print('登录状态已保存到本地（Session由Appwrite自动管理）'); // 调试
  }

  /// 标准化手机号格式
  /// 
  /// 确保手机号以+86开头，用于与后端API保持一致
  String _formatPhoneNumber(String phone) {
    // 移除所有空格和特殊字符
    String cleanPhone = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    
    // 如果已经有+86前缀，直接返回
    if (cleanPhone.startsWith('+86')) {
      return cleanPhone;
    }
    
    // 如果有+但不是+86，移除+
    if (cleanPhone.startsWith('+')) {
      cleanPhone = cleanPhone.substring(1);
    }
    
    // 如果以86开头，添加+
    if (cleanPhone.startsWith('86') && cleanPhone.length == 13) {
      return '+$cleanPhone';
    }
    
    // 如果是11位纯数字，添加+86
    if (cleanPhone.length == 11 && RegExp(r'^1[3-9]\d{9}$').hasMatch(cleanPhone)) {
      return '+86$cleanPhone';
    }
    
    // 默认添加+86前缀
    return '+86$cleanPhone';
  }

  /// 处理认证错误
  String _handleAuthError(dynamic error) {
    if (error is AppwriteException) {
      switch (error.code) {
        case 401:
          // 401 错误可能是验证码错误，也可能是登录会话过期
          if (_userId != null) {
            return '登录已过期，请重新登录';
          }
          return '验证码错误或已过期';
        case 404:
          return '用户不存在';
        case 409:
          return '该手机号已注册';
        case 429:
          return '请求过于频繁，请稍后再试';
        default:
          return error.message ?? '认证失败，请重试';
      }
    }
    return error.toString();
  }
}

