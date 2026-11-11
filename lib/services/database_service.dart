import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../models/deck.dart';
import '../models/card_item.dart';

/// 移动端文档目录提供者（由 main.dart 注入 path_provider，避免此处引入 Flutter 依赖）
typedef PathProvider = Future<String> Function();

/// 本地数据服务 —— 基于 JSON 单文件存储
///
/// 为什么不用 sqlite：
/// 桌面端 sqflite 依赖 sqlite3 原生库，而 `sqlite3_flutter_libs` 已废弃失效
/// （0.6.0 起是空包），Windows 构建产物里不会有 sqlite3.dll，数据库根本打不开。
///
/// 而本应用的负载特征是：全量卡片常驻内存（`_cardsByDeck` 本就是全量缓存），
/// 数据规模是个人卡片库（千级），同步包格式本来就是 JSON。
/// 改用 JSON 单文件后：
///   - 桌面端与移动端行为完全一致，无任何原生依赖
///   - 导出/导入同步包与底层存储同构，合并逻辑天然一致
///   - 可用纯 Dart 脚本验证，不必打包 exe 才能发现问题
class DatabaseService {
  static final DatabaseService instance = DatabaseService._();
  DatabaseService._();

  /// 由 main.dart 注入（path_provider），未注入时回退当前目录
  static PathProvider? mobilePathProvider;

  static const String _fileName = 'hermes_cards.json';
  static const String _formatTag = 'hermes-cards-db';
  static const int _formatVersion = 2;

  bool _loaded = false;
  /// 最近一次见到的文件时间戳（用于判断文件是否被别的实例改过）
  String? _lastSeenUpdatedAt;
  final Map<String, Map<String, dynamic>> _decks = {};
  final Map<String, Map<String, dynamic>> _cards = {};
  final List<Map<String, dynamic>> _logs = [];
  final Map<String, String> _settings = {};

  // ===== 载入 / 落盘 =====

  Future<void> _ensure() async {
    if (_loaded) return;
    final file = File(await _jsonPath());
    if (file.existsSync()) {
      try {
        final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        for (final m in (data['decks'] as List? ?? [])) {
          final d = Map<String, dynamic>.from(m as Map);
          _decks[d['id'] as String] = d;
        }
        for (final m in (data['cards'] as List? ?? [])) {
          final c = Map<String, dynamic>.from(m as Map);
          _cards[c['id'] as String] = c;
        }
        _logs.addAll((data['reviewLogs'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map)));
        _settings.addAll(Map<String, String>.from(data['settings'] as Map? ?? {}));
        _lastSeenUpdatedAt = data['updatedAt'] as String?;
      } catch (_) {
        // 文件损坏时不阻塞启动，按空库处理
      }
    }
    _loaded = true;
  }

  Future<void> _flush() async {
    final file = File(await _jsonPath());
    final dir = file.parent;
    if (!dir.existsSync()) await dir.create(recursive: true);

    // 多开窗口保护：整份 JSON 是盲覆盖写的，若另一个实例刚写过，
    // 直接覆盖会把它的数据抹掉。写之前先看文件有没有被别人改过，改过就先合并。
    if (file.existsSync()) {
      try {
        final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        final diskUpdated = data['updatedAt'] as String?;
        if (diskUpdated != null && diskUpdated != _lastSeenUpdatedAt) {
          _mergeFrom(data);
        }
      } catch (_) {
        // 读不出来就按原样写，不因为别人的坏文件阻塞自己的保存
      }
    }

    final now = DateTime.now().toIso8601String();
    final out = {
      'format': _formatTag,
      'version': _formatVersion,
      'updatedAt': now,
      'decks': _decks.values.toList(),
      'cards': _cards.values.toList(),
      'reviewLogs': _logs,
      'settings': _settings,
    };
    await file.writeAsString(const JsonEncoder().convert(out), flush: true);
    _lastSeenUpdatedAt = now;
  }

  /// 把磁盘上的内容合进内存（按 id 合并，同 id 取 updatedAt 较新的一份）
  void _mergeFrom(Map<String, dynamic> data) {
    void mergeById(Map<String, Map<String, dynamic>> mine, String key) {
      for (final raw in (data[key] as List? ?? [])) {
        final m = Map<String, dynamic>.from(raw as Map);
        final id = m['id'] as String?;
        if (id == null) continue;
        final cur = mine[id];
        mine[id] = cur == null ? m : _newerOf(cur, m);
      }
    }

    mergeById(_decks, 'decks');
    mergeById(_cards, 'cards');

    final haveLog = _logs.map((l) => l['id'] as String?).toSet();
    for (final raw in (data['reviewLogs'] as List? ?? [])) {
      final m = Map<String, dynamic>.from(raw as Map);
      if (m['id'] != null && !haveLog.contains(m['id'])) _logs.add(m);
    }
    for (final e in (data['settings'] as Map? ?? {}).entries) {
      _settings.putIfAbsent(e.key.toString(), () => e.value.toString());
    }
  }

  static Map<String, dynamic> _newerOf(
      Map<String, dynamic> a, Map<String, dynamic> b) {
    final ta = DateTime.tryParse(a['updatedAt']?.toString() ?? '');
    final tb = DateTime.tryParse(b['updatedAt']?.toString() ?? '');
    if (ta == null && tb == null) return a; // 都没有时间戳 → 保留自己这份
    if (ta == null) return b;
    if (tb == null) return a;
    return tb.isAfter(ta) ? b : a;
  }

  Future<String> _jsonPath() async => p.join(await dataDirectory(), _fileName);

  /// 测试用：强制指定数据目录，避免测试把文件写进 SDK 目录
  static String? pathOverride;

