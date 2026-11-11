import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/card_item.dart';
import '../services/app_state.dart' show AppState, StudyMode;
import '../theme/app_theme.dart';
import 'card_editor_screen.dart';

/// 学习页：翻面 + 四键评分（FSRS）
class StudyScreen extends StatefulWidget {
  final List<CardItem> cards;
  final StudyMode mode;
  const StudyScreen({
    super.key,
    required this.cards,
    this.mode = StudyMode.normal,
  });

  @override
  State<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends State<StudyScreen> {
  int _idx = 0;
  bool _flipped = false;
  late List<CardItem> _cards;
  DateTime? _cardStart;

  @override
  void initState() {
    super.initState();
    _cards = widget.cards;
    _cardStart = DateTime.now();
  }

  void _flip() => setState(() => _flipped = !_flipped);

  Future<void> _rate(ReviewGrade grade) async {
    final card = _cards[_idx];
    final state = context.read<AppState>();
    final elapsed =
        _cardStart != null ? DateTime.now().difference(_cardStart!) : null;

    await state.reviewCard(
      card,
      grade,
      durationMs: elapsed?.inMilliseconds ?? 8000,
    );

    if (!mounted) return;

    // C3 Leech：连错达阈值 → 提示改写或删除
    final becameLeech = grade == ReviewGrade.again &&
        card.againCount >= state.leechThreshold;

    if (_idx >= _cards.length - 1) {
      // 最后一张：先弹对话框，由对话框负责退出学习页，
      // 避免先 pop 再用已停用的 context 弹窗
      if (becameLeech) {
        _showLeechDialog(card, state, exitStudy: true);
      } else {
        _showDone(exitStudy: true);
      }
    } else {
      setState(() {
        _idx++;
        _flipped = false;
        _cardStart = DateTime.now();
      });
      if (becameLeech) {
        _showLeechDialog(card, state);
      }
    }
  }

  /// C3 顽固卡处理：连错 4 次说明卡片写坏了，提示改写或删除
  void _showLeechDialog(CardItem card, AppState state,
      {bool exitStudy = false}) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('这张卡先放一放 🪨'),
        content: Text(
          '已经连续 ${card.againCount} 次「重来」了。\n\n'
          '这通常不是记性问题，而是卡片本身太长、太抽象或缺少语境。\n'
          '建议改写它（拆短 / 加例句），或者直接删掉。',
          style: TextStyle(fontSize: 13, color: AppTheme.ink2, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              state.deleteCard(card.id);
              if (exitStudy) Navigator.pop(context);
            },
            child: const Text('删除', style: TextStyle(color: AppTheme.again)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              // C3「改写」直达编辑器；改完后恢复并重置 Leech 计数
              await Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => CardEditorScreen(
                        deckId: card.deckId, card: card)),
              );
              await state.reviveCard(card);
              if (exitStudy && mounted) Navigator.pop(context);
            },
            child: const Text('改写',
                style: TextStyle(color: AppTheme.mintDark)),
          ),
        ],
      ),
    );
  }

  void _showDone({bool exitStudy = false}) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎉', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            const Text('太棒了，全部完成！',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text('本轮共复习 ${_cards.length} 张卡片',
                style: TextStyle(color: AppTheme.ink2, fontSize: 13)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              if (exitStudy) Navigator.pop(context);
            },
            child: const Text('完成', style: TextStyle(color: AppTheme.mintDark)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_cards.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('学习')),
        body: const Center(child: Text('没有可学习的卡片')),
      );
    }

    final card = _cards[_idx];
    final pct = (_idx / _cards.length * 100).clamp(0, 100);

    return Scaffold(
      backgroundColor: AppTheme.paper,
      appBar: AppBar(
        title: Text(widget.mode == StudyMode.reviewOnly ? '快速复习' : '学习'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 进度条
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: pct / 100,
                      backgroundColor: AppTheme.line,
                      color: AppTheme.mint,
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('${_idx + 1} / ${_cards.length}',
                      style: TextStyle(color: AppTheme.ink3, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // 翻面卡片
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GestureDetector(
                  onTap: _flip,
                  child: TweenAnimationBuilder(
                    tween: Tween<double>(begin: 0, end: _flipped ? 1 : 0),
                    duration: const Duration(milliseconds: 450),
                    curve: Curves.easeInOut,
                    builder: (context, value, _) {
                      final angle = value * 3.14159265;
                      final showBack = value > 0.5;
                      return Transform(
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.001)
                          ..rotateY(angle),
                        alignment: Alignment.center,
                        child: showBack
                            ? Transform(
                                transform: Matrix4.identity()..rotateY(3.14159265),
                                alignment: Alignment.center,
                                child: _buildFace(card, isBack: true),
                              )
                            : _buildFace(card, isBack: false),
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // 四键评分
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Row(
                children: [
                  _rateBtn('重来', '忘了', AppTheme.again, ReviewGrade.again),
                  const SizedBox(width: 10),
                  _rateBtn('困难', '模糊', AppTheme.hard, ReviewGrade.hard),
                  const SizedBox(width: 10),
                  _rateBtn('良好', '想起', AppTheme.good, ReviewGrade.good),
                  const SizedBox(width: 10),
                  _rateBtn('简单', '秒答', AppTheme.easy, ReviewGrade.easy),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// C5 学习页一键翻转（只翻方向，复习记录保留）
  Future<void> _flipDirection() async {
    final card = _cards[_idx];
    setState(() => card.flip());
    await context.read<AppState>().addCard(card);
  }

  Widget _buildFace(CardItem card, {required bool isBack}) {
    // C5 翻转：使用翻转后的实际提问面 / 回答面
    final text = isBack ? card.answerFace : card.questionFace;
    return Container(
      decoration: BoxDecoration(
        color: isBack ? const Color(0xFFF2FBF7) : AppTheme.paper,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.line),
      ),
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Align(
            alignment: Alignment.topLeft,
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.cream,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: AppTheme.line),
                  ),
                  child: Text(isBack ? '你要回忆' : '你看到',
                      style: TextStyle(
                          fontSize: 11,
                          color: isBack ? AppTheme.mintDark : AppTheme.ink3)),
                ),
                // C5 翻转标记
                if (card.flipped) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.mint.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text('已翻转',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.mintDark)),
                  ),
                ],
                const Spacer(),
                // C5 一键翻转按钮
                InkWell(
                  onTap: _flipDirection,
                  borderRadius: BorderRadius.circular(999),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.swap_horiz,
                        size: 20, color: AppTheme.mintDark),
                  ),
                ),
                const SizedBox(width: 6),
                if (card.tag != null)
                  // 标签来自导入文件，长度不可控；手机上必须限宽省略，否则整行溢出
                  Flexible(
                    child: Text(
                      card.tag!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: AppTheme.ink3),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      text,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: isBack ? 16 : 21,
                        fontWeight: FontWeight.w700,
                        height: 1.6,
                        color: AppTheme.ink,
                      ),
                    ),
                    // C4 语境：孤立知识点调不出来，答案面显示语境
                    if (isBack &&
                        card.context != null &&
                        card.context!.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.cream,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('语境',
                                style: TextStyle(
                                    fontSize: 10, color: AppTheme.ink3)),
                            const SizedBox(height: 4),
                            Text(card.context!,
                                style: TextStyle(
                                    fontSize: 13,
                                    height: 1.5,
                                    color: AppTheme.ink2)),
                          ],
                        ),
                      ),
                    ],
                    // C4 来源
                    if (isBack &&
                        card.source != null &&
                        card.source!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text('— ${card.source}',
                          style:
                              TextStyle(fontSize: 10, color: AppTheme.ink3)),
                    ],
                  ],
                ),
              ),
            ),
          ),
          if (!isBack)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('点击卡片查看答案',
                  style: TextStyle(color: AppTheme.ink3, fontSize: 12)),
            ),
        ],
      ),
    );
  }

  Widget _rateBtn(String label, String sub, Color color, ReviewGrade grade) {
    return Expanded(
      child: GestureDetector(
        onTap: _flipped ? () => _rate(grade) : null,
        child: Opacity(
          opacity: _flipped ? 1 : 0.4,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 13),
            decoration: BoxDecoration(
              color: AppTheme.paper,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.line),
            ),
            child: Column(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration:
                      BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(height: 6),
                Text(label,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                Text(sub,
                    style: TextStyle(color: AppTheme.ink3, fontSize: 9)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
