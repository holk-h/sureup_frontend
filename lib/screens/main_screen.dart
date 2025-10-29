import 'package:flutter/cupertino.dart';
import '../config/colors.dart';
import '../widgets/common/custom_tab_bar.dart';
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
  Key _homeScreenKey = UniqueKey(); // 主页的唯一key，用于刷新
  
  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      HomeScreen(key: _homeScreenKey),
      const AnalysisScreen(),
      const SizedBox(), // 占位符，中间是拍照按钮
      const PracticeScreen(),
      const ProfileScreen(),
    ];
  }

  // 判断是否应该显示分析小红点
  bool _shouldShowAnalysisBadge() {
    // 模拟数据：距上次复盘的天数和积累的错题数
    // TODO: 实际使用时，应该从数据层获取真实数据
    const daysSinceLastReview = 3;
    const accumulatedMistakes = 15;
    
    // 只有满足以下条件之一时才显示小红点：
    // 1. 距离上次复盘超过2天
    // 2. 积累的错题超过30道
    return daysSinceLastReview > 2 || accumulatedMistakes > 30;
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
                    // 如果切换到主页，刷新主页内容
                    if (index == 0) {
                      _homeScreenKey = UniqueKey();
                      _pages[0] = HomeScreen(key: _homeScreenKey);
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
