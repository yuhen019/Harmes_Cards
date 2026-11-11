import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';
import 'stats_screen.dart';
import 'import_screen.dart';
import 'settings_screen.dart';

/// 主框架：底部导航 + 页面切换
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  final _pages = const [
    HomeScreen(),
    StatsScreen(),
    ImportScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final err = context.watch<AppState>().initError;
    return Scaffold(
      // 数据层出错时明确提示，避免界面一直转圈却看不出原因
      body: err != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('⚠️', style: TextStyle(fontSize: 36)),
                    const SizedBox(height: 12),
                    const Text('数据没能打开',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    SelectableText(err,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12, height: 1.5)),
                  ],
                ),
              ),
            )
          : _pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        backgroundColor: AppTheme.paper,
        indicatorColor: AppTheme.mintLight,
        height: 70,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.school_outlined),
            selectedIcon: Icon(Icons.school, color: AppTheme.mintDark),
            label: '学习',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart, color: AppTheme.mintDark),
            label: '统计',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_box_outlined),
            selectedIcon: Icon(Icons.add_box, color: AppTheme.mintDark),
            label: '导入',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person, color: AppTheme.mintDark),
            label: '我的',
          ),
        ],
      ),
    );
  }
}
