import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:appwrite/appwrite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'appwrite_service.dart';

/// 订阅产品 ID
class SubscriptionProducts {
  static const String monthlyPremium = 'monthly_premium';

  /// 根据平台获取产品 ID
  static String getPlatformProductId() {
    return monthlyPremium;
  }
}

/// 订阅状态
class SubscriptionStatus {
  final bool isPremium;
  final DateTime? expiryDate;
  final bool autoRenew;

  SubscriptionStatus({
    required this.isPremium,
    this.expiryDate,
    this.autoRenew = false,
  });

  bool get isActive {
    if (!isPremium) return false;
    if (expiryDate == null) return false;
    // 统一使用 UTC 时间比较
    return expiryDate!.isAfter(DateTime.now().toUtc());
  }
}

/// 订阅服务
class SubscriptionService extends ChangeNotifier {
  final InAppPurchase _iap = InAppPurchase.instance;
  final AppwriteService _appwrite;
  
  // 用于获取当前用户 ID
  String? Function()? _getUserId;

  // 订阅状态
  SubscriptionStatus? _status;
  SubscriptionStatus? get status => _status;

  // 可用产品
  List<ProductDetails> _products = [];
  List<ProductDetails> get products => _products;

  // 是否可用
  bool _isAvailable = false;
  bool get isAvailable => _isAvailable;

  // 加载状态
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // 购买流监听
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  // 错误消息
  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // 🚀 初始化标志：用于忽略开屏时自动推送的历史购买
  bool _isInitializing = true;

  SubscriptionService(this._appwrite, {String? Function()? getUserId})
      : _getUserId = getUserId {
    _initializeService();
  }
  
  /// 设置获取用户 ID 的回调
  void setGetUserId(String? Function() getUserId) {
    _getUserId = getUserId;
  }

  /// 初始化服务
  Future<void> _initializeService() async {
    _isAvailable = await _iap.isAvailable();
    if (!_isAvailable) {
      debugPrint('⚠️ In-app purchase not available');
      return;
    }

    // 监听购买更新
    _subscription = _iap.purchaseStream.listen(
      _handlePurchaseUpdates,
      onError: (error) {
        debugPrint('❌ Purchase stream error: $error');
        _errorMessage = error.toString();
        notifyListeners();
      },
    );

    // 🚀 优化：只加载产品和订阅状态，不自动恢复购买
    // 恢复购买应该由用户主动触发，而不是开屏自动执行
    await Future.wait([_loadProducts(), loadSubscriptionStatus()]);
    
    // 🚀 延迟标记初始化完成，给 purchaseStream 时间推送历史记录
    // 这样我们可以忽略这些自动推送的记录
    Future.delayed(const Duration(seconds: 2), () {
      _isInitializing = false;
      debugPrint('✅ SubscriptionService initialization complete, will now process new purchases');
    });
    
    debugPrint('✅ SubscriptionService initialized (ignoring auto-pushed purchases)');
  }

  /// 加载可用产品
  Future<void> _loadProducts() async {
    if (!_isAvailable) return;

    try {
      final Set<String> productIds = {
        SubscriptionProducts.getPlatformProductId(),
      };
      final ProductDetailsResponse response = await _iap.queryProductDetails(
        productIds,
      );

      if (response.error != null) {
        debugPrint('❌ Failed to load products: ${response.error}');
        _errorMessage = response.error!.message;
        return;
      }

      _products = response.productDetails;
      debugPrint('✅ Loaded ${_products.length} products');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error loading products: $e');
      _errorMessage = e.toString();
    }
  }

