import 'package:flutter/foundation.dart';
import '../models/deck.dart';
import '../models/card_item.dart';
import '../services/database_service.dart';
import '../services/demo_data_service.dart';
import '../services/fsrs_scheduler.dart';
import '../services/sync_service.dart';

/// 学习模式
enum StudyMode {
  normal, // 常规：复习 + 新卡
  reviewOnly, // C8 快速复习：只清复习，不加新卡
}

/// v1.2 护栏默认值（来自主学习 Agent 实证评审）
class GuardDefaults {
  static const int dailyNewLimit = 8; // C1 不是 20
  static const int dailyReviewLimit = 9999; // C1 还债不许设上限
  static const int backlogPauseAt = 150; // C1 积压暂停阈值
  static const int backlogResumeAt = 60; // C1 积压恢复阈值
  static const int leechThreshold = 4; // C3 Again 累计 4 次
  static const int breakDays = 3; // C2 断卡天数
  static const int dailyMinutesBudget = 10; // C7 每日时间预算
  static const int aiFirstBatch = 20; // L5 首批启用量
  // C6 学习步进
  static const int newStep1Minutes = 1;
  static const int newStep2Minutes = 10;
  static const int graduatingIntervalDays = 3;
  static const int easyIntervalDays = 4;
}

/// 应用全局状态
class AppState extends ChangeNotifier {
  final DatabaseService _db = DatabaseService.instance;
  final FsrsScheduler scheduler = FsrsScheduler();
  final DemoDataService _demo = DemoDataService();
  final SyncService _sync = SyncService();

  List<Deck> decks = [];
  Map<String, List<CardItem>> _cardsByDeck = {};
  bool loading = true;

  /// 是否已载入演示数据（决定设置页显示「清除」还是「载入」）
  bool hasDemo = false;

  /// 初始化失败原因（数据库打不开等原因）。非 null 时界面显示错误而非一直转圈
  String? initError;

  // ===== 设置（带 v1.2 默认值）=====
  double desiredRetention = 0.90;
  int dailyNewLimit = GuardDefaults.dailyNewLimit;
  int dailyReviewLimit = GuardDefaults.dailyReviewLimit;
  int dailyMinutesBudget = GuardDefaults.dailyMinutesBudget;
  int leechThreshold = GuardDefaults.leechThreshold;
  int newStep1Minutes = GuardDefaults.newStep1Minutes;
  int newStep2Minutes = GuardDefaults.newStep2Minutes;
  int graduatingIntervalDays = GuardDefaults.graduatingIntervalDays;
  int easyIntervalDays = GuardDefaults.easyIntervalDays;

  DateTime? _lastStudyDate;
  double _avgCardMs = 8000;

  /// C1 积压暂停状态（带迟滞：>150 暂停，<60 才恢复），跨重启保留
  bool _backlogPaused = false;

  // ===== 生命周期 =====
  Future<void> init() async {
    loading = true;
    initError = null;
    notifyListeners();
    try {
      await _loadSettings();
      await _loadDecks();
      hasDemo = await _demo.hasDemoData();
      await releaseDailyBatches();
    } catch (e) {
      // 数据层出错时明确告知，而不是让界面一直转圈
      initError = '数据初始化失败：$e';
    }
    loading = false;
    notifyListeners();
  }

  Future<void> _loadSettings() async {
    final s = await _db.getAllSettings();
    desiredRetention = double.tryParse(s['desiredRetention'] ?? '') ?? 0.90;
    dailyNewLimit =
        int.tryParse(s['dailyNewLimit'] ?? '') ?? GuardDefaults.dailyNewLimit;
    dailyReviewLimit = int.tryParse(s['dailyReviewLimit'] ?? '') ??
        GuardDefaults.dailyReviewLimit;
    dailyMinutesBudget = int.tryParse(s['dailyMinutesBudget'] ?? '') ??
        GuardDefaults.dailyMinutesBudget;
    leechThreshold =
        int.tryParse(s['leechThreshold'] ?? '') ?? GuardDefaults.leechThreshold;
    newStep1Minutes = int.tryParse(s['newStep1Minutes'] ?? '') ??
        GuardDefaults.newStep1Minutes;
    newStep2Minutes = int.tryParse(s['newStep2Minutes'] ?? '') ??
        GuardDefaults.newStep2Minutes;
    graduatingIntervalDays =
        int.tryParse(s['graduatingIntervalDays'] ?? '') ??
            GuardDefaults.graduatingIntervalDays;
    easyIntervalDays = int.tryParse(s['easyIntervalDays'] ?? '') ??
        GuardDefaults.easyIntervalDays;
    final last = s['lastStudyDate'];
    _lastStudyDate = last != null ? DateTime.tryParse(last) : null;
    _backlogPaused = s['backlogPaused'] == '1';
    scheduler.desiredRetention = desiredRetention;
    // C6 学习步进必须同步给调度器，否则设置改了不生效
    scheduler.learningSteps = [
      newStep1Minutes.toDouble(),
      newStep2Minutes.toDouble(),
    ];
    scheduler.graduatingIntervalDays = graduatingIntervalDays;
    scheduler.easyIntervalDays = easyIntervalDays;
    _avgCardMs = await _db.getAverageCardDurationMs();
  }

