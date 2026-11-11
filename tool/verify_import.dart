// 验证导入模板与文本/CSV 解析（纯 Dart 运行）
// 运行：dart run tool/verify_import.dart
import 'dart:io';

import 'package:hermes_cards/services/document_parser.dart';
import 'package:hermes_cards/services/template_service.dart';

Future<void> main() async {
  final tmp = Directory.systemTemp.createTempSync('hermes_import_');
  Directory.current = tmp.path;
  stdout.writeln('工作目录: ${tmp.path}');

  final tpl = TemplateService();

  // ===== 1. CSV 模板 =====
  stdout.writeln('\n--- 1. CSV 模板 ---');
  final csvPath = await tpl.exportCsvTemplate();
  final csvContent = await File(csvPath).readAsString();
  stdout.writeln('路径: ${File(csvPath).uri.pathSegments.last}');
  stdout.writeln('首行表头: ${csvContent.split('\n').first}');

  // 用解析器读回模板自身（模板里的示例行应当能被解析成卡片）
  final fromTemplate = tpl.parseCsv(csvContent, deckId: 'd1');
  stdout.writeln('模板示例行解析出: ${fromTemplate.length} 张卡（应为 4）');
  for (final c in fromTemplate) {
    stdout.writeln(
        '  [${c.type.name}] ${c.front} → ${c.back} | 语境: ${(c.context ?? '').isEmpty ? '无' : '有'} | flipped=${c.flipped}');
  }

  // ===== 2. MD 规格文档 =====
  stdout.writeln('\n--- 2. MD 规格文档 ---');
  final mdPath = await tpl.exportMdTemplate();
  final md = await File(mdPath).readAsString();
  stdout.writeln('路径: ${File(mdPath).uri.pathSegments.last}');
  stdout.writeln('字数: ${md.length}');
  for (final key in ['front', 'back', 'context', '一卡一义', '9 个词', '选择题']) {
    stdout.writeln('  含「$key」: ${md.contains(key)}');
  }

  // ===== 3. 快捷文本格式：! 分隔正反面，; 分隔卡片 =====
  stdout.writeln('\n--- 3. 快捷文本格式 ---');
  void quick(String label, String text, int expect) {
    final cards = DocumentParser.parseQuickFormat(text, deckId: 'd1');
    final ok = cards.length == expect;
    stdout.writeln('$label: ${cards.length} 张 (期望 $expect) ${ok ? '✅' : '❌'}');
    for (final c in cards) {
      stdout.writeln('    ${c.front} → ${c.back}');
    }
  }

  quick('英文分号', '放弃、抛弃!abandon;可持续的!sustainable', 2);
  quick('中文分号', '人体最大的器官!皮肤；前臂内侧的骨!尺骨', 2);
  quick('换行分隔', '我想预订一张两人桌!Quisiera reservar una mesa.\n这个多少钱!¿Cuánto cuesta?', 2);
  quick('中英叹号混用', '洗手间在哪里！¿Dónde está el baño?', 1);
  quick('单个卡片（无分号）', '矛盾的!contradiction', 1);
  quick('空文本', '', 0);

  // 多个叹号：只按第一个切分，后面归入反面
  final multi = DocumentParser.parseQuickFormat('正面!反面里有!号!结尾', deckId: 'd1');
  stdout.writeln('多叹号: front="${multi.first.front}" back="${multi.first.back}"');

  // ===== 4. generateCards 回退到结构化解析 =====
  stdout.writeln('\n--- 4. 结构化回退（不含 ! 的 Markdown）---');
  final mdText = '# 认知心理学\n主动回忆：先自行提取答案，比反复阅读更能强化记忆痕迹。\n间隔重复：在即将遗忘的时刻复习。';
  final structured = DocumentParser().generateCards(mdText, deckId: 'd1');
  stdout.writeln('解析出 ${structured.length} 张（走「术语：定义」模式）');
  for (final c in structured) {
    stdout.writeln('    ${c.front} → ${c.back}');
  }

  // ===== 5. CSV 边界情况 =====
  stdout.writeln('\n--- 5. CSV 边界 ---');
  final tricky = 'front,back,context\n'
      '"含逗号, 的正面","含逗号, 的反面","语境里也有, 逗号"\n'
      '"带引号""的正面","普通反面","普通语境"\n'
      '普通正面,普通反面,\n';
  final trickyCards = tpl.parseCsv(tricky, deckId: 'd1');
  stdout.writeln('解析出 ${trickyCards.length} 张（应为 3）');
  for (final c in trickyCards) {
    stdout.writeln('    front="${c.front}" back="${c.back}" ctx="${c.context}"');
  }

  final noHeader = tpl.parseCsv('abc,def', deckId: 'd1');
  stdout.writeln('无表头 CSV: ${noHeader.length} 张（应为 0，交给文本解析兜底）');

  stdout.writeln('\n=== 验证结束 ===');
  try {
    tmp.deleteSync(recursive: true);
  } catch (_) {
    stdout.writeln('（临时目录可自行清理：${tmp.path}）');
  }
}
