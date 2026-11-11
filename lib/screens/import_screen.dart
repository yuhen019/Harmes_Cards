import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../models/card_item.dart';
import '../models/deck.dart';
import '../services/app_state.dart';
import '../services/document_parser.dart';
import '../services/file_pick.dart';
import '../services/template_service.dart';
import '../theme/app_theme.dart';
import '../widgets/help_tip.dart';

export '../services/app_state.dart' show GuardDefaults;

/// 导入向导：上传文档 → 设置参数 → 生成卡片预览
class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  int _step = 0;
  String _density = '均衡';
  String _detail = '标准';
  String _type = '混合';
  // L4 提问语言 / 回答语言（语言材料默认「母语提问 → 外语回答」）
  String _questionLang = '中文';
  String _answerLang = '英文';
  // C5 方向：false = 按生成的默认方向；true = 翻转（背面提问）
  bool _flipDirection = false;
  final TemplateService _templates = TemplateService();
  List<_GenCard> _preview = [];
  // 文件导入时的来源名（用于卡包命名）与已读取的文档正文
  String? _importedFileName;
  String _importedContent = '';
  bool _importedIsCsv = false;

  bool get _hasDoc => _importedContent.trim().isNotEmpty;

  static const _densityOpts = ['精简', '均衡', '详细'];
  static const _detailOpts = ['简洁', '标准', '详细'];
  static const _typeOpts = ['问答', '填空', '开口', '混合'];
  static const _langOpts = ['中文', '英文', '原文'];

  void _next() {
    if (_step == 0) {
      if (!_hasDoc) {
        _toast('先选一份文档，或直接下载下面的模板填写后再上传');
        return;
      }
      if (_importedIsCsv) {
        final cards = _templates.parseCsv(_importedContent, deckId: 'preview');
        if (cards.isEmpty) {
          _toast(_csvDiag(_importedContent));
          return;
        }
        setState(() {
          _preview = cards
              .map((c) => _GenCard(
                    front: c.front,
                    back: c.back,
                    tag: c.tag,
                    context: c.context,
                    source: c.source,
                    type: c.type,
                    flipped: c.flipped,
                  ))
              .toList();
          _step = 2;
        });
        return;
      }
      setState(() => _step = 1);
      return;
    }
    if (_step == 1) {
      // 生成卡片
      final parser = DocumentParser();
      final cards = parser.generateCards(
        _importedContent,
        deckId: 'preview',
        density: _density,
      );
      if (cards.isEmpty) {
        _toast('没从这份文档里读出卡片，换一份或改用 CSV 模板试试');
        return;
      }
      setState(() {
        _preview = cards
            .map((c) => _GenCard(
                  front: c.front,
                  back: c.back,
                  tag: c.tag,
                  context: c.context,
                  source: c.source,
                  type: c.type,
                ))
            .toList();
        _step = 2;
      });
      return;
    }
    setState(() => _step++);
  }

  Future<void> _import() async {
    final state = context.read<AppState>();
    final deckName = (_importedFileName?.isNotEmpty ?? false)
        ? _importedFileName!
        : '新卡包';
    final deck = Deck(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: deckName,
      emoji: '📖',
      tag: '导入',
    );
    await state.createDeck(deck);

    // 以预览结果为准：CSV 导入与文本解析都统一走预览，避免两次生成导致不一致
    List<CardItem> cards;
    if (_preview.isNotEmpty) {
      final stamp = DateTime.now().microsecondsSinceEpoch;
      cards = _preview.asMap().entries.map((e) {
        final g = e.value;
        return CardItem(
          id: '${stamp}_${e.key}',
          deckId: deck.id,
          front: g.front,
          back: g.back,
          tag: g.tag,
          context: g.context,
          source: g.source ?? deck.name,
          type: g.type,
          flipped: g.flipped,
        );
      }).toList();
    } else {
      final parser = DocumentParser();
      cards = parser.generateCards(
        _importedContent,
        deckId: deck.id,
        density: _density,
      );
    }

    // C5 应用方向翻转 + C4 记录来源
    for (final c in cards) {
      if (_flipDirection && !c.flipped) {
        c.flip();
      }
      c.source ??= deck.name;
    }

    // L5 分批释放：addCards 内部会把超出首批的卡片置为"待启用"
    await state.addCards(cards);

    if (!mounted) return;
    // 回读一次，确认真的进库了（多开窗口互相覆盖时能立刻发现）
    final saved = state.cardsOf(deck.id).length;
    if (saved != cards.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '⚠️ 导入可能没存住：应存 ${cards.length} 张，实际读到 $saved 张。'
              '请关掉其它 Hermes 窗口只留一个，再导入一次'),
          duration: const Duration(seconds: 6),
        ),
      );
      return;
    }
    final enabled = cards.length > GuardDefaults.aiFirstBatch
        ? GuardDefaults.aiFirstBatch
        : cards.length;
    final pending = cards.length - enabled;
    if (!context.mounted) return;
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('导入完成',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('卡包「${deck.name}」共 ${cards.length} 张',
                style: const TextStyle(fontSize: 13, height: 1.5)),
            if (pending > 0) ...[
              const SizedBox(height: 8),
              Text('先启用 $enabled 张，$pending 张存为「待启用」，每天自动放一批。'
                  '在卡包详情页可以手动「现在就放一批」。',
                  style: TextStyle(
                      fontSize: 12, height: 1.5, color: AppTheme.ink2)),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('好的'),
          ),
        ],
      ),
    );
    setState(() {
      _step = 0;
      _preview = [];
      _importedFileName = null;
      _importedContent = '';
      _importedIsCsv = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        children: [
          Text('导入文档', style: TextStyle(color: AppTheme.ink2, fontSize: 13)),
          const SizedBox(height: 2),
          const Text('把资料变成卡片',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          _stepBar(),
          const SizedBox(height: 20),
          if (_step == 0) _buildUpload(),
          if (_step == 1) _buildOptions(),
          if (_step == 2) _buildPreview(),
        ],
      ),
    );
  }

  Widget _stepBar() {
    return Row(
      children: List.generate(3, (i) {
        return Expanded(
          child: Container(
            height: 4,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: i <= _step ? AppTheme.mint : AppTheme.line,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildUpload() {
    return Column(
      children: [
        // 上传区（标题 + 字段说明问号）
        Row(
          children: [
            const Text('上传文档',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(width: 6),
            const HelpTip(
              title: '导入模板的字段说明',
              fields: [
                HelpField('front', '正面 —— 学习者看到的内容（问题/提示）', required: true),
                HelpField('back', '反面 —— 需要主动回忆出来的内容（答案）', required: true),
                HelpField('context', '语境 —— 原文例句/出处原句。孤立知识点调不出来，认得却说不出'),
                HelpField('source', '来源 —— 文档名、章节、集数、时间戳'),
                HelpField('tag', '标签 —— 用于筛选与分组'),
                HelpField('type', '类型 —— basic 问答 / cloze 填空 / speaking 开口卡'),
                HelpField('flipped', '方向 —— 0 默认（front 提问）/ 1 翻转（用 back 提问）'),
              ],
              example:
                  'front,back,context,source,tag,type,flipped\n'
                  '"放弃、抛弃（正式用语）","abandon","They had to ___ the car in the snow.","雅思核心词表","写作高频","basic","0"',
              exampleLabel: 'CSV 示例（含表头）',
              width: 380,
            ),
          ],
        ),
        const SizedBox(height: 10),
        InkWell(
          onTap: _pickFile,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
            decoration: BoxDecoration(
              color: AppTheme.mintLight,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.mint, width: 2),
            ),
            child: Column(
              children: [
                Text(_hasDoc ? '✅' : '📄', style: const TextStyle(fontSize: 36)),
                const SizedBox(height: 10),
                Text(
                  _hasDoc ? _importedFileName! : '点击上传文档',
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.mintDark),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  _hasDoc
                      ? '约 ${_importedContent.trim().length} 字 · 点击可换一份'
                      : '支持 CSV / Markdown / 纯文本',
                  style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.mintDark.withValues(alpha: 0.85))),
              ],
            ),
          ),
        ),
        // 格式写法说明
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('CSV 用表头分列，文本用 ! 和 ; 分卡',
                style: TextStyle(fontSize: 11, color: AppTheme.ink3)),
            const SizedBox(width: 4),
            const HelpTip(
              title: '文本写法要求',
              fields: [
                HelpField('!', '分隔正反面：左边是正面（你看到的），右边是反面（你要回忆的）',
                    required: true),
                HelpField(';', '分隔两张卡片。中英文分号都可以，换行同样算一张卡', required: true),
                HelpField('提示', '一段里出现多个 ! 时，只按第一个切分，后面的内容归入反面'),
              ],
              example: '放弃、抛弃（正式用语）!abandon;可持续的!sustainable;人体最大的器官!皮肤',
              exampleLabel: '示例（一行或分号隔开都行）',
            ),
          ],
        ),
        // 模板下载
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _templateButton('⬇ CSV 模板', '带表头，填完即可导入',
                () => _downloadCsvTemplate())),
            const SizedBox(width: 10),
            Expanded(child: _templateButton('⬇ MD 规格', '给 AI 读的导入规格书',
                () => _downloadMdTemplate())),
          ],
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: _next,
          child: const Text('下一步'),
        ),
      ],
    );
  }

  Widget _templateButton(String label, String sub, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.cream,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.line2),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600)),
                  Text(sub,
                      style: TextStyle(fontSize: 10, color: AppTheme.ink3)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===== 模板下载 =====

  Future<void> _downloadCsvTemplate() async {
    try {
      final path = await _templates.exportCsvTemplate();
      if (!mounted) return;
      await _showTemplateSaved(
        title: 'CSV 模板已保存',
        body: '用 Excel 或记事本打开填写即可，第一行的表头不要删。填好后回到这里「点击上传文档」选择它。',
        path: path,
      );
    } catch (e) {
      _toast('保存失败：$e');
    }
  }

  Future<void> _downloadMdTemplate() async {
    try {
      final path = await _templates.exportMdTemplate();
      if (!mounted) return;
      await _showTemplateSaved(
        title: 'MD 规格文档已保存',
        body: '这是一份给 AI 助手读的「卡片导入规格」。把它丢给 AI，让它按规格产出 CSV，就能直接导入。'
            '里面还写了卡片写作铁律（一卡一义、答案 ≤9 词、必须有语境、不生成选择题）。',
        path: path,
      );
    } catch (e) {
      _toast('保存失败：$e');
    }
  }

  Future<void> _showTemplateSaved(
      {required String title, required String body, required String path}) {
    return showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(body, style: const TextStyle(fontSize: 13, height: 1.5)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.cream,
                borderRadius: BorderRadius.circular(10),
              ),
              child: SelectableText(path,
                  style: const TextStyle(fontSize: 11, height: 1.4)),
            ),
          ],
        ),
        actions: [
          // 手机上没有"打开文件夹"这回事（Process.run 会崩），桌面才显示
          if (Platform.isWindows || Platform.isMacOS || Platform.isLinux)
            TextButton(
              onPressed: () => _openFolder(path),
              child: const Text('打开文件夹'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('好的', style: TextStyle(color: AppTheme.ink3)),
          ),
        ],
      ),
    );
  }

  void _openFolder(String filePath) {
    try {
      final dir = File(filePath).parent.path;
      if (Platform.isWindows) {
        Process.run('explorer.exe', [dir]);
      } else if (Platform.isMacOS) {
        Process.run('open', [dir]);
      } else {
        Process.run('xdg-open', [dir]);
      }
    } catch (_) {
      // 打开文件夹失败不影响模板已保存
    }
  }

  // ===== 文件导入 =====

  Future<void> _pickFile() async {
    late final PlatformFile file;
    try {
      final picked = await FilePick.pick(
        extensions: const ['csv', 'md', 'markdown', 'txt'],
        dialogTitle: '选择要导入的文档',
      );
      if (picked == null) return; // 用户取消
      file = picked;
    } on FilePickError catch (e) {
      _toast(e.message);
      return;
    }

    String content;
    try {
      if (file.bytes != null) {
        // 必须按编码解，不能逐字节当字符（否则 UTF-8 中文全变乱码）
        content = TemplateService.decodeBytes(file.bytes!);
      } else if (file.path != null) {
        content = TemplateService.decodeBytes(await File(file.path!).readAsBytes());
      } else {
        _toast('读取文件失败');
        return;
      }
    } catch (e) {
      _toast('读取文件失败：$e');
      return;
    }
    if (content.trim().isEmpty) {
      _toast('这个文件是空的');
      return;
    }
    // 解码出来有大量替换字符 = 文件不是 UTF-8（多半是 Excel 存成了 ANSI/GBK）
    if (content.contains('\uFFFD')) {
      _toast('注意：文件编码不是 UTF-8，中文可能是乱码。请用「另存为 → CSV UTF-8」再传一次');
    }

    final name = file.name;
    final lower = name.toLowerCase();

    if (lower.endsWith('.csv')) {
      // CSV 是结构化的，直接解析成卡片进入预览
      final cards = _templates.parseCsv(content, deckId: 'preview');
      if (cards.isEmpty) {
        _toast(_csvDiag(content));
        return;
      }
      setState(() {
        _importedFileName = name.replaceAll(RegExp(r'\.csv$', caseSensitive: false), '');
        _importedContent = content;
        _importedIsCsv = true;
        _preview = cards
            .map((c) => _GenCard(
                  front: c.front,
                  back: c.back,
                  tag: c.tag,
                  context: c.context,
                  source: c.source,
                  type: c.type,
                  flipped: c.flipped,
                ))
            .toList();
        _step = 2;
      });
      return;
    }

    // Markdown / 纯文本：存下正文，走后续参数设置
    setState(() {
      _importedFileName =
          name.replaceAll(RegExp(r'\.(md|markdown|txt)$', caseSensitive: false), '');
      _importedContent = content;
      _importedIsCsv = false;
    });
    _toast('已读取「$name」，点「下一步」设置参数');
  }

  /// CSV 认不出表头时，把读到的第一行回显出来，方便定位编码/格式问题
  String _csvDiag(String content) {
    final line = content
        .split('\n')
        .firstWhere((l) => l.trim().isNotEmpty, orElse: () => '')
        .trim();
    final shown = line.length > 36 ? '${line.substring(0, 36)}…' : line;
    return '没认出 front / back 两列。读到的第一行：「$shown」。'
        '请确认首行是表头 front,back,context,source,tag,type,flipped';
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Widget _buildOptions() {
    return Column(
      children: [
        _optionCard('卡片密度', _densityOpts, _density, (v) => setState(() => _density = v)),
        _optionCard('答案详细度', _detailOpts, _detail, (v) => setState(() => _detail = v)),
        _optionCard('卡片类型', _typeOpts, _type, (v) => setState(() => _type = v)),
        // L4 提问语言 / 回答语言
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF2FBF7),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.mint.withValues(alpha: 0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('你想被考的是哪种语言？',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(
                '语言材料默认「$_questionLang提问 → $_answerLang回答」。'
                '反过来（外语提问）练的是阅读认词，对开口帮助很小。',
                style: TextStyle(color: AppTheme.ink3, fontSize: 11, height: 1.4),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _langDropdown('提问', _questionLang,
                        (v) => setState(() => _questionLang = v)),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('→', style: TextStyle(fontSize: 15)),
                  ),
                  Expanded(
                    child: _langDropdown('回答', _answerLang,
                        (v) => setState(() => _answerLang = v)),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: _next,
          child: const Text('生成卡片'),
        ),
      ],
    );
  }

  Widget _langDropdown(String label, String value, ValueChanged<String> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.paper,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 10, color: AppTheme.ink3)),
          DropdownButton<String>(
            value: value,
            isExpanded: true,
            underline: const SizedBox.shrink(),
            items: _langOpts
                .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                .toList(),
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
          ),
        ],
      ),
    );
  }

  Widget _optionCard(String title, List<String> opts, String selected,
      ValueChanged<String> onSelect) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.paper,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: opts.map((o) {
              final sel = o == selected;
              return GestureDetector(
                onTap: () => onSelect(o),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: sel ? AppTheme.mintLight : AppTheme.paper,
                    borderRadius: BorderRadius.circular(999),
                    border: sel
                        ? null
                        : Border.all(color: AppTheme.line2),
                  ),
                  child: Text(o,
                      style: TextStyle(
                          fontSize: 12,
                          color: sel ? AppTheme.mintDark : AppTheme.ink2,
                          fontWeight: sel ? FontWeight.w700 : FontWeight.w400)),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  /// C5 方向确认：显示 3 张样例卡的正面，问"你想被考的是哪一面？"
  Widget _buildDirectionCard() {
    final samples = _preview.take(3).toList();
    if (samples.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF2FBF7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.mint.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('你想被考的是哪一面？',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('下面是 3 张样例卡的正面（你看到的部分）',
              style: TextStyle(color: AppTheme.ink3, fontSize: 11)),
          const SizedBox(height: 10),
          ...samples.map((c) {
            final face = _flipDirection ? c.back : c.front;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('· ', style: TextStyle(fontSize: 12)),
                  Expanded(
                    child: Text(face,
                        style: const TextStyle(fontSize: 12, height: 1.4),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => setState(() => _flipDirection = !_flipDirection),
            icon: const Icon(Icons.swap_horiz, size: 16),
            label: Text(_flipDirection ? '已翻转：用答案面提问' : '翻转方向'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.mintDark,
              side: BorderSide(color: AppTheme.mint.withValues(alpha: 0.6)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  /// L3 语块长度硬提示：答案超过 9 个词 → 温和提示（不阻断）
  /// 中文按字数折算（约 2.5 字 ≈ 1 词），英文按空格分词
  int _chunkCount(String text) {
    final t = text.trim();
    if (t.isEmpty) return 0;
    if (t.contains(' ')) {
      return t.split(RegExp(r'\s+')).length;
    }
    return (t.length / 2.5).ceil();
  }

  Widget _lengthHint(String text) {
    final n = _chunkCount(text);
    if (n <= 9) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        children: [
          const Text('⚠️ ', style: TextStyle(fontSize: 10)),
          Expanded(
            child: Text('这张可能太长（约 $n 词），考虑拆开',
                style: const TextStyle(fontSize: 10, color: Color(0xFFB8860B))),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    // L5 分批释放：默认只启用前 20 张
    final firstBatch =
        _preview.length > GuardDefaults.aiFirstBatch ? GuardDefaults.aiFirstBatch : _preview.length;
    final pending = _preview.length - firstBatch;

    return Column(
      children: [
        Text('已生成 ${_preview.length} 张卡片，预览确认',
            style: TextStyle(color: AppTheme.ink2, fontSize: 13)),
        const SizedBox(height: 12),

        // L5 分批释放说明
        if (pending > 0)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF4E5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFF5D9A8)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('🌱', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '默认只启用前 $firstBatch 张，其余 $pending 张存为「待启用」'
                    '，每天自动释放一批。这样不会第三天就积压爆炸。',
                    style: const TextStyle(
                        fontSize: 11,
                        height: 1.4,
                        color: Color(0xFF8A6327)),
                  ),
                ),
              ],
            ),
          ),

        // C5 样例卡方向确认（显示 3 张样例卡的正面 + 一键翻转）
        _buildDirectionCard(),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.paper,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.line),
          ),
          child: Column(
            children: _preview.asMap().entries.map((e) {
              final i = e.key;
              final c = e.value;
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  border: i < _preview.length - 1
                      ? const Border(
                          bottom: BorderSide(color: AppTheme.line))
                      : null,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: AppTheme.mintLight,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      alignment: Alignment.center,
                      child: Text('${i + 1}',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.mintDark)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_flipDirection ? c.back : c.front,
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 3),
                          Text(_flipDirection ? c.front : c.back,
                              style: TextStyle(
                                  color: AppTheme.ink2, fontSize: 11)),
                          // L3 长度提示
                          _lengthHint(_flipDirection ? c.front : c.back),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: _import,
          child: const Text('确认导入卡包'),
        ),
        TextButton(
          onPressed: () => setState(() => _step = 0),
          child: Text('重新生成',
              style: TextStyle(color: AppTheme.ink2, fontSize: 13)),
        ),
      ],
    );
  }
}

class _GenCard {
  final String front;
  final String back;
  final String? tag;
  String? context;
  String? source;
  CardType type;
  bool flipped;

  _GenCard({
    required this.front,
    required this.back,
    this.tag,
    this.context,
    this.source,
    this.type = CardType.basic,
    this.flipped = false,
  });
}