  Future<void> _saveSetting(String key, String value) =>
      _db.setSetting(key, value);

  Future<void> _loadDecks() async {
    decks = await _db.getAllDecks();
    _cardsByDeck = {};
    for (final d in decks) {
      _cardsByDeck[d.id] = await _db.getCardsByDeck(d.id);
    }
    _refreshBacklogPause();
  }

  /// C1 迟滞：>150 进入暂停，降到 <60 才恢复，避免在阈值附近反复横跳
  void _refreshBacklogPause() {
    final backlog = backlogCount;
    if (_backlogPaused) {
      if (backlog < GuardDefaults.backlogResumeAt) {
        _backlogPaused = false;
        _saveSetting('backlogPaused', '0');
      }
    } else if (backlog > GuardDefaults.backlogPauseAt) {
      _backlogPaused = true;
      _saveSetting('backlogPaused', '1');
    }
  }

  /// 数据文件所在目录（设置页展示，便于排查数据到底存在哪）
  Future<String> dataDirectory() => _db.dataDirectory();

  List<CardItem> cardsOf(String deckId) => _cardsByDeck[deckId] ?? [];

  List<CardItem> get allCards =>
      _cardsByDeck.values.expand((e) => e).toList();

  // ===== 护栏：积压 / 断卡 / Leech =====

  /// 当前待复习总数（未暂停、已启用）
  int get backlogCount => _dueAll().length;

  /// C1 是否因积压而暂停新卡（迟滞状态由 _refreshBacklogPause 维护）
  bool get newPausedByBacklog => _backlogPaused;

  /// C2 是否处于断卡恢复状态（距上次学习 ≥3 天）
  bool get isReturningFromBreak {
    if (_lastStudyDate == null) return false;
    final days = DateTime.now().difference(_lastStudyDate!).inDays;
    return days >= GuardDefaults.breakDays;
  }

  /// 断卡天数
  int get breakDays {
    if (_lastStudyDate == null) return 0;
    return DateTime.now().difference(_lastStudyDate!).inDays;
  }

  /// 今天是否应该加新卡（综合 C1 积压 + C2 断卡）
  bool get shouldAddNewCards =>
      !newPausedByBacklog && !isReturningFromBreak;

  /// 首页降级提示文案（无提示则返回 null）
  String? get guardMessage {
    if (newPausedByBacklog) {
      return '今天不加新卡，先清完 $backlogCount 张';
    }
    if (isReturningFromBreak) {
      return '回来就好，今天先还债';
    }
    return null;
  }

  List<CardItem> _dueAll() {
    final now = DateTime.now();
    return allCards
        .where((c) =>
            !c.suspended && c.enabled && scheduler.isDue(c, now))
        .toList();
  }

  /// 今日到期待复习的卡片（受复习上限约束）
  List<CardItem> dueCards() {
    final list = _dueAll();
    if (list.length <= dailyReviewLimit) return list;
    return list.sublist(0, dailyReviewLimit);
  }

  /// 今日可学新卡（受 C1/C2/L5 约束）
  List<CardItem> newCards() {
    if (!shouldAddNewCards) return [];
    final list = allCards
        .where((c) => !c.suspended && c.enabled && c.state == 'new')
        .toList();
    if (list.length <= dailyNewLimit) return list;
    return list.sublist(0, dailyNewLimit);
  }

  /// C8 快速复习模式的卡（只清复习，不含新卡）
  List<CardItem> reviewOnlyCards() => dueCards();

  /// 常规学习的卡 = 复习 + 新卡
  List<CardItem> studyCards() => [...dueCards(), ...newCards()];

  /// 按模式取卡
  List<CardItem> cardsForMode(StudyMode mode) =>
      mode == StudyMode.reviewOnly ? reviewOnlyCards() : studyCards();

  /// C7 首页预计用时（分钟）
  int estimateMinutes(StudyMode mode) {
    final n = cardsForMode(mode).length;
    return (n * _avgCardMs / 60000).ceil();
  }

