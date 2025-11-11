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

    // 加载产品和状态
    await Future.wait([_loadProducts(), loadSubscriptionStatus()]);
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
    
    for (final PurchaseDetails purchaseDetails in purchaseDetailsList) {
      debugPrint('📦 Purchase update:');
      debugPrint('   Status: ${purchaseDetails.status}');
      debugPrint('   Product ID: ${purchaseDetails.productID}');
      debugPrint('   Transaction Date: ${purchaseDetails.transactionDate}');
      debugPrint('   Pending Complete: ${purchaseDetails.pendingCompletePurchase}');

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
        // 购买成功，验证收据
        debugPrint('✅ Purchase successful! Now verifying...');
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

      // 构建验证请求
      Map<String, dynamic> requestBody = {
        'userId': userId,
        'platform': Platform.isIOS ? 'ios' : 'android',
        'productId': purchaseDetails.productID, // 添加 productId
      };

      if (Platform.isIOS) {
        // iOS: 发送收据数据
        final String? receiptData =
            purchaseDetails.verificationData.serverVerificationData;
        if (receiptData == null) {
          debugPrint('❌ No receipt data');
          return false;
        }
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
      debugPrint('📤 Sending verification request: $requestBodyJson');

      // 调用验证 Function
      final functions = _appwrite.functions;
      debugPrint('🔧 Calling subscription-verify function...');
      
      final execution = await functions.createExecution(
        functionId: 'subscription-verify',
        body: requestBodyJson,
      );

      debugPrint('📥 Function execution status: ${execution.status}');
      debugPrint('📥 Function response code: ${execution.responseStatusCode}');

      // 检查 HTTP 响应码而非 execution.status（它是枚举类型）
      if (execution.responseStatusCode != 200) {
        debugPrint('❌ Function returned non-200 status code: ${execution.responseStatusCode}');
        debugPrint('❌ Response body: ${execution.responseBody}');
        return false;
      }

      final response = execution.responseBody;
      debugPrint('✅ Verification response (HTTP 200): $response');

      // 解析响应
      try {
        final responseJson = jsonDecode(response);
        if (responseJson['success'] == true) {
          debugPrint('✅ Purchase verified successfully!');
          return true;
        } else {
          debugPrint('❌ Verification failed: ${responseJson['message']}');
          return false;
        }
      } catch (e) {
        debugPrint('⚠️ Failed to parse response as JSON: $e');
        // 降级处理：如果不是 JSON，检查是否包含 error
        return !response.contains('error');
      }
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

    try {
      await _iap.restorePurchases();
      
      // 设置超时保护：如果10秒内没有收到状态回调，重置加载状态
      Future.delayed(const Duration(seconds: 10), () {
        if (_isLoading) {
          debugPrint('⚠️ Restore timeout, resetting loading state');
          _isLoading = false;
          // 如果10秒后还在 loading，可能没有可恢复的购买
          _errorMessage = '没有找到可恢复的购买记录';
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