  /// 从服务器加载订阅状态
  Future<void> loadSubscriptionStatus() async {
    try {
      // 尝试从回调获取 userId
      String? userId = _getUserId?.call();
      
      // 如果回调没有设置或返回 null，尝试从 SharedPreferences 获取
      if (userId == null) {
        final prefs = await SharedPreferences.getInstance();
        userId = prefs.getString('userId');
      }
      
      if (userId == null) {
        debugPrint('⚠️ Cannot load subscription status: user not logged in');
        _status = SubscriptionStatus(isPremium: false);
        notifyListeners();
        return;
      }

      // 从 profiles 表获取订阅状态
      final databases = _appwrite.databases;
      final profiles = await databases.listDocuments(
        databaseId: 'main',
        collectionId: 'profiles',
        queries: [Query.equal('userId', userId), Query.limit(1)],
      );

      if (profiles.documents.isEmpty) {
        _status = SubscriptionStatus(isPremium: false);
        notifyListeners();
        return;
      }

      final profile = profiles.documents.first.data;
      final subscriptionStatus = profile['subscriptionStatus'] ?? 'free';
      final expiryDateStr = profile['subscriptionExpiryDate'];

      debugPrint('📋 Profile data:');
      debugPrint('   subscriptionStatus: $subscriptionStatus');
      debugPrint('   subscriptionExpiryDate: $expiryDateStr');

      DateTime? expiryDate;
      if (expiryDateStr != null) {
        expiryDate = DateTime.parse(expiryDateStr).toUtc();
        final nowUtc = DateTime.now().toUtc();
        debugPrint('   Parsed expiry date (UTC): $expiryDate');
        debugPrint('   Current time (UTC): $nowUtc');
        debugPrint('   Is after now? ${expiryDate.isAfter(nowUtc)}');
      }

      final nowUtc = DateTime.now().toUtc();
      final isPremium = subscriptionStatus == 'active' &&
          expiryDate != null &&
          expiryDate.isAfter(nowUtc);

      _status = SubscriptionStatus(
        isPremium: isPremium,
        expiryDate: expiryDate,
        autoRenew: true,
      );

      debugPrint('✅ Subscription status loaded: isPremium=$isPremium');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error loading subscription status: $e');
      _status = SubscriptionStatus(isPremium: false);
      notifyListeners();
    }
  }

