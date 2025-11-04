import 'package:flutter/cupertino.dart';
import '../config/colors.dart';
import '../widgets/common/custom_tab_bar.dart';
import '../services/mistake_service.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';
import 'analysis_screen.dart';
import 'practice_screen.dart';
import 'profile_screen.dart';

/// 主屏幕 - 带底部导航栏
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  int _homeRefreshTrigger = 0; // 用于触发主页刷新
  
  // 页面列表 - 会在 build 中动态更新 HomeScreen
  late List<Widget> _pages;
  
  // 积累统计数据
  int _daysSinceLastReview = 0;
  int _accumulatedMistakes = 0;
  
  final _mistakeService = MistakeService();

  @override
  void initState() {
    super.initState();
    
    // 初始化页面列表
    _pages = [
      HomeScreen(
        key: const PageStorageKey('home_page'),
        refreshTrigger: _homeRefreshTrigger,
      ),
      const AnalysisScreen(key: PageStorageKey('analysis_page')),
      const SizedBox(), // 占位符，中间是拍照按钮
      const PracticeScreen(key: PageStorageKey('practice_page')),
      const ProfileScreen(key: PageStorageKey('profile_page')),
    ];
    
    // 加载积累统计数据
    _loadAccumulationStats();
  }
  
  /// 加载积累统计数据
  Future<void> _loadAccumulationStats() async {
    try {
      final authService = AuthService();
      final userId = authService.userId;
      
      if (userId == null) {
        // 未登录，使用默认值
        return;
      }
      
      // 初始化服务
      _mistakeService.initialize(authService.client);
      
      // 获取积累统计
      final stats = await _mistakeService.getAccumulationStats(userId);
      
      if (mounted) {
        setState(() {
          _daysSinceLastReview = stats['daysSinceLastReview'] ?? 0;
          _accumulatedMistakes = stats['accumulatedMistakes'] ?? 0;
        });
      }
    } catch (e) {
      print('加载积累统计失败: $e');
      // 静默失败，使用默认值
    }
  }

  // 判断是否应该显示分析小红点
  bool _shouldShowAnalysisBadge() {
    // 只有满足以下条件之一时才显示小红点：
    // 1. 距离上次复盘超过2天
    // 2. 积累的错题超过30道
    return _daysSinceLastReview > 2 || _accumulatedMistakes > 30;
  }

  final List<CustomTabItem> _tabItems = [
    const CustomTabItem(
      icon: CupertinoIcons.home,
      activeIcon: CupertinoIcons.house_fill,
      label: '主页',
    ),
    const CustomTabItem(
      icon: CupertinoIcons.search,
      activeIcon: CupertinoIcons.zoom_in,
      label: '分析',
    ),
    const CustomTabItem(
      icon: CupertinoIcons.camera,
      activeIcon: CupertinoIcons.camera_fill,
      label: '拍照', // 这个不会显示，因为是特殊按钮
    ),
    const CustomTabItem(
      icon: CupertinoIcons.book,
      activeIcon: CupertinoIcons.book_fill,
      label: '练习',
    ),
    const CustomTabItem(
      icon: CupertinoIcons.person,
      activeIcon: CupertinoIcons.person_fill,
      label: '我的',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: Column(
          children: [
            // 主要内容区域
            Expanded(
              child: IndexedStack(
                index: _currentIndex,
                children: _pages,
              ),
            ),
            // 自定义底部导航栏
            CustomTabBar(
              currentIndex: _currentIndex,
              onTap: (index) {
                // 跳过中间的拍照按钮索引
                if (index != 2) {
                  setState(() {
                    _currentIndex = index;
                    
                    // 如果切换到主页，触发刷新
                    if (index == 0) {
                      _homeRefreshTrigger++;
                      _pages[0] = HomeScreen(
                        key: const PageStorageKey('home_page'),
                        refreshTrigger: _homeRefreshTrigger,
                      );
                      print('🏠 切换到主页，刷新触发器: $_homeRefreshTrigger');
                    }
                    
                    // 如果切换到分析页面，刷新积累统计
                    if (index == 1) {
                      _loadAccumulationStats();
                    }
                  });
                }
              },
              items: _tabItems,
              showAnalysisBadge: _shouldShowAnalysisBadge(), // 显示分析小红点
            ),
          ],
        ),
      ),
    );
  }
}
