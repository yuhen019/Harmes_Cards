// 用法：dart run tool/check_csv.dart <csv路径>
// 用 App 自身的解析器（TemplateService.parseCsv）实跑检查一份 CSV 是否满足导入要求。
import 'dart:io';
import '../lib/models/card_item.dart';
import '../lib/services/template_service.dart';

bool hasCjk(String s) => s.runes.any((r) => r >= 0x4E00 && r <= 0x9FFF);

/// 与 import_screen 的 _chunkCount 保持一致：英文按空格分词，中文按 2.5 字≈1 词
int chunkCount(String text) {
  final t = text.trim();
  if (t.isEmpty) return 0;
  if (t.contains(' ')) return t.split(RegExp(r'\s+')).length;
  return (t.length / 2.5).ceil();
}

void main(List<String> args) {
  if (args.isEmpty) {
    stdout.writeln('用法: dart run tool/check_csv.dart <csv路径>');
    exit(1);
  }
  final file = File(args.first);
  if (!file.existsSync()) {
    stdout.writeln('文件不存在: ${args.first}');
    exit(1);
  }
  final content = file.readAsStringSync();

  // ---- 1. 表头检查 ----
  final firstLine = content.split('\n').first.trim();
  stdout.writeln('表头: $firstLine');
  final headerCols = firstLine.split(',').map((e) => e.trim()).toList();
  final required = ['front', 'back'];
  final missing = required.where((c) => !headerCols.contains(c)).toList();
  stdout.writeln(
      missing.isEmpty ? '✅ 必需列 front/back 齐全' : '❌ 缺少必需列: $missing');

  // ---- 2. 用 App 解析器实跑 ----
  final svc = TemplateService();
  final cards = svc.parseCsv(content, deckId: 'check');
  final dataLines =
      content.split('\n').where((l) => l.trim().isNotEmpty).length - 1;
  stdout.writeln('');
  stdout.writeln('数据行数: $dataLines    解析出卡片: ${cards.length}');
  if (cards.length != dataLines) {
    stdout.writeln(
        '⚠️ 有 ${dataLines - cards.length} 行被丢弃（front 或 back 为空）');
  } else {
    stdout.writeln('✅ 每一行都被解析成卡片');
  }

  // ---- 3. 卡片写作铁律检查 ----
  stdout.writeln('');
  final noContext = <CardItem>[];
  final tooLong = <CardItem>[];
  final wrongDir = <CardItem>[];
  final seen = <String, String>{};
  final dup = <String>[];

  for (final c in cards) {
    if (c.context == null || c.context!.trim().isEmpty) {
      noContext.add(c);
    }
    final n = chunkCount(c.back);
    if (n > 9) tooLong.add(c);
    // 语言材料：正面应为中文提示，反面应为英文（中文提问 → 外语回答）
    if (!hasCjk(c.front) && hasCjk(c.back)) wrongDir.add(c);
    final key = c.front.trim();
    if (seen.containsKey(key)) {
      dup.add(key);
    } else {
      seen[key] = c.back;
    }
  }

  stdout.writeln('铁律3 · 必须带语境');
  stdout.writeln(noContext.isEmpty
      ? '  ✅ 全部 ${cards.length} 张都有 context'
      : '  ❌ ${noContext.length} 张缺 context:');
  for (final c in noContext.take(5)) {
    stdout.writeln('     - ${c.front}');
  }

  stdout.writeln('铁律2 · 答案 ≤ 9 词');
  if (tooLong.isEmpty) {
    stdout.writeln('  ✅ 全部答案都在 9 词以内');
  } else {
    stdout.writeln('  ⚠️ ${tooLong.length} 张偏长（不阻断导入，但建议拆）:');
    for (final c in tooLong.take(8)) {
      stdout.writeln(
          '     - ${chunkCount(c.back)} 词 | ${c.front} → ${c.back}');
    }
  }

  stdout.writeln('铁律4 · 中文提问 → 外语回答');
  stdout.writeln(wrongDir.isEmpty
      ? '  ✅ 方向正确，没有「英文提问→中文回答」的反向卡'
      : '  ⚠️ ${wrongDir.length} 张方向疑似反了:');
  for (final c in wrongDir.take(5)) {
    stdout.writeln('     - ${c.front} → ${c.back}');
  }

  stdout.writeln('重复检查');
  stdout.writeln(dup.isEmpty ? '  ✅ 无重复正面' : '  ⚠️ 重复正面 ${dup.length} 条:');
  for (final d in dup.take(5)) {
    stdout.writeln('     - $d');
  }

  // ---- 4. 字段分布 ----
  stdout.writeln('');
  final typeCount = <CardType, int>{};
  for (final c in cards) {
    typeCount[c.type] = (typeCount[c.type] ?? 0) + 1;
  }
  stdout.writeln('卡片类型: ${typeCount.entries.map((e) => '${e.key.name}=${e.value}').join('  ')}');
  final flips = cards.where((c) => c.flipped).length;
  stdout.writeln('翻转卡: $flips 张');
  final noSource = cards.where((c) => c.source == null || c.source!.isEmpty).length;
  final noTag = cards.where((c) => c.tag == null || c.tag!.isEmpty).length;
  stdout.writeln('缺 source: $noSource    缺 tag: $noTag');

  final sources = <String, int>{};
  for (final c in cards) {
    final s = c.source ?? '(空)';
    sources[s] = (sources[s] ?? 0) + 1;
  }
  stdout.writeln('来源分布:');
  sources.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value))
    ..forEach((e) => stdout.writeln('   ${e.value} 张  ${e.key}'));

  // ---- 5. 导入后会发生什么 ----
  stdout.writeln('');
  const firstBatch = 20;
  stdout.writeln('导入行为：共 ${cards.length} 张，'
      '默认启用前 ${cards.length > firstBatch ? firstBatch : cards.length} 张，'
      '其余 ${cards.length > firstBatch ? cards.length - firstBatch : 0} 张存为「待启用」');
}
