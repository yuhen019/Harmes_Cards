import 'dart:math';
import '../models/card_item.dart';
import '../models/deck.dart';
import 'database_service.dart';

/// 演示数据服务
///
/// 空库状态下用户看不到任何东西，无法判断产品好坏。
/// 这里预置三个有代表性的卡包，覆盖三种典型场景：
///   1. 语言输出训练（中→英，符合 L4 默认：母语提问、外语回答）
///   2. 术语记忆（带语境，短答案）
///   3. 开口卡（录音自评，v1.2 P0 差异化能力）
///
/// 卡片带真实分布的 FSRS 状态（新卡 / 学习中 / 复习中），
/// 并回填过去 14 天的复习日志，让首页、统计热力图、诊断指标都有数据可看。
class DemoDataService {
  static const String deckPrefix = 'demo_';
  final DatabaseService _db = DatabaseService.instance;

  /// 是否为演示牌组（按 id 前缀判断，便于一键清除）
  static bool isDemoDeck(String deckId) => deckId.startsWith(deckPrefix);

  /// 当前是否已有演示数据
  Future<bool> hasDemoData() async {
    final decks = await _db.getAllDecksRaw();
    return decks.any((d) => isDemoDeck(d.id));
  }

  /// 载入演示数据（已存在则先清再载，保证状态一致）
  Future<int> loadDemoData() async {
    await clearDemoData();

    final now = DateTime.now();
    final rnd = Random(20261025); // 固定种子：每次结果一致，便于复现

    // ===== 牌组 =====
    final ielts = Deck(
      id: '${deckPrefix}ielts',
      name: '雅思核心词 · 中→英',
      emoji: '🌏',
      colorValue: 0xFF7FB8E6,
      description: '母语提问、外语回答：训练主动输出，而不是再认',
      tag: '语言输出',
      createdAt: now.subtract(const Duration(days: 14)),
    );
    final anatomy = Deck(
      id: '${deckPrefix}anatomy',
      name: '解剖学 · 术语',
      emoji: '🦴',
      colorValue: 0xFFF0997B,
      description: '一卡一义，答案控制在 9 词内',
      tag: '医学',
      createdAt: now.subtract(const Duration(days: 9)),
    );
    final spanish = Deck(
      id: '${deckPrefix}spanish',
      name: '西语开口卡',
      emoji: '💬',
      colorValue: 0xFFB8A9E8,
      description: '说出来才算会：录音后自己对比再评分',
      tag: '开口输出',
      createdAt: now.subtract(const Duration(days: 5)),
    );
    await _db.saveDeck(ielts);
    await _db.saveDeck(anatomy);
    await _db.saveDeck(spanish);

    final cards = <CardItem>[];
    final logs = <Map<String, dynamic>>[];

    // ===== 雅思：8 张（3 新 / 2 学习中 / 3 复习中）=====
    final ieltsData = [
      ['放弃、抛弃（正式用语）', 'abandon',
        'They had to ___ the car in the snow and walk home.'],
      ['明显的、显而易见的', 'evident',
        'It was ___ that she had been crying.'],
      ['可持续的', 'sustainable',
        '___ development meets present needs without compromising the future.'],
      ['加剧、使恶化', 'exacerbate',
        'The recession has ___ the unemployment problem.'],
      ['微不足道的、可忽略的', 'negligible',
        'The difference between the two samples is ___.'],
      ['强制性的、义务的', 'mandatory',
        'Wearing a helmet is ___ for all riders.'],
      ['推测、猜测', 'speculate',
        'Analysts ___ that prices will rise next quarter.'],
      ['矛盾、不一致', 'contradiction',
        "Her story is in ___ with the witness's account."],
    ];
    for (var i = 0; i < ieltsData.length; i++) {
      final row = ieltsData[i];
      final c = CardItem(
        id: '${deckPrefix}ielts_c$i',
        deckId: ielts.id,
        front: row[0],
        back: row[1],
        context: row[2],
        source: '雅思核心词表 · List 3',
        tag: '写作高频',
        createdAt: now.subtract(Duration(days: 14 - i)),
      );
      if (i < 3) {
        // 全新卡，未学
        _asNew(c);
      } else if (i < 5) {
        // 学习中：今天还要再来一遍
        _asLearning(c, now, rnd, logs);
      } else {
        // 已进入复习队列：前两张今天到期，后一张三天后
        _asReview(
            c, i == 7 ? now.add(const Duration(days: 3)) : now, rnd, logs);
      }
      cards.add(c);
    }

    // ===== 解剖学：6 张（4 新 / 2 复习中）=====
    final anatomyData = [
      ['人体面积最大的器官', '皮肤',
        '成人体表面积约 1.5–2 平方米，是最大的器官。'],
      ['把血液从心脏送出的血管', '动脉',
        '肺动脉是唯一运送静脉血的动脉。'],
      ['前臂位于小指侧的骨', '尺骨',
        '尺骨与桡骨共同构成前臂骨架。'],
      ['分泌胰岛素的细胞', '胰岛β细胞',
        'β细胞受损会导致 1 型糖尿病。'],
      ['连接肌肉与骨骼的结构', '肌腱',
        '跟腱是人体最粗大的肌腱。'],
      ['Wernicke 语言理解区所在的脑叶', '颞叶',
        '该区损伤会导致感觉性失语。'],
    ];
    for (var i = 0; i < anatomyData.length; i++) {
      final row = anatomyData[i];
      final c = CardItem(
        id: '${deckPrefix}anatomy_c$i',
        deckId: anatomy.id,
        front: row[0],
        back: row[1],
        context: row[2],
        source: '系统解剖学 · 第 4 章',
        tag: '期末重点',
        createdAt: now.subtract(Duration(days: 9 - (i ~/ 2))),
      );
      if (i < 4) {
        _asNew(c);
      } else {
        _asReview(c, i == 4 ? now : now.add(const Duration(days: 2)), rnd, logs);
      }
      cards.add(c);
    }

    // ===== 西语开口卡：4 张，全部新卡，展示 flipped 与 speaking 类型 =====
    final spanishData = [
      ['我想预订一张两人桌', 'Quisiera reservar una mesa para dos.',
        '餐厅 · 预订'],
      ['这个多少钱？', '¿Cuánto cuesta esto?', '购物 · 询价'],
      ['洗手间在哪里？', '¿Dónde está el baño?', '出行 · 问路'],
      ['我没听懂，能再说一遍吗？', 'No entiendo bien, ¿puede repetirlo?',
        '通用 · 救场'],
    ];
    for (var i = 0; i < spanishData.length; i++) {
      final row = spanishData[i];
      final c = CardItem(
        id: '${deckPrefix}spanish_c$i',
        deckId: spanish.id,
        front: row[0],
        back: row[1],
        context: row[2],
        source: '西语生存句 · 第 1 课',
        tag: '口语',
        type: CardType.speaking,
        createdAt: now.subtract(Duration(days: 5 - i)),
      );
      _asNew(c);
      // 第 3 张演示「方向翻转」：看到西语，回忆中文
      if (i == 2) c.flipped = true;
      cards.add(c);
    }

    // L5 分批释放：所有演示卡默认启用（量小，无需分批）
    await _db.saveCards(cards);
    await _db.insertReviewLogs(logs);

    return cards.length;
  }

