import '../models/card_item.dart';

/// 文档导入服务 —— 纯本地规则拆卡（M1 阶段）
///
/// 根据文本结构（标题、列表、定义、问答模式）自动拆分出原子卡片。
/// 后续 M2 阶段将接入联网大模型（可插拔），本服务保留统一接口。
class DocumentParser {
  /// 从文本生成卡片列表
  ///
  /// 优先识别「快捷格式」：用 `!` 分隔正反面，用 `;`（或换行）分隔卡片。
  /// 例：`放弃、抛弃!abandon;可持续的!sustainable`
  /// 识别不到时回退到结构化解析（Markdown 标题 / 列表 / 「术语：定义」）。
  List<CardItem> generateCards(
    String text, {
    required String deckId,
    String density = '均衡', // 精简 / 均衡 / 详细
  }) {
    final quick = parseQuickFormat(text, deckId: deckId);
    if (quick.isNotEmpty) return quick;

    final lines = text
        .split(RegExp(r'\r?\n'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final cards = <CardItem>[];
    String? lastHeading;

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];

      // 标题作为卡片主题
      if (_isHeading(line)) {
        lastHeading = line.replaceAll(RegExp(r'^#+\s*'), '');
        continue;
      }

      // 定义/问答模式："术语：定义" 或 "术语 - 定义"
      final defMatch =
          RegExp(r'^(.{1,40})[:：]\s*(.+)$').firstMatch(line);
      if (defMatch != null && defMatch.group(1)!.length <= 30) {
        final term = defMatch.group(1)!.trim();
        final def = defMatch.group(2)!.trim();
        if (term.length > 1 && def.length > 1) {
          cards.add(CardItem(
            id: _genId(),
            deckId: deckId,
            front: _questionify(term, lastHeading),
            back: def,
            tag: lastHeading,
          ));
          continue;
        }
      }

      // 列表项（- 或 数字.）
      final listMatch = RegExp(r'^[-•*]\s+(.+)$').firstMatch(line);
      if (listMatch != null && lastHeading != null) {
        cards.add(CardItem(
          id: _genId(),
          deckId: deckId,
          front: '关于「$lastHeading」，请解释：${listMatch.group(1)}',
          back: listMatch.group(1)!,
          tag: lastHeading,
        ));
        continue;
      }
    }

    // 按密度控制卡片数量
    if (density == '精简' && cards.length > 10) {
      cards.shuffle();
      cards.removeRange(10, cards.length);
    }

    return cards;
  }

  /// 快捷格式解析
  ///
  /// 规则：
  ///   - 正反面用 `!` 或 `！` 分隔，左边是正面（你看到的），右边是反面（你要回忆的）
  ///   - 卡片之间用 `;` 或 `；` 分隔，换行也可以
  ///   - 超出两段的，第二段之后的部分并入反面（避免误切）
  ///
  /// 返回空列表表示「不是这个格式」，交给结构化解析兜底。
  static List<CardItem> parseQuickFormat(String text,
      {required String deckId}) {
    final cards = <CardItem>[];
    final segments = text.split(RegExp(r'[;；\n]'));
    for (final seg in segments) {
      final t = seg.trim();
      if (t.isEmpty) continue;
      final idx = t.indexOf(RegExp(r'[!！]'));
      if (idx <= 0) continue; // 没有分隔符，或正面为空
      final front = t.substring(0, idx).trim();
      final back = t.substring(idx + 1).trim();
      if (front.isEmpty || back.isEmpty) continue;
      cards.add(CardItem(
        id: _genId(),
        deckId: deckId,
        front: front,
        back: back,
      ));
    }
    return cards;
  }

  bool _isHeading(String line) {
    return RegExp(r'^#{1,4}\s').hasMatch(line);
  }

  String _questionify(String term, String? heading) {
    if (heading != null && heading.isNotEmpty && !term.contains(heading)) {
      return '$heading —— $term 是什么？';
    }
    return '$term 是什么？';
  }

  static int _seq = 0;

  static String _genId() {
    // 用序号而非随机数：避免同一微秒内批量生成时 id 撞车
    return '${DateTime.now().microsecondsSinceEpoch}_${_seq++}';
  }
}
