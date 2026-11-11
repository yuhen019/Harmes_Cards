import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../models/card_item.dart';
import '../models/deck.dart';
import 'database_service.dart';

/// 导入前的差异摘要：先给用户看清楚「会发生什么」，再让他决定
class SyncDiff {
  final int decksAdded;
  final int decksUpdated;
  final int cardsAdded;
  final int cardsUpdated;
  final int cardsKeptLocal; // 本地更新，保留本地版本
  final int logsAdded;

  const SyncDiff({
    this.decksAdded = 0,
    this.decksUpdated = 0,
    this.cardsAdded = 0,
    this.cardsUpdated = 0,
    this.cardsKeptLocal = 0,
    this.logsAdded = 0,
  });

  int get totalChanges =>
      decksAdded + decksUpdated + cardsAdded + cardsUpdated + logsAdded;

  bool get isEmpty => totalChanges == 0;

  /// 一句话摘要，用于确认弹窗
  String summary() {
    final parts = <String>[];
    if (cardsAdded > 0) parts.add('新增 $cardsAdded 张卡片');
    if (cardsUpdated > 0) parts.add('更新 $cardsUpdated 张（对方更新）');
    if (cardsKeptLocal > 0) parts.add('保留 $cardsKeptLocal 张（本地更新）');
    if (decksAdded > 0) parts.add('新增 $decksAdded 个卡包');
    if (decksUpdated > 0) parts.add('更新 $decksUpdated 个卡包');
    if (logsAdded > 0) parts.add('补 $logsAdded 条复习记录');
    if (parts.isEmpty) return '两边数据一致，无需合并';
    return parts.join(' · ');
  }
}

/// 手动同步服务（需求文档 3.8）
///
/// 设计要点：手动同步最容易出的事故是「两边数据互相覆盖」。
/// 因此合并的最小单位是**卡片**，不是整个库：
///   - 同一张卡（id 相同）→ 取 updatedAt 较新的一方，绝不整库覆盖
///   - 各自新增的卡 → 全部保留
///   - 复习日志 → 按 id 求并集，不会丢任何一端的复习历史
///   - 设置 → 只补充本地缺失的键，不覆盖用户在本地的偏好
class SyncService {
  static const String formatTag = 'hermes-cards-sync';
  static const int formatVersion = 1;

  final DatabaseService _db = DatabaseService.instance;

