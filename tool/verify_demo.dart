// 本地验证脚本（非 flutter test，用 dart 直接跑）
// 用途：在交付前真实验证「演示数据载入」与「同步包导出/导入合并」逻辑
// 运行：dart run tool/verify_demo.dart
import 'dart:io';

import 'package:hermes_cards/services/database_service.dart';
import 'package:hermes_cards/services/demo_data_service.dart';
import 'package:hermes_cards/services/sync_service.dart';

Future<void> main() async {
  // 用临时目录当作运行目录，避免污染真实数据
  final tmp = Directory.systemTemp.createTempSync('hermes_verify_');
  Directory.current = tmp.path;
  stdout.writeln('工作目录: ${tmp.path}');

  final db = DatabaseService.instance;
  final demo = DemoDataService();
  final sync = SyncService();

  // ===== 1. 演示数据 =====
  stdout.writeln('\n--- 1. 载入演示数据 ---');
  final n = await demo.loadDemoData();
  stdout.writeln('载入卡片数: $n');
  final decks = await db.getAllDecksRaw();
  final cards = await db.getAllCards();
  final logs = await db.getReviewLogs();
  stdout.writeln('牌组数: ${decks.length}');
  for (final d in decks) {
    stdout.writeln('  ${d.emoji} ${d.name} (${d.id})');
  }
  stdout.writeln('卡片数: ${cards.length}');
  stdout.writeln('复习日志数: ${logs.length}');

  final now = DateTime.now();
  final dueNow = cards.where((c) =>
      c.due != null && !c.due!.isAfter(now) && c.enabled && !c.suspended);
  stdout.writeln('今日到期: ${dueNow.length} 张');
  stdout.writeln('新卡: ${cards.where((c) => c.state == 'new').length} 张');
  stdout.writeln('开口卡: ${cards.where((c) => c.type.name == 'speaking').length} 张');
  stdout.writeln('翻转卡: ${cards.where((c) => c.flipped).length} 张');
  final withCtx = cards.where((c) => (c.context ?? '').isNotEmpty).length;
  stdout.writeln('带语境: $withCtx 张');

  // ===== 2. 导出同步包 =====
  stdout.writeln('\n--- 2. 导出同步包 ---');
  final path = await sync.exportPackage();
  stdout.writeln('导出路径: $path');
  final content = await File(path).readAsString();
  stdout.writeln('包大小: ${content.length} 字符');
  final parsed = sync.parsePackage(content);
  stdout.writeln('格式校验: ${parsed['format']} v${parsed['version']}');
  stdout.writeln('包内统计: ${parsed['counts']}');

  // ===== 4. 合并语义：本地更新 vs 包内更新 =====
  stdout.writeln('\n--- 4. 合并语义验证 ---');
  Directory.current = tmp.path;
  // 4a. 本地把一张卡改得更新 -> 导入旧包应「保留本地」
  final target = cards.first;
  target.back = '【本地改过的新答案】';
  target.updatedAt = DateTime.now().add(const Duration(hours: 1));
  await db.saveCard(target);
  stdout.writeln('本地已改新: ${target.id} -> ${target.back}');

  var diff = await sync.previewPackage(parsed);
  stdout.writeln('预览: ${diff.summary()}');
  stdout.writeln('  cardsKeptLocal=${diff.cardsKeptLocal} (应为 1)');

  var applied = await sync.importPackage(parsed);
  stdout.writeln('执行: ${applied.summary()}');
  final after = (await db.getAllCards()).firstWhere((c) => c.id == target.id);
  stdout.writeln('合并后该卡答案: ${after.back}  ${after.back.contains('本地') ? '✅ 本地版本保留' : '❌ 被覆盖了'}');

  // 4b. 包内更新 -> 导入应「覆盖本地」
  final t2 = cards[1];
  final stale = DateTime.now().subtract(const Duration(days: 5));
  t2.back = '【本地旧答案】';
  t2.updatedAt = stale;
  await db.saveCard(t2);
  stdout.writeln('\n本地设为旧: ${t2.id} -> ${t2.back}');
  diff = await sync.previewPackage(parsed);
  stdout.writeln('预览: ${diff.summary()}');
  stdout.writeln('  cardsUpdated=${diff.cardsUpdated} (应为 1)');
  applied = await sync.importPackage(parsed);
  stdout.writeln('执行: ${applied.summary()}');
  final after2 = (await db.getAllCards()).firstWhere((c) => c.id == t2.id);
  stdout.writeln('合并后该卡答案: ${after2.back}  ${after2.back.contains('本地') ? '❌ 仍是旧的' : '✅ 已被包内更新覆盖'}');

  // ===== 5. 清除演示数据 =====
  stdout.writeln('\n--- 5. 清除演示数据 ---');
  await demo.clearDemoData();
  final left = await db.getAllDecksRaw();
  final leftCards = await db.getAllCards();
  stdout.writeln('剩余牌组: ${left.length} (应为 0)');
  stdout.writeln('剩余卡片: ${leftCards.length} (应为 0)');

  stdout.writeln('\n=== 验证结束 ===');
  for (final d in [tmp]) {
    try {
      d.deleteSync(recursive: true);
    } catch (_) {
      stdout.writeln('（临时目录可自行清理：${d.path}）');
    }
  }
}
