// Hermes Cards 综合测试套件 · 护栏部分（AppState 依赖 flutter/foundation，须走 flutter test）
// 运行：flutter test test/guardrails_test.dart -r expanded
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_cards/models/card_item.dart';
import 'package:hermes_cards/models/deck.dart';
import 'package:hermes_cards/services/app_state.dart';
import 'package:hermes_cards/services/database_service.dart';

CardItem mkCard(String id,
    {String state = 'new',
    bool enabled = true,
    DateTime? due,
    double stability = 0,
    int reps = 0,
    String deckId = 'd1'}) {
  return CardItem(
    id: id, deckId: deckId, front: 'F$id', back: 'B$id',
    state: state, enabled: enabled, due: due,
    stability: stability, reps: reps,
  );
}

void main() {
  final fails = <String>[];
  void check(String name, bool cond, [String detail = '']) {
    if (cond) {
      // ignore: avoid_print
      print('  PASS  $name');
    } else {
      fails.add('$name ${detail.isNotEmpty ? "-- $detail" : ""}');
      // ignore: avoid_print
      print('  FAIL  $name ${detail.isNotEmpty ? "-- $detail" : ""}');
    }
  }

  test('B 组：护栏与学习队列', () async {
    final tmp = Directory.systemTemp.createTempSync('hermes_guard_');
    Directory.current = tmp.path;
    final now = DateTime.now();

    // 清掉上次测试遗留的数据文件（flutter_tester 下数据目录在 exe 旁，会跨次残留）
    final dataDir = await DatabaseService.instance.dataDirectory();
    final dataFile = File('$dataDir${Platform.pathSeparator}hermes_cards.json');
    if (dataFile.existsSync()) dataFile.deleteSync();

    final state = AppState();
    await state.init();
    expect(state.initError, isNull);
    await state.createDeck(Deck(id: 'd1', name: '测试包', emoji: 'T', tag: '测试'));

    // B1 新卡不应计入待复习，学习队列不应重复
    await state.addCards([mkCard('n1'), mkCard('n2'), mkCard('n3')]);
    final due1 = state.dueCards();
    final study1 = state.studyCards();
    check('B1a 新卡不计入待复习', due1.where((c) => c.state == 'new').isEmpty,
        '待复习 ${due1.length} 张里含 ${due1.where((c) => c.state == 'new').length} 张新卡');
    check('B1b 学习队列无重复',
        study1.length == study1.map((c) => c.id).toSet().length,
        '队列 ${study1.length} 张，去重后 ${study1.map((c) => c.id).toSet().length} 张');

    // B2 C1 积压 >150 → 暂停新卡
    final backlog = List.generate(
        151,
        (i) => mkCard('bk$i',
            state: 'review', stability: 5, due: now.subtract(const Duration(days: 1))));
    await state.addCards(backlog, firstBatch: 9999);
    check('B2a 积压>150 → 暂停新卡', state.newPausedByBacklog);
    check('B2b 积压时新卡队列为空', state.newCards().isEmpty);
    check('B2c 积压提示文案', (state.guardMessage ?? '').contains('不加新卡'));
    check('B3 C8 快速复习不含新卡',
        state.reviewOnlyCards().every((c) => c.state != 'new'));

    // B9 C1 迟滞：降到 100（>60）仍暂停；降到 50（<60）才恢复
    await DatabaseService.instance.deleteCardsByIds(
        backlog.take(51).map((c) => c.id).toList());
    await state.init();
    check('B9a 积压降到100(>60) → 仍暂停（迟滞）', state.newPausedByBacklog,
        'backlog=${state.backlogCount}');
    await DatabaseService.instance.deleteCardsByIds(
        backlog.skip(51).take(50).map((c) => c.id).toList());
    await state.init();
    check('B9b 积压降到50(<60) → 恢复新卡', !state.newPausedByBacklog,
        'backlog=${state.backlogCount}');

    await DatabaseService.instance
        .deleteCardsByIds(backlog.map((c) => c.id).toList());
    await state.init();

    // B4 C2 断卡 4 天 → 只清复习
    await DatabaseService.instance.setSetting('lastStudyDate',
        now.subtract(const Duration(days: 4)).toIso8601String());
    await state.init();
    check('B4a 断卡4天 → 识别为回归', state.isReturningFromBreak);
    check('B4b 断卡回归 → 新卡为 0', state.newCards().isEmpty);
    check('B4c 断卡文案温和', (state.guardMessage ?? '').contains('回来就好'));
    await DatabaseService.instance
        .setSetting('lastStudyDate', now.toIso8601String());
    await state.init();

    // B5 C3 Leech：连续 4 次 Again → 暂停 + 落盘后仍暂停 + 待处理列表
    await state.addCards([mkCard('l1')]);
    final leechCard = state.allCards.firstWhere((c) => c.id == 'l1');
    for (var i = 0; i < 4; i++) {
      await state.reviewCard(leechCard, ReviewGrade.again);
    }
    check('B5a 连错4次 → againCount 累计', leechCard.againCount >= 4,
        '实际=${leechCard.againCount}');
    final l1db = (await DatabaseService.instance.getCardsByDeck('d1'))
        .firstWhere((c) => c.id == 'l1');
    check('B5b 落盘后仍暂停且计数在', l1db.suspended && l1db.againCount >= 4,
        'suspended=${l1db.suspended} againCount=${l1db.againCount}（落盘丢失则 C3 重启后失效）');
    check('B5c Leech 出现在待处理列表', state.leechCards.any((c) => c.id == 'l1'));
    await DatabaseService.instance.deleteCardsByIds(['l1']);
    await state.init();

    // B6 L5 分批释放（用全新牌组 d2，排除前面用例的干扰）
    await state.createDeck(Deck(id: 'd2', name: '释放测试', emoji: 'T', tag: '测试'));
    await state.addCards(List.generate(42, (i) => mkCard('p$i', deckId: 'd2')));
    var stats = state.deckEnabledStats('d2');
    check('B6a 导入42张 → 启用20', stats['enabled'] == 20, '实际=${stats['enabled']}');
    await state.releaseBatch('d2');
    stats = state.deckEnabledStats('d2');
    check('B6b 手动释放一批 → 启用28', stats['enabled'] == 28, '实际=${stats['enabled']}');
    check('B7 待启用卡不进学习队列', !state.studyCards().any((c) => !c.enabled));

    // B8 C6 步进设置应生效
    state.setLearningSteps(step1: 30);
    final c30 = state.scheduler.review(mkCard('s1'), ReviewGrade.again, now: now);
    final mins30 = c30.due!.difference(now).inMinutes;
    check('B8 C6 步进改后生效(30m)', mins30 >= 25,
        '实际 $mins30 分钟（设置未同步给调度器）');

    // B10 C6 毕业/简单间隔生效：新卡 Good→7天，Easy→10天
    state.setLearningSteps(graduating: 7, easy: 10);
    final dGood = state.scheduler.review(mkCard('s2'), ReviewGrade.good, now: now);
    final dEasy = state.scheduler.review(mkCard('s3'), ReviewGrade.easy, now: now);
    check('B10a 新卡 Good 按毕业间隔 7 天', dGood.due!.difference(now).inDays == 7,
        '实际=${dGood.due!.difference(now).inDays} 天');
    check('B10b 新卡 Easy 按简单间隔 10 天', dEasy.due!.difference(now).inDays == 10,
        '实际=${dEasy.due!.difference(now).inDays} 天');

    expect(fails, isEmpty, reason: '\n${fails.join('\n')}');
  });
}