  /// 购买订阅
  Future<bool> purchaseSubscription() async {
    debugPrint('🛒 purchaseSubscription called');
    debugPrint('🛒 Current isLoading state: $_isLoading');
    debugPrint('🛒 Current subscription status: ${_status?.isPremium}');
    
    if (!_isAvailable || _products.isEmpty) {
      debugPrint('❌ Subscription service not available');
      _errorMessage = '订阅服务不可用';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final product = _products.first;
      debugPrint('🛒 Purchasing product: ${product.id}');
      debugPrint('   Price: ${product.price}');
      debugPrint('   Title: ${product.title}');
      
      final PurchaseParam purchaseParam = PurchaseParam(
        productDetails: product,
      );

      // 发起购买请求
      // 注意：这里只是发起请求，不代表购买完成
      // 实际购买结果会通过 _handlePurchaseUpdates 回调处理
      debugPrint('🛒 Calling buyNonConsumable...');
      final bool success = await _iap.buyNonConsumable(
        purchaseParam: purchaseParam,
      );

      debugPrint('🛒 buyNonConsumable returned: $success');

      if (!success) {
        // buyNonConsumable 返回 false 通常表示用户取消或无法发起购买
        debugPrint('🚫 Purchase request failed or canceled');
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // 设置超时保护：如果10秒内没有收到状态回调，重置加载状态
      debugPrint('⏰ Setting 10s timeout protection...');
      Future.delayed(const Duration(seconds: 10), () {
        if (_isLoading) {
          debugPrint('⚠️ Purchase timeout, resetting loading state');
          _isLoading = false;
          notifyListeners();
        }
      });

      debugPrint('🛒 Purchase request initiated, waiting for callback...');
      // 返回 true 只表示购买请求已发起
      // 实际购买结果会通过监听回调处理
      return true;
    } catch (e) {
      debugPrint('❌ Purchase error: $e');
      debugPrint('❌ Error type: ${e.runtimeType}');
      _errorMessage = '购买失败: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// 处理购买更新
  Future<void> _handlePurchaseUpdates(
    List<PurchaseDetails> purchaseDetailsList,
  ) async {
    debugPrint('🔄 _handlePurchaseUpdates called with ${purchaseDetailsList.length} items');
    debugPrint('   Is initializing: $_isInitializing');
    
    for (final PurchaseDetails purchaseDetails in purchaseDetailsList) {
      debugPrint('📦 Purchase update:');
      debugPrint('   Status: ${purchaseDetails.status}');
      debugPrint('   Product ID: ${purchaseDetails.productID}');
      debugPrint('   Transaction Date: ${purchaseDetails.transactionDate}');
      debugPrint('   Pending Complete: ${purchaseDetails.pendingCompletePurchase}');

      // 🚀 关键优化：初始化阶段忽略所有 restored 状态的购买
      // 这些是 iOS 自动推送的历史购买记录，不需要验证
      if (_isInitializing && purchaseDetails.status == PurchaseStatus.restored) {
        debugPrint('⏭️ Skipping auto-pushed restored purchase during initialization');
        // 直接完成交易，避免重复推送
        if (purchaseDetails.pendingCompletePurchase) {
          await _iap.completePurchase(purchaseDetails);
          debugPrint('🏁 Completed without verification (initialization phase)');
        }
        continue; // 跳过这条记录2
      }

      if (purchaseDetails.status == PurchaseStatus.pending) {
        // 购买进行中
        debugPrint('⏳ Purchase is pending...');
        _isLoading = true;
        notifyListeners();
      } else if (purchaseDetails.status == PurchaseStatus.canceled) {
        // 用户取消购买
        debugPrint('🚫 Purchase canceled by user');
        _errorMessage = null; // 清除错误信息，不显示为错误
        _isLoading = false;
        notifyListeners();
      } else if (purchaseDetails.status == PurchaseStatus.error) {
        // 购买失败
        debugPrint('❌ Purchase error: ${purchaseDetails.error?.message}');
        debugPrint('   Error code: ${purchaseDetails.error?.code}');
        debugPrint('   Error details: ${purchaseDetails.error?.details}');
        _errorMessage = purchaseDetails.error?.message ?? '购买失败';
        _isLoading = false;
        notifyListeners();
      } else if (purchaseDetails.status == PurchaseStatus.purchased ||
          purchaseDetails.status == PurchaseStatus.restored) {
        // 购买成功或用户主动恢复，验证收据
        debugPrint('✅ Purchase/Restore confirmed! Now verifying...');
        final bool valid = await _verifyPurchase(purchaseDetails);
        if (valid) {
          // 验证成功
          debugPrint('✅ Verification successful, updating subscription status...');
          await loadSubscriptionStatus();
          _isLoading = false;
          notifyListeners();
        } else {
          debugPrint('❌ Verification failed');
          _errorMessage = '收据验证失败';
          _isLoading = false;
          notifyListeners();
        }
      } else {
        debugPrint('⚠️ Unknown purchase status: ${purchaseDetails.status}');
      }

      // 完成购买
      if (purchaseDetails.pendingCompletePurchase) {
        debugPrint('🏁 Completing purchase...');
        await _iap.completePurchase(purchaseDetails);
        debugPrint('🏁 Purchase completed');
      }
    }
    
    debugPrint('🔄 _handlePurchaseUpdates finished');
  }

  /// 验证购买（调用后端）
  Future<bool> _verifyPurchase(PurchaseDetails purchaseDetails) async {
    try {
      // 尝试从回调获取 userId
      String? userId = _getUserId?.call();
      
      // 如果回调没有设置或返回 null，尝试从 SharedPreferences 获取
      if (userId == null) {
        debugPrint('⚠️ getUserId callback not set or returned null, trying SharedPreferences...');
        final prefs = await SharedPreferences.getInstance();
        userId = prefs.getString('userId');
      }
      
      if (userId == null) {
        debugPrint('❌ User ID not found - user may not be logged in');
        debugPrint('⚠️ Skipping verification for now. User needs to restore purchases after login.');
        return false;
      }
      
      debugPrint('✅ Got userId: $userId');

      debugPrint('🔐 Verifying purchase for product: ${purchaseDetails.productID}');

      // 🚀 从 PurchaseDetails 获取 transactionId（用于缓存检查）
      String? transactionId;
      if (Platform.isIOS) {
        // iOS: 使用 purchaseID (对应 Apple 的 transactionIdentifier)
        transactionId = purchaseDetails.purchaseID;
      } else {
        // Android: 使用 purchaseID 或 serverVerificationData 的哈希
        transactionId = purchaseDetails.purchaseID;
      }
      
      debugPrint('📋 Transaction ID: $transactionId');

      // 构建验证请求
      Map<String, dynamic> requestBody = {
        'userId': userId,
        'platform': Platform.isIOS ? 'ios' : 'android',
        'productId': purchaseDetails.productID,
        'transactionId': transactionId, // 🚀 传递 transactionId 用于缓存检查
      };

      if (Platform.isIOS) {
        // iOS: 发送收据数据
        final String receiptData =
            purchaseDetails.verificationData.serverVerificationData;
        requestBody['receiptData'] = receiptData;
        debugPrint('📄 Receipt data length: ${receiptData.length}');
      } else {
        // Android: 发送购买令牌
        requestBody['purchaseToken'] =
            purchaseDetails.verificationData.serverVerificationData;
        requestBody['packageName'] = 'com.example.sureup'; // 替换为实际包名
      }

      // 转换为 JSON 字符串
      final requestBodyJson = jsonEncode(requestBody);
      debugPrint('📤 Sending verification request with cache support');

      // 🚀 调用验证 Function
      // 后端已配置为异步执行（async: true），所以会立即返回 execution 对象
      final functions = _appwrite.functions;
      debugPrint('🔧 Calling subscription-verify function (backend async mode)...');
      
      final execution = await functions.createExecution(
        functionId: 'subscription-verify',
        body: requestBodyJson,
      );

      debugPrint('📥 Function execution started: ${execution.$id}');
      debugPrint('📥 Function status: ${execution.status}');
      debugPrint('📥 Response body: ${execution.responseBody}');
      
      // 🚀 检查是否是已过期的订阅
      try {
        final responseJson = jsonDecode(execution.responseBody);
        if (responseJson['isExpired'] == true) {
          debugPrint('⚠️ 检测到已过期的订阅记录');
          debugPrint('   这是沙盒环境特有现象：测试订阅过期后无法重新购买');
          debugPrint('   生产环境中用户可以正常续订');
          _errorMessage = '沙盒测试订阅已过期\n请使用新的测试账号或在生产环境测试';
          return false; // 返回 false 表示验证失败（过期）
        }
      } catch (e) {
        debugPrint('⚠️ Failed to parse response: $e');
      }
      
      // 🚀 后端配置为异步执行，function 会在后台处理
      // 订阅状态会通过后端更新，前端稍后刷新即可
      
      // 短暂延迟后刷新订阅状态（给后端一点时间处理）
      Future.delayed(const Duration(seconds: 3), () {
        debugPrint('🔄 Refreshing subscription status after async verification...');
        loadSubscriptionStatus();
      });
      
      // 再延迟一次（防止第一次刷新时后端还未完成）
      Future.delayed(const Duration(seconds: 6), () {
        debugPrint('🔄 Second refresh for subscription status...');
        loadSubscriptionStatus();
      });
      
      // 返回 true 表示验证请求已发送
      return true;
    } catch (e) {
      debugPrint('❌ Verification error: $e');
      debugPrint('❌ Error type: ${e.runtimeType}');
      return false;
    }
  }

  /// 恢复购买
  Future<void> restorePurchases() async {
    if (!_isAvailable) {
      _errorMessage = '订阅服务不可用';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    debugPrint('🔄 开始恢复购买...');
    
    // 🚀 标记不再是初始化阶段，允许处理恢复的购买
    _isInitializing = false;

    try {
      await _iap.restorePurchases();
      
      // 🚀 设置超时保护：如果15秒内没有收到状态回调，检查最终状态
      Future.delayed(const Duration(seconds: 15), () async {
        if (_isLoading) {
          debugPrint('⚠️ Restore timeout, checking final status...');
          _isLoading = false;
          
          // 刷新订阅状态以获取最终结果
          await loadSubscriptionStatus();
          
          // 根据订阅状态给出不同提示
          if (_status?.isActive == true) {
            debugPrint('✅ 恢复成功：订阅已激活');
            // 成功恢复，不显示错误消息
            _errorMessage = null;
          } else {
            debugPrint('⚠️ 恢复完成：未找到有效订阅');
            _errorMessage = '没有找到有效的订阅记录';
          }
          
          notifyListeners();
        }
      });
      
      // 恢复结果会通过 _handlePurchaseUpdates 处理
    } catch (e) {
      debugPrint('❌ Restore error: $e');
      _errorMessage = '恢复购买失败: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 清除错误消息
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