  /// C7 是否超过时间预算
  bool isOverBudget(StudyMode mode) =>
      estimateMinutes(mode) > dailyMinutesBudget;

  /// L5 分批释放：牌组的"已启用 / 总数"
  Map<String, int> deckEnabledStats(String deckId) {
    final list = cardsOf(deckId);
    return {
      'enabled': list.where((c) => c.enabled).length,
      'total': list.length,
    };
  }

  /// 今日自动释放的数量（供界面提示）
  int releasedToday = 0;

  /// L5 每日自动释放：每个自然日最多补一批，且只在积压消化到恢复线以下时补。
  /// 没有这个，导入 42 张就永远只有前 20 张能被学到。
  Future<void> releaseDailyBatches() async {
    final today = _todayKey();
    final s = await _db.getAllSettings();
    if (s['lastReleaseDate'] == today) return;
    // C1 积压保护：债还没还完就不补新卡
    if (backlogCount > GuardDefaults.backlogResumeAt) return;

    var released = 0;
    for (final d in decks) {
      final pending = cardsOf(d.id).where((c) => !c.enabled).toList();
      if (pending.isEmpty) continue;
      // 只有当已启用卡里「还没学过的」不足一批时，才补下一批
      final newLeft =
          cardsOf(d.id).where((c) => c.enabled && c.state == 'new').length;
      if (newLeft >= dailyNewLimit) continue;
      for (final c in pending.take(dailyNewLimit)) {
        c.enabled = true;
        await _db.saveCard(c);
        released++;
      }
    }
    if (released > 0) {
      await _loadDecks();
      releasedToday = released;
    }
    await _saveSetting('lastReleaseDate', today);
  }

  static String _todayKey() {
    final n = DateTime.now();
    final m = n.month.toString().padLeft(2, '0');
    final d = n.day.toString().padLeft(2, '0');
    return '${n.year}-$m-$d';
  }

  /// L5 手动释放一批（数额 = 每日新卡上限）
  Future<void> releaseBatch(String deckId) async {
    final pending = cardsOf(deckId).where((c) => !c.enabled).toList();
    final take = pending.take(dailyNewLimit);
    for (final c in take) {
      c.enabled = true;
      await _db.saveCard(c);
    }
    await _loadDecks();
    notifyListeners();
  }

  /// C3 Leech 列表（待处理）
  List<CardItem> get leechCards =>
      allCards.where((c) => c.suspended && c.againCount >= leechThreshold).toList();

  // ===== 数据操作 =====
  Future<void> createDeck(Deck deck) async {
    await _db.saveDeck(deck);
    await _loadDecks();
    notifyListeners();
  }

  /// 3.1 重命名卡包
  Future<void> renameDeck(Deck deck, String name) async {
    deck.name = name.trim().isEmpty ? deck.name : name.trim();
    deck.updatedAt = DateTime.now();
    await _db.saveDeck(deck);
    await _loadDecks();
    notifyListeners();
  }

  /// 3.1 归档 / 取消归档（归档后不在首页出现，数据保留且仍参与导出）
  Future<void> setDeckArchived(Deck deck, bool archived) async {
    deck.archived = archived;
    deck.updatedAt = DateTime.now();
    await _db.saveDeck(deck);
    await _loadDecks();
    notifyListeners();
  }

  /// 3.1 删除卡包（连同卡片）
  Future<void> removeDeck(String id) async {
    await _db.deleteDeck(id);
    await _loadDecks();
    notifyListeners();
  }

  Future<void> addCard(CardItem card) async {
    await _db.saveCard(card);
    await _loadDecks();
    notifyListeners();
  }

  /// L5 批量导入：超出首批数量的卡片存为"待启用"
  Future<void> addCards(List<CardItem> cards,
      {int firstBatch = GuardDefaults.aiFirstBatch}) async {
    for (var i = 0; i < cards.length; i++) {
      cards[i].enabled = i < firstBatch;
    }
    await _db.saveCards(cards);
    await _loadDecks();
    notifyListeners();
  }

  /// 复习一张卡：更新 FSRS + Leech 计数 + 学习日志
  Future<void> reviewCard(
    CardItem card,
    ReviewGrade grade, {
    int durationMs = 8000,
  }) async {
    // C3 Leech：Again 累计
    if (grade == ReviewGrade.again) {
      card.againCount += 1;
      if (card.againCount >= leechThreshold) {
        card.suspended = true; // 自动暂停，等待改写或删除
      }
    } else {
      // 答对则重置连续 Again 计数
      card.againCount = 0;
    }

    final updated = scheduler.review(card, grade);
    await _db.saveCard(updated);
    await _db.logReview(
        cardId: card.id, grade: grade.index, durationMs: durationMs);

    // C2 记录最后学习日期
    _lastStudyDate = DateTime.now();
    await _saveSetting('lastStudyDate', _lastStudyDate!.toIso8601String());

    await _loadDecks();
    notifyListeners();
  }

