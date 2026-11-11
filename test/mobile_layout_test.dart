// 手机尺寸冒烟测试（Android 适配验收用）
//
// 目的：在 360×800dp（主流安卓手机竖屏）与 320×568dp（老机型）下渲染四个主页面，
// 一旦出现 RenderFlex overflow / 渲染异常，测试直接失败。
//
// 注意两个坑（踩过）：
// 1) 真实文件 I/O 必须放在 tester.runAsync 里，否则被 FakeAsync 卡住直到超时；
// 2) 不能用 pumpAndSettle —— 页面里有无值进度条之类的无限动画，会一直等下去。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:hermes_cards/screens/main_shell.dart';
import 'package:hermes_cards/services/app_state.dart';
import 'package:hermes_cards/services/database_service.dart';
import 'package:hermes_cards/theme/app_theme.dart';

Future<AppState> _boot() async {
  final tmp = Directory.systemTemp.createTempSync('hermes_ui_');
  DatabaseService.pathOverride = tmp.path;
  final state = AppState();
  await state.init();
  // 有真实数据才测得到「卡包网格 / 待复习角标 / 进度条」这些容易溢出的地方
  await state.loadDemoData();
  return state;
}

Future<AppState> _mount(WidgetTester tester, Size logicalSize) async {
  tester.view.physicalSize = logicalSize * 3.0;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  late AppState state;
  await tester.runAsync(() async {
    state = await _boot();
  });

  await tester.pumpWidget(
    ChangeNotifierProvider<AppState>.value(
      value: state,
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const MainShell(),
      ),
    ),
  );
  // 用固定次数的 pump 推进，不用 pumpAndSettle
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
  return state;
}

void main() {
  testWidgets('360x800 手机尺寸下四个主页面不溢出', (tester) async {
    await _mount(tester, const Size(360, 800));
    expect(tester.takeException(), isNull, reason: '学习首页渲染异常');

    // 依次切到其它三个 tab（用底部导航未选中图标定位，避免和页面内文字重名）
    final tabs = <String, IconData>{
      '统计': Icons.bar_chart_outlined,
      '导入': Icons.add_box_outlined,
      '我的': Icons.person_outline,
    };
    for (final e in tabs.entries) {
      await tester.tap(find.byIcon(e.value).last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(tester.takeException(), isNull, reason: '「${e.key}」页溢出或渲染异常');
    }

    // 回到学习页，确认切换来回也不炸
    await tester.tap(find.byIcon(Icons.school_outlined).last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(tester.takeException(), isNull, reason: '返回学习页异常');
  });

  testWidgets('320x568 极窄屏（老机型）仍不溢出', (tester) async {
    await _mount(tester, const Size(320, 568));
    expect(tester.takeException(), isNull, reason: '320dp 宽下首页溢出');
  });
}
