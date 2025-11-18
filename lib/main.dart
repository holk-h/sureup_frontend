import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'config/colors.dart';
import 'screens/main_screen.dart';
import 'screens/subscription_screen.dart';
import 'services/auth_service.dart';
import 'services/appwrite_service.dart';
import 'services/local_storage_service.dart';
import 'services/notification_service.dart';
import 'services/subscription_service.dart';
import 'providers/auth_provider.dart';

void main() async {
  // 确保Flutter binding初始化
  WidgetsFlutterBinding.ensureInitialized();
  
  // 🚀 预初始化本地存储服务（提升性能）
  await LocalStorageService().initialize();
  print('✅ 本地存储服务已预初始化');
  
  // 初始化通知服务
  await NotificationService().initialize();
  print('✅ 通知服务已初始化');
  
  // 初始化Appwrite
  final authService = AuthService();
  authService.initialize();
  
  runApp(const SureUpApp());
}

class SureUpApp extends StatelessWidget {
  const SureUpApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProxyProvider<AuthProvider, SubscriptionService>(
          create: (_) => SubscriptionService(
            AppwriteService(),
            getUserId: () => null, // 初始化时返回 null
          ),
          update: (context, authProvider, previousService) {
            final service = previousService ?? SubscriptionService(AppwriteService());
            // 设置 getUserId 回调，从 AuthProvider 获取用户 ID
            service.setGetUserId(() => authProvider.userProfile?.id);
            
            // 🚀 当用户登录或档案更新时，同步订阅信息
            if (authProvider.isLoggedIn && authProvider.userProfile != null) {
              // 异步同步订阅状态，不阻塞 UI
              Future.microtask(() async {
                try {
                  await service.loadSubscriptionStatus();
                  print('✅ 订阅信息已同步');
                } catch (e) {
                  print('⚠️ 同步订阅信息失败: $e');
                  // 静默失败，不影响用户体验
                }
              });
            }
            
            return service;
          },
        ),
      ],
      child: CupertinoApp(
        title: '稳了！',
        theme: const CupertinoThemeData(
          primaryColor: AppColors.primary,
          scaffoldBackgroundColor: AppColors.background,
          barBackgroundColor: AppColors.cardBackground,
          textTheme: CupertinoTextThemeData(
            primaryColor: AppColors.textPrimary,
            textStyle: TextStyle(
              fontFamily: '.SF Pro Text',
              color: AppColors.textSecondary,
            ),
          ),
        ),
        home: const AppInitializer(),
        routes: {'/subscription': (context) => const SubscriptionScreen()},
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

/// 应用初始化器 - 静默初始化后直接进入主页
class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  bool _hasTriggeredInitialRefresh = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        // 初始化完成后直接显示主页
        // 不再强制登录，让用户先浏览应用
        if (!authProvider.isInitialized) {
          return _buildSplashScreen();
        }
        
        // 在AuthProvider初始化完成后，触发一次数据刷新
        if (!_hasTriggeredInitialRefresh) {
          _hasTriggeredInitialRefresh = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _triggerInitialDataRefresh(authProvider);
          });
        }
        
        return const MainScreen();
      },
    );
  }
  
  /// 触发应用启动后的初始数据刷新
  void _triggerInitialDataRefresh(AuthProvider authProvider) {
    print('🚀 AuthProvider初始化完成，触发初始数据刷新...');
    
    // 如果用户已登录，刷新用户档案
    if (authProvider.isLoggedIn) {
      print('👤 用户已登录，刷新用户档案...');
      authProvider
          .refreshProfile()
          .then((_) {
        print('✅ 用户档案刷新完成');
          })
          .catchError((e) {
        print('❌ 用户档案刷新失败: $e');
      });
    } else {
      print('👤 用户未登录，跳过用户档案刷新');
    }
  }

  Widget _buildSplashScreen() {
    return Container(
      color: CupertinoColors.white,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo
              Image.asset(
                'assets/images/new_splash_logo.png',
              width: 150,
              height: 150,
              fit: BoxFit.contain,
            ),
            
            const SizedBox(height: 24),
            
            Text(
              '稳了!',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            
            const SizedBox(height: 48),
            
            const CupertinoActivityIndicator(),
          ],
        ),
      ),
    );
  }
}