  /// 导出学习数据包，返回写入的文件路径
  ///
  /// 所见即所得：库里有什么就导出什么（含示例卡包）。
  /// 示例卡包 id 固定，导入到另一台设备时按 id 合并，不会产生重复。
  Future<String> exportPackage() async {
    final decks = await _db.getAllDecksRaw();
    final allCards = await _db.getAllCards();
    final logs = await _db.getReviewLogs();
    final settings = await _db.getAllSettings();

    final payload = {
      'format': formatTag,
      'version': formatVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'app': 'Hermes Cards',
      'counts': {
        'decks': decks.length,
        'cards': allCards.length,
        'logs': logs.length,
      },
      'decks': decks.map((d) => d.toMap()).toList(),
      'cards': allCards.map((c) => c.toMap()).toList(),
      'reviewLogs': logs,
      'settings': settings,
    };

    final dir = await _syncDir();
    final stamp = _timestamp();
    final file = File(p.join(dir, 'hermes_cards_同步包_$stamp.json'));
    await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(payload),
        encoding: utf8);
    return file.path;
  }

  /// 兼容格式导出：CSV（front,back,context,tag,source）
  Future<String> exportCsv(String deckId) async {
    final cards = deckId.isEmpty
        ? await _db.getAllCards()
        : await _db.getCardsByDeck(deckId);
    final buf = StringBuffer();
    buf.writeln('front,back,context,tag,source');
    for (final c in cards) {
      buf.writeln([
        _csv(c.questionFace),
        _csv(c.answerFace),
        _csv(c.context ?? ''),
        _csv(c.tag ?? ''),
        _csv(c.source ?? ''),
      ].join(','));
    }
    final dir = await _syncDir();
    final stamp = _timestamp();
    final file = File(p.join(dir, 'hermes_cards_导出_$stamp.csv'));
    await file.writeAsString(buf.toString(), encoding: utf8);
    return file.path;
  }

  /// 解析数据包（校验格式，失败抛出可读的中文错误）
  Map<String, dynamic> parsePackage(String content) {
    Map<String, dynamic> data;
    try {
      data = jsonDecode(content) as Map<String, dynamic>;
    } catch (_) {
      throw const FormatException('这不是有效的 JSON 文件');
    }
    if (data['format'] != formatTag) {
      throw const FormatException('这不是 Hermes Cards 的学习数据包');
    }
    final v = data['version'];
    if (v is int && v > formatVersion) {
      throw FormatException('数据包版本 v$v 高于当前应用，请先升级应用');
    }
    return data;
  }

  /// 只算差异，不写入——导入前先给用户看清楚
  Future<SyncDiff> previewPackage(Map<String, dynamic> data) =>
      _merge(data, apply: false);

  /// 执行合并写入
  Future<SyncDiff> importPackage(Map<String, dynamic> data) =>
      _merge(data, apply: true);

  Future<SyncDiff> _merge(Map<String, dynamic> data,
      {required bool apply}) async {
    final localDecks = await _db.getAllDecksRaw();
    final localCards = await _db.getAllCards();
    final localLogs = await _db.getReviewLogs();

    final localDeckById = {for (final d in localDecks) d.id: d};
    final localCardById = {for (final c in localCards) c.id: c};
    final localLogIds = localLogs.map((l) => l['id'] as String).toSet();

    int decksAdded = 0, decksUpdated = 0;
    int cardsAdded = 0, cardsUpdated = 0, cardsKeptLocal = 0, logsAdded = 0;

    final decksToSave = <Deck>[];
    final cardsToSave = <CardItem>[];
    final logsToSave = <Map<String, dynamic>>[];

    // ===== 牌组：同 id 取 updatedAt 较新者 =====
    for (final m in (data['decks'] as List? ?? [])) {
      final incoming = Deck.fromMap(Map<String, dynamic>.from(m as Map));
      final mine = localDeckById[incoming.id];
      if (mine == null) {
        decksAdded++;
        decksToSave.add(incoming);
      } else if (incoming.updatedAt.isAfter(mine.updatedAt)) {
        decksUpdated++;
        decksToSave.add(incoming);
      }
    }

    // ===== 卡片：最小合并单位 =====
    for (final m in (data['cards'] as List? ?? [])) {
      final incoming =
          CardItem.fromMap(Map<String, dynamic>.from(m as Map));
      final mine = localCardById[incoming.id];
      if (mine == null) {
        // 本地没有 → 直接收下（对方新增的卡）
        cardsAdded++;
        cardsToSave.add(incoming);
      } else if (incoming.updatedAt.isAfter(mine.updatedAt)) {
        // 对方更新 → 覆盖本地
        cardsUpdated++;
        cardsToSave.add(incoming);
      } else {
        // 本地更新 → 保留本地，绝不倒退
        cardsKeptLocal++;
      }
    }

    // ===== 复习日志：id 求并集，两端历史都保留 =====
    for (final l in (data['reviewLogs'] as List? ?? [])) {
      final map = Map<String, dynamic>.from(l as Map);
      final id = map['id'] as String?;
      if (id == null || localLogIds.contains(id)) continue;
      logsAdded++;
      logsToSave.add(map);
    }

    if (apply) {
      for (final d in decksToSave) {
        await _db.saveDeck(d);
      }
      if (cardsToSave.isNotEmpty) await _db.saveCards(cardsToSave);
      if (logsToSave.isNotEmpty) await _db.insertReviewLogs(logsToSave);

      // 设置：只补本地缺失的键，不覆盖用户在本机的偏好
      final incomingSettings =
          Map<String, String>.from(data['settings'] as Map? ?? {});
      final mine = await _db.getAllSettings();
      for (final entry in incomingSettings.entries) {
        if (!mine.containsKey(entry.key)) {
          await _db.setSetting(entry.key, entry.value);
        }
      }
    }

    return SyncDiff(
      decksAdded: decksAdded,
      decksUpdated: decksUpdated,
      cardsAdded: cardsAdded,
      cardsUpdated: cardsUpdated,
      cardsKeptLocal: cardsKeptLocal,
      logsAdded: logsAdded,
    );
  }

  /// 同步包存放目录：桌面端在运行目录下建 sync/，移动端在文档目录
  Future<String> _syncDir() async {
    final base = await _db.dataDirectory();
    final dir = Directory(p.join(base, 'sync'));
    if (!dir.existsSync()) await dir.create(recursive: true);
    return dir.path;
  }

  String _timestamp() {
    final n = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${n.year}${two(n.month)}${two(n.day)}_${two(n.hour)}${two(n.minute)}';
  }

  String _csv(String s) {
    final escaped = s.replaceAll('"', '""');
    return '"$escaped"';
  }
}