  /// 清除所有演示数据（牌组 + 卡片 + 相关日志）
  Future<void> clearDemoData() async {
    final decks = await _db.getAllDecksRaw();
    final demoDecks = decks.where((d) => isDemoDeck(d.id)).toList();
    if (demoDecks.isEmpty) return;

    final allCards = await _db.getAllCards();
    final ids = allCards
        .where((c) => demoDecks.any((d) => d.id == c.deckId))
        .map((c) => c.id)
        .toList();
    await _db.deleteReviewLogsByCardIds(ids);
    await _db.deleteCardsByIds(ids);
    for (final d in demoDecks) {
      await _db.deleteDeck(d.id);
    }
  }

  // ===== 状态构造器 =====

  void _asNew(CardItem c) {
    c.state = 'new';
    c.stability = 0;
    c.difficulty = 5;
    c.retrievability = 1.0;
    c.reps = 0;
    c.lapses = 0;
    c.due = null;
    c.enabled = true;
  }

  /// 学习中：当天短间隔过了一遍，现在再次到期
  void _asLearning(CardItem c, DateTime now, Random rnd,
      List<Map<String, dynamic>> logs) {
    c.state = 'learning';
    c.stability = 0.4 + rnd.nextDouble() * 0.3;
    c.difficulty = 5.0 + rnd.nextDouble() * 1.5;
    c.retrievability = 0.85;
    c.reps = 1;
    c.due = now;
    c.enabled = true;
    _pushLogs(c, 1, now, rnd, logs);
  }

  /// 复习中：已跨过学习步进，进入正式间隔
  void _asReview(
      CardItem c, DateTime due, Random rnd, List<Map<String, dynamic>> logs) {
    c.state = 'review';
    c.stability = 4.0 + rnd.nextDouble() * 14;
    c.difficulty = 4.5 + rnd.nextDouble() * 2;
    c.retrievability = 0.9;
    c.reps = 3 + rnd.nextInt(4);
    c.lapses = rnd.nextInt(2);
    c.due = due;
    c.enabled = true;
    _pushLogs(c, c.reps, DateTime.now(), rnd, logs);
  }

  /// 回填复习日志：分布在过去 14 天内，让热力图与诊断指标有数据
  void _pushLogs(CardItem c, int count, DateTime now, Random rnd,
      List<Map<String, dynamic>> logs) {
    for (var i = 0; i < count; i++) {
      final back = rnd.nextInt(13) + 1; // 1–13 天前
      final at = now.subtract(Duration(
        days: back,
        hours: rnd.nextInt(8),
        minutes: rnd.nextInt(60),
      ));
      logs.add({
        'id': 'demo_${c.id}_$i',
        'cardId': c.id,
        // 多数答对，少量 Again——贴近真实分布
        'grade': rnd.nextDouble() < 0.82 ? (1 + rnd.nextInt(3)) : 0,
        'durationMs': 4000 + rnd.nextInt(9000),
        'reviewedAt': at.toIso8601String(),
      });
    }
  }
}
