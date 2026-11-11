import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/card_item.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';

/// 卡片编辑器：手动录入新卡 / 编辑已有卡（含 C3 顽固卡「改写」入口）
class CardEditorScreen extends StatefulWidget {
  final String deckId;
  final CardItem? card; // null = 新建
  const CardEditorScreen({super.key, required this.deckId, this.card});

  @override
  State<CardEditorScreen> createState() => _CardEditorScreenState();
}

class _CardEditorScreenState extends State<CardEditorScreen> {
  late final TextEditingController _front;
  late final TextEditingController _back;
  late final TextEditingController _context;
  late final TextEditingController _source;
  late final TextEditingController _tag;
  late bool _flipped;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final c = widget.card;
    _front = TextEditingController(text: c?.front ?? '');
    _back = TextEditingController(text: c?.back ?? '');
    _context = TextEditingController(text: c?.context ?? '');
    _source = TextEditingController(text: c?.source ?? '');
    _tag = TextEditingController(text: c?.tag ?? '');
    _flipped = c?.flipped ?? false;
    _back.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _front.dispose();
    _back.dispose();
    _context.dispose();
    _source.dispose();
    _tag.dispose();
    super.dispose();
  }

  /// L3 语块长度提示：答案超过 9 个词温和提醒（不阻断）
  int get _backWordCount {
    final t = _back.text.trim();
    if (t.isEmpty) return 0;
    // 英文按空格分词；中文按字符粗估（中文 9 词 ≈ 18 字）
    final words = t.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    if (words > 1) return words;
    return (t.runes.length / 2).ceil();
  }

  Future<void> _save() async {
    if (_front.text.trim().isEmpty || _back.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('正面和反面都要填写哦')),
      );
      return;
    }
    setState(() => _saving = true);
    final state = context.read<AppState>();
    final card = widget.card ??
        CardItem(
          id: '${DateTime.now().microsecondsSinceEpoch}_manual',
          deckId: widget.deckId,
          front: '',
          back: '',
          source: '手动录入',
        );
    card.front = _front.text.trim();
    card.back = _back.text.trim();
    card.context = _context.text.trim().isEmpty ? null : _context.text.trim();
    card.source = _source.text.trim().isEmpty
        ? (card.source ?? '手动录入')
        : _source.text.trim();
    card.tag = _tag.text.trim().isEmpty ? null : _tag.text.trim();
    if (card.flipped != _flipped) card.flip();
    card.updatedAt = DateTime.now();
    await state.addCard(card);
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.card == null;
    return Scaffold(
      appBar: AppBar(title: Text(isNew ? '新卡片' : '编辑卡片')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            _field(_front, '正面（你看到什么）', '例如：放弃、抛弃（正式用语）'),
            const SizedBox(height: 14),
            _field(_back, '反面（你要回忆什么）', '例如：abandon'),
            if (_backWordCount > 9) ...[
              const SizedBox(height: 6),
              Text('这张可能太长，考虑拆开（一卡一义）',
                  style: TextStyle(fontSize: 12, color: AppTheme.hard)),
            ],
            const SizedBox(height: 14),
            _field(_context, '语境（例句 / 出处原句，可选）',
                '孤立的知识点调不出来，给它一个例句',
                maxLines: 3),
            const SizedBox(height: 14),
            _field(_source, '来源（可选）', '文档名 / 集数 / 时间戳'),
            const SizedBox(height: 14),
            _field(_tag, '标签（可选）', '例如：词汇、寒暄'),
            const SizedBox(height: 10),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('翻转正反面', style: TextStyle(fontSize: 14)),
              subtitle: Text(
                _flipped ? '当前：反面提问 → 正面回答' : '当前：正面提问 → 反面回答',
                style: TextStyle(fontSize: 12, color: AppTheme.ink3),
              ),
              value: _flipped,
              activeTrackColor: AppTheme.mint,
              onChanged: (v) => setState(() => _flipped = v),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? '保存中…' : '保存'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String label, String hint,
      {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        TextField(
          controller: c,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: AppTheme.ink3, fontSize: 12),
            filled: true,
            fillColor: AppTheme.cream,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}