  /// 应用数据目录：桌面端为 exe 所在目录，移动端为文档目录
  Future<String> dataDirectory() async {
    if (pathOverride != null) return pathOverride!;
    if (Platform.isAndroid || Platform.isIOS) {
      final f = mobilePathProvider;
      if (f != null) return f();
      return Directory.current.path;
    }
    // 桌面端：用 exe 所在目录，避免双击启动时工作目录不确定
    final exe = Platform.resolvedExecutable.toLowerCase();
    if (exe.endsWith('dart.exe') || exe.endsWith('/dart') || exe.endsWith('\\dart')) {
      // dart 脚本/测试运行时的回退
      return Directory.current.path;
    }
    return File(Platform.resolvedExecutable).parent.path;
  }

  // ===== 设置持久化（key-value）=====
  Future<void> setSetting(String key, String value) async {
    await _ensure();
    _settings[key] = value;
    await _flush();
  }

  Future<String?> getSetting(String key) async {
    await _ensure();
    return _settings[key];
  }

  Future<Map<String, String>> getAllSettings() async {
    await _ensure();
    return Map<String, String>.from(_settings);
  }

  // ===== 学习日志（诊断指标）=====
  Future<void> logReview({
    required String cardId,
    required int grade,
    required int durationMs,
  }) async {
    await _ensure();
    _logs.add({
      'id': '${DateTime.now().microsecondsSinceEpoch}_$cardId',
      'cardId': cardId,
      'grade': grade,
      'durationMs': durationMs,
      'reviewedAt': DateTime.now().toIso8601String(),
    });
    await _flush();
  }

  Future<List<Map<String, dynamic>>> getReviewLogs() async {
    await _ensure();
    return List<Map<String, dynamic>>.from(_logs);
  }

  /// 批量写入复习日志（同步合并用，按 id 去重）
  Future<int> insertReviewLogs(List<Map<String, dynamic>> logs) async {
    if (logs.isEmpty) return 0;
    await _ensure();
    final have = _logs.map((l) => l['id'] as String).toSet();
    var n = 0;
    for (final l in logs) {
      final id = l['id'] as String?;
      if (id == null || have.contains(id)) continue;
      _logs.add(l);
      have.add(id);
      n++;
    }
    if (n > 0) await _flush();
    return n;
  }

  /// 平均单卡耗时（毫秒），用于首页预计用时估算
  Future<double> getAverageCardDurationMs() async {
    await _ensure();
    if (_logs.isEmpty) return 8000; // 默认 8 秒/张
    final recent = _logs.reversed.take(100).toList();
    final sum = recent.fold<int>(0, (a, b) => a + ((b['durationMs'] as int?) ?? 8000));
    return sum / recent.length;
  }

  // ===== 牌组操作 =====
  Future<List<Deck>> getAllDecks() async {
    await _ensure();
    return _decks.values
        .where((m) => (m['archived'] ?? 0) != 1)
        .map(Deck.fromMap)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// 含归档在内的全部牌组（导出用，避免丢数据）
  Future<List<Deck>> getAllDecksRaw() async {
    await _ensure();
    return _decks.values.map(Deck.fromMap).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> saveDeck(Deck deck) async {
    await _ensure();
    _decks[deck.id] = deck.toMap();
    await _flush();
  }

  Future<void> deleteDeck(String id) async {
    await _ensure();
    _decks.remove(id);
    _cards.removeWhere((_, c) => c['deckId'] == id);
    await _flush();
  }

  /// 删除某个牌组下的所有卡片（保留牌组）
  Future<void> deleteCardsByDeck(String deckId) async {
    await _ensure();
    _cards.removeWhere((_, c) => c['deckId'] == deckId);
    await _flush();
  }

  /// 删除指定卡片 id 集合（如清除演示数据）
  Future<void> deleteCardsByIds(List<String> ids) async {
    if (ids.isEmpty) return;
    await _ensure();
    final set = ids.toSet();
    _cards.removeWhere((id, _) => set.contains(id));
    await _flush();
  }

  /// 删除指定卡片相关的复习日志
  Future<void> deleteReviewLogsByCardIds(List<String> cardIds) async {
    if (cardIds.isEmpty) return;
    await _ensure();
    final set = cardIds.toSet();
    _logs.removeWhere((l) => set.contains(l['cardId']));
    await _flush();
  }

  // ===== 卡片操作 =====
  Future<List<CardItem>> getCardsByDeck(String deckId) async {
    await _ensure();
    final list = _cards.values
        .where((m) => m['deckId'] == deckId)
        .map(CardItem.fromMap)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return list;
  }

  Future<List<CardItem>> getAllCards() async {
    await _ensure();
    return _cards.values.map(CardItem.fromMap).toList();
  }

  Future<void> saveCard(CardItem card) async {
    await _ensure();
    _cards[card.id] = card.toMap();
    await _flush();
  }

  Future<void> saveCards(List<CardItem> cards) async {
    if (cards.isEmpty) return;
    await _ensure();
    for (final c in cards) {
      _cards[c.id] = c.toMap();
    }
    await _flush();
  }

  Future<void> deleteCard(String id) async {
    await _ensure();
    _cards.remove(id);
    await _flush();
  }

  /// 统计信息
  Future<Map<String, int>> getStats(String deckId) async {
    await _ensure();
    final cards = deckId.isEmpty
        ? _cards.values.map(CardItem.fromMap).toList()
        : await getCardsByDeck(deckId);
    int due = 0, newCount = 0;
    final now = DateTime.now();
    for (final c in cards) {
      if (c.state == 'new') {
        newCount++;
      } else if (c.due != null && !now.isBefore(c.due!)) {
        due++;
      }
    }
    return {'due': due, 'new': newCount, 'total': cards.length};
  }
}
