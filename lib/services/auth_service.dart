import 'dart:convert';
import 'package:appwrite/appwrite.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../config/api_config.dart';
import '../models/user_profile.dart';
import 'local_storage_service.dart';
import 'notification_service.dart';

/// 认证服务 - 处理用户登录、注册、会话管理
class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  late Client _client;
  late Account _account;
  late Databases _databases;
  late Functions _functions;
  final LocalStorageService _localStorage = LocalStorageService();
  final NotificationService _notificationService = NotificationService();
  
  String? _userId;  // 当前用户ID
  String? _userPhone;  // 当前用户手机号
  UserProfile? _currentProfile;
  
  // 初始化Appwrite客户端和本地存储
  Future<void> initialize() async {
    _client = Client()
        .setEndpoint(ApiConfig.endpoint)
        .setProject(ApiConfig.projectId);
    
    _account = Account(_client);
    _databases = Databases(_client);
    _functions = Functions(_client);
    
    await _localStorage.initialize();
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
      
      // 注册 APNs push target（如果是 iOS 设备）
      try {
        await _notificationService.registerPushTarget(_account);
      } catch (e) {
        print('⚠️ 注册 push target 时发生错误: $e');
        // 不影响登录流程
      }
      
      // 返回true表示需要完善信息（新用户且没有档案）
      final needsSetup = isNewUser && !hasProfile;
      print('needsSetup: $needsSetup (isNewUser=$isNewUser, hasProfile=$hasProfile)'); // 调试
      return needsSetup;
    } catch (e) {
      throw _handleAuthError(e);
    }
  }

  /// 使用苹果登录
  /// 
  /// 返回 true 表示需要完善用户信息（新用户且没有档案）
  Future<bool> signInWithApple() async {
    try {
      // 1. 调用苹果登录
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        // 如果需要使用 Service ID 而不是 Bundle ID，取消下面的注释
        // webAuthenticationOptions: WebAuthenticationOptions(
        //   clientId: 'com.example.sureup.signin',  // 你的 Service ID
        //   redirectUri: Uri.parse('https://your-domain.com/callback'),
        // ),
      );
      
      print('苹果登录成功，User ID: ${credential.userIdentifier}'); // 调试
      
      // 验证必需字段
      if (credential.identityToken == null || credential.identityToken!.isEmpty) {
        throw Exception('未获取到有效的身份令牌');
      }
      
      if (credential.userIdentifier == null || credential.userIdentifier!.isEmpty) {
        throw Exception('未获取到用户标识');
      }
      
      // 2. 构造请求体
      final requestBody = {
        'identityToken': credential.identityToken,
        'userIdentifier': credential.userIdentifier,
        'email': credential.email,
        'givenName': credential.givenName,
        'familyName': credential.familyName,
      };
      
      print('苹果登录验证请求: ${requestBody.keys.toList()}'); // 调试
      
      // 3. 调用后端验证函数
      final execution = await _functions.createExecution(
        functionId: 'apple-signin',
        body: jsonEncode(requestBody),
      );
      
      // 4. 解析响应
      final response = jsonDecode(execution.responseBody);
      
      if (response['success'] != true) {
        throw Exception(response['message'] ?? '苹果登录验证失败');
      }
      
      final data = response['data'];
      final userId = data['userId'];
      final isNewUser = data['isNewUser'] ?? false;
      final hasProfile = data['hasProfile'] ?? false;
      final sessionToken = data['sessionToken'];
      final email = data['email'];
      
      print('苹果登录验证成功: userId=$userId, isNewUser=$isNewUser, hasProfile=$hasProfile'); // 调试
      
      // 5. 创建会话
      if (sessionToken == null || sessionToken.toString().isEmpty) {
        throw Exception('未获取到会话令牌，无法创建会话');
      }
      
      try {
        print('使用 Session Token 创建会话...'); // 调试
        await _account.createSession(
          userId: userId,
          secret: sessionToken.toString(),
        );
        print('Session 创建成功'); // 调试
      } catch (sessionError) {
        print('创建 Session 失败: $sessionError'); // 调试
        throw Exception('创建会话失败: ${sessionError.toString()}');
      }
      
      // 6. 保存用户信息到内存
      _userId = userId;
      _userPhone = email;  // 对于苹果登录，我们用 email 代替 phone
      
      print('已保存用户信息: _userId=$_userId'); // 调试
      
      // 7. 如果有档案，加载档案信息
      if (hasProfile) {
        await _checkUserProfile(userId);
      }
      
      // 8. 保存登录状态到本地
      await _saveLoginState(userId, email ?? '');
      
      print('苹果登录状态已保存到本地'); // 调试
      
      // 注册 APNs push target（如果是 iOS 设备）
      try {
        await _notificationService.registerPushTarget(_account);
      } catch (e) {
        print('⚠️ 注册 push target 时发生错误: $e');
        // 不影响登录流程
      }
      
      // 9. 返回是否需要完善信息
      final needsSetup = isNewUser && !hasProfile;
      print('needsSetup: $needsSetup'); // 调试
      return needsSetup;
      
    } on SignInWithAppleAuthorizationException catch (e) {
      // 用户取消登录或其他苹果登录特定错误
      print('苹果登录授权失败: ${e.code} - ${e.message}'); // 调试
      if (e.code == AuthorizationErrorCode.canceled) {
        throw Exception('用户取消了登录');
      } else if (e.code == AuthorizationErrorCode.failed) {
        throw Exception('登录失败，请重试');
      } else if (e.code == AuthorizationErrorCode.notHandled) {
        throw Exception('登录未处理');
      } else {
        throw Exception('苹果登录失败: ${e.message}');
      }
    } catch (e) {
      print('苹果登录失败: $e'); // 调试
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
      
      // 同时保存到本地
      await _localStorage.saveUserInfo(userId, {
        'id': document.$id,
        'name': _currentProfile!.name,
        'avatar': _currentProfile!.avatar,
        'phone': _currentProfile!.phone,
        'email': _currentProfile!.email,
        'grade': _currentProfile!.grade,
        'focusSubjects': _currentProfile!.focusSubjects,
        'createdAt': _currentProfile!.createdAt.toIso8601String(),
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
      // 获取设备时区
      final deviceTimezone = now.timeZoneName;
      // 将时区名称转换为标准格式（如果可能）
      String timezone = 'Asia/Shanghai'; // 默认时区
      if (deviceTimezone.contains('GMT+8') || deviceTimezone.contains('CST')) {
        timezone = 'Asia/Shanghai';
      } else if (deviceTimezone.contains('GMT+9') || deviceTimezone.contains('JST')) {
        timezone = 'Asia/Tokyo';
      } else if (deviceTimezone.contains('GMT-5') || deviceTimezone.contains('EST')) {
        timezone = 'America/New_York';
      } else if (deviceTimezone.contains('GMT-8') || deviceTimezone.contains('PST')) {
        timezone = 'America/Los_Angeles';
      }
      // 可以根据需要添加更多时区映射
      
      print('检测到设备时区: $deviceTimezone，使用: $timezone'); // 调试
      
      // 创建用户档案数据
      final profileData = {
        'userId': _userId!,  // 必需字段
        'name': name,
        'avatar': null,  // 头像URL，可选
        'phone': _userPhone,  // 手机号
        'email': null,  // 邮箱，可选
        'grade': grade,
        'focusSubjects': focusSubjects ?? [],
        'timezone': timezone,  // 添加时区字段
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
      
      // 保存到本地
      await _localStorage.saveUserInfo(_userId!, {
        'id': document.$id,
        'name': name,
        'phone': _userPhone,
        'grade': grade,
        'focusSubjects': focusSubjects ?? [],
        'createdAt': now.toIso8601String(),
      });
      
      // 初始化统计数据到本地
      await _localStorage.saveUserStats(_userId!, {
        'totalMistakes': 0,
        'masteredMistakes': 0,
        'totalPracticeSessions': 0,
        'completedSessions': 0,
        'continuousDays': 0,
        'weekMistakes': 0,
        'userName': name,
        'usageDays': 1,
        'createdAt': now.toIso8601String(),
        'statsUpdatedAt': now.toIso8601String(),
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
    String? dailyTaskDifficulty,
    bool? dailyTaskReminderEnabled,
    bool? reviewReminderEnabled,
    String? reviewReminderTime,
    String? timezone,
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
      if (dailyTaskDifficulty != null) updateData['dailyTaskDifficulty'] = dailyTaskDifficulty;
      if (dailyTaskReminderEnabled != null) updateData['dailyTaskReminderEnabled'] = dailyTaskReminderEnabled;
      if (reviewReminderEnabled != null) updateData['reviewReminderEnabled'] = reviewReminderEnabled;
      if (reviewReminderTime != null) updateData['reviewReminderTime'] = reviewReminderTime;
      if (timezone != null) updateData['timezone'] = timezone;
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
      
      // 更新本地用户信息
      await _localStorage.saveUserInfo(_userId!, {
        'id': document.$id,
        'name': _currentProfile!.name,
        'avatar': _currentProfile!.avatar,
        'phone': _currentProfile!.phone,
        'email': _currentProfile!.email,
        'grade': _currentProfile!.grade,
        'focusSubjects': _currentProfile!.focusSubjects,
        'createdAt': _currentProfile!.createdAt.toIso8601String(),
      });
    } catch (e) {
      throw _handleAuthError(e);
    }
  }

  /// 更新每周复习数据（用于统计图表）
  Future<void> updateWeeklyReviewData(int questionCount) async {
    try {
      if (_userId == null) {
        throw Exception('用户未登录');
      }
      
      // 重新加载当前profile以获取最新数据
      await reloadUserProfile();
      
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final todayStr = '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      
      // 解析现有数据
      List<Map<String, dynamic>> weeklyData = [];
      if (_currentProfile?.weeklyReviewData != null && _currentProfile!.weeklyReviewData!.isNotEmpty) {
        try {
          final decoded = jsonDecode(_currentProfile!.weeklyReviewData!);
          if (decoded is List) {
            weeklyData = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
          }
        } catch (e) {
          print('⚠️ 解析 weeklyReviewData 失败: $e');
        }
      }
      
      // 查找今天的记录
      int todayIndex = -1;
      for (int i = 0; i < weeklyData.length; i++) {
        if (weeklyData[i]['date'] == todayStr) {
          todayIndex = i;
          break;
        }
      }
      
      // 更新或添加今天的记录
      if (todayIndex >= 0) {
        weeklyData[todayIndex]['count'] = (weeklyData[todayIndex]['count'] as int? ?? 0) + questionCount;
      } else {
        weeklyData.add({
          'date': todayStr,
          'count': questionCount,
        });
      }
      
      // 只保留最近7天的数据
      final sevenDaysAgo = today.subtract(const Duration(days: 6));
      weeklyData = weeklyData.where((entry) {
        try {
          final entryDate = DateTime.parse(entry['date'] as String);
          return entryDate.isAfter(sevenDaysAgo.subtract(const Duration(days: 1))) || 
                 entryDate.isAtSameMomentAs(sevenDaysAgo);
        } catch (e) {
          return false;
        }
      }).toList();
      
      // 按日期排序
      weeklyData.sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));
      
      // 转换为JSON字符串
      final weeklyDataStr = jsonEncode(weeklyData);
      
      // 更新到数据库
      await _databases.updateDocument(
        databaseId: ApiConfig.databaseId,
        collectionId: ApiConfig.usersCollectionId,
        documentId: _userId!,
        data: {
          'weeklyReviewData': weeklyDataStr,
          'lastActiveAt': DateTime.now().toIso8601String(),
        },
      );
      
      print('✅ 更新 weeklyReviewData 成功: $weeklyDataStr');
    } catch (e) {
      print('⚠️ 更新 weeklyReviewData 失败: $e');
      // 不抛出异常，避免影响用户体验
    }
  }

  /// 尝试从本地恢复登录状态
  Future<bool> tryRestoreSession() async {
    try {
      // 先从本地读取用户信息
      final prefs = await _localStorage.prefs;
      final userId = prefs.getString('user_id');
      final userPhone = prefs.getString('user_phone');
      
      if (userId == null) {
        return false;
      }
      
      // 检查 Appwrite Session 是否有效
      try {
        // 尝试获取当前账户信息，如果session有效则成功
        final account = await _account.get();
        print('Session 有效，用户ID: ${account.$id}'); // 调试
        
        // 恢复用户信息
        _userId = userId;
        _userPhone = userPhone;
        
        // 优先从本地加载用户档案
        final localUserInfo = await _localStorage.getUserInfo(userId);
        if (localUserInfo != null) {
          _currentProfile = UserProfile.fromJson(localUserInfo);
          print('📦 从本地恢复用户档案: ${_currentProfile!.name}');
        } else {
          // 本地没有，从云端加载
          await _checkUserProfile(userId);
        }
        
        return true;
      } catch (e) {
        print('Session 无效或已过期: $e'); // 调试
        // Session 已过期，清除本地数据
        await _localStorage.clearAll();
        return false;
      }
    } catch (e) {
      print('恢复会话失败: $e'); // 调试
      // 会话已过期或不存在，清除本地数据
      await _localStorage.clearAll();
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
      
      // 清除本地存储（包括用户信息、统计数据、图表数据等）
      await _localStorage.clearAll();
      print('✅ 已清除所有本地数据');
    } catch (e) {
      throw _handleAuthError(e);
    }
  }

  /// 保存登录状态到本地
  Future<void> _saveLoginState(String userId, String phone) async {
    final prefs = await _localStorage.prefs;
    await prefs.setString('user_id', userId);
    await prefs.setString('user_phone', phone);
    await prefs.setBool('is_logged_in', true);
    
    print('💾 登录状态已保存到本地（Session由Appwrite自动管理）'); // 调试
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

