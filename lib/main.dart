import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'config/colors.dart';
import 'screens/main_screen.dart';
import 'services/auth_service.dart';
import 'services/local_storage_service.dart';
import 'providers/auth_provider.dart';

void main() async {
  // 确保Flutter binding初始化
  WidgetsFlutterBinding.ensureInitialized();
  
  // 🚀 预初始化本地存储服务（提升性能）
  await LocalStorageService().initialize();
  print('✅ 本地存储服务已预初始化');
  
  // 初始化Appwrite
  final authService = AuthService();
  authService.initialize();
  
  runApp(const SureUpApp());
}

class SureUpApp extends StatelessWidget {
  const SureUpApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthProvider(),
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

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        // 初始化完成后直接显示主页
        // 不再强制登录，让用户先浏览应用
        if (!authProvider.isInitialized) {
          return _buildSplashScreen();
        }
        
        return MainScreen();
      },
    );
  }

  Widget _buildSplashScreen() {
    return Container(
      color: AppColors.background,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(20),
                boxShadow: AppColors.coloredShadow(
                  AppColors.primary,
                  opacity: 0.3,
                ),
              ),
              child: const Icon(
                CupertinoIcons.checkmark_shield_fill,
                color: CupertinoColors.white,
                size: 48,
              ),
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