  /// C3 Leech 改写后重新启用
  Future<void> reviveCard(CardItem card) async {
    card.suspended = false;
    card.againCount = 0;
    await _db.saveCard(card);
    await _loadDecks();
    notifyListeners();
  }

  Future<void> deleteCard(String id) async {
    await _db.deleteCard(id);
    await _loadDecks();
    notifyListeners();
  }

  void setDesiredRetention(double v) {
    desiredRetention = v;
    scheduler.desiredRetention = v;
    _saveSetting('desiredRetention', v.toString());
    notifyListeners();
  }

  // ===== 设置项（C6 学习步进可查可调）=====
  void setDailyNewLimit(int v) {
    dailyNewLimit = v;
    _saveSetting('dailyNewLimit', v.toString());
    notifyListeners();
  }

  void setDailyReviewLimit(int v) {
    dailyReviewLimit = v;
    _saveSetting('dailyReviewLimit', v.toString());
    notifyListeners();
  }

  void setDailyMinutesBudget(int v) {
    dailyMinutesBudget = v;
    _saveSetting('dailyMinutesBudget', v.toString());
    notifyListeners();
  }

  void setLearningSteps(
      {int? step1, int? step2, int? graduating, int? easy}) {
    if (step1 != null) {
      newStep1Minutes = step1;
      _saveSetting('newStep1Minutes', step1.toString());
    }
    if (step2 != null) {
      newStep2Minutes = step2;
      _saveSetting('newStep2Minutes', step2.toString());
    }
    if (graduating != null) {
      graduatingIntervalDays = graduating;
      _saveSetting('graduatingIntervalDays', graduating.toString());
    }
    if (easy != null) {
      easyIntervalDays = easy;
      _saveSetting('easyIntervalDays', easy.toString());
    }
    // 立即对调度器生效（PRD 3.7.2：改后立即对新卡生效）
    scheduler.learningSteps = [
      newStep1Minutes.toDouble(),
      newStep2Minutes.toDouble(),
    ];
    scheduler.graduatingIntervalDays = graduatingIntervalDays;
    scheduler.easyIntervalDays = easyIntervalDays;
    notifyListeners();
  }

  // ===== 演示数据 =====

  /// 载入演示卡包（返回卡片数）
  Future<int> loadDemoData() async {
    final n = await _demo.loadDemoData();
    await _loadDecks();
    hasDemo = true;
    notifyListeners();
    return n;
  }

  /// 清除演示数据
  Future<void> clearDemoData() async {
    await _demo.clearDemoData();
    await _loadDecks();
    hasDemo = false;
    notifyListeners();
  }

  // ===== 手动同步（需求 3.8）=====

  /// 导出学习数据包，返回文件路径
  Future<String> exportPackage() => _sync.exportPackage();

  /// 导出 CSV 兼容格式，返回文件路径
  Future<String> exportCsv(String deckId) => _sync.exportCsv(deckId);

  /// 解析数据包内容（格式错误会抛出中文异常）
  Map<String, dynamic> parsePackage(String content) =>
      _sync.parsePackage(content);

  /// 预演合并结果（不写入）
  Future<SyncDiff> previewPackage(Map<String, dynamic> data) =>
      _sync.previewPackage(data);

  /// 执行合并导入
  Future<SyncDiff> importPackage(Map<String, dynamic> data) async {
    final diff = await _sync.importPackage(data);
    await _loadSettings();
    await _loadDecks();
    hasDemo = await _demo.hasDemoData();
    notifyListeners();
    return diff;
  }

  // ===== 统计诊断指标（3.5 新增）=====

  /// 成熟卡正确率：稳定期卡片（reps>=3 且间隔较长）的答对比例
  /// 低于 80% 说明新卡加太快或卡片质量差
  Future<double> matureAccuracy() async {
    final logs = await _db.getReviewLogs();
    if (logs.isEmpty) return 1.0;
    final mature = allCards
        .where((c) => c.reps >= 3 && c.state == 'review')
        .map((c) => c.id)
        .toSet();
    final relevant = logs.where((l) => mature.contains(l['cardId'])).toList();
    if (relevant.isEmpty) return 1.0;
    final ok = relevant.where((l) => (l['grade'] as int) > 0).length;
    return ok / relevant.length;
  }

  /// 估算平均单卡耗时（毫秒）
  double get avgCardMs => _avgCardMs;
}
