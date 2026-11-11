import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/deck.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';
import 'study_screen.dart';
import 'card_editor_screen.dart';

/// 牌组详情页
class DeckScreen extends StatelessWidget {
  final Deck deck;
  const DeckScreen({super.key, required this.deck});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final cards = state.cardsOf(deck.id);
    final color = Color(deck.colorValue);
    // 只有「已启用且未暂停」的卡才会计入学习队列
    final active =
        cards.where((c) => c.enabled && !c.suspended).toList();
    final pending = cards.length - active.length;
    final due =
        active.where((c) => state.scheduler.isDue(c, DateTime.now())).length;
    final newCount = active.where((c) => c.state == 'new').length;
    final learned = active.where((c) => c.state != 'new').length;
    final pct = active.isEmpty ? 0 : (learned / active.length * 100).round();

    return Scaffold(
      appBar: AppBar(
        title: const Text('卡包详情'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // 3.2.1 手动录入
          IconButton(
            tooltip: '手动添加卡片',
            icon: const Icon(Icons.add),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => CardEditorScreen(deckId: deck.id)),
            ),
          ),
          // 3.1 卡包管理：重命名 / 归档 / 删除
          PopupMenuButton<String>(
            onSelected: (v) async {
              switch (v) {
                case 'rename':
                  await _renameDialog(context);
                  break;
                case 'archive':
                  await state.setDeckArchived(deck, !deck.archived);
                  if (context.mounted) Navigator.pop(context);
                  break;
                case 'delete':
                  await _deleteDialog(context, state);
                  break;
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'rename', child: Text('重命名')),
              PopupMenuItem(
                  value: 'archive',
                  child: Text(deck.archived ? '取消归档' : '归档（首页隐藏）')),
              const PopupMenuItem(
                  value: 'delete',
                  child: Text('删除卡包', style: TextStyle(color: Colors.red))),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Row(
              children: [
                Text(deck.emoji, style: const TextStyle(fontSize: 30)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(deck.name,
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w800)),
                      Text('${deck.tag ?? ''} · ${cards.length} 张卡片',
                          style: TextStyle(color: AppTheme.ink3, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _miniStat('$due', '待复习', color),
                const SizedBox(width: 10),
                _miniStat('$newCount', '新卡片', AppTheme.ink),
                const SizedBox(width: 10),
                _miniStat('$pct%', '掌握度', AppTheme.ink),
              ],
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: due == 0
                  ? null
                  : () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => StudyScreen(
                                cards: active.where((c) => state.scheduler.isDue(c, DateTime.now())).toList())),
                      ),
              child: const Text('开始复习这个卡包'),
            ),
            // L5 分批释放：未启用的卡要有可见出口，否则永远学不到
            if (pending > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4E5),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFF5D9A8)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('还有 $pending 张没启用',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF8A6327))),
                    const SizedBox(height: 4),
                    Text(
                      '这是防积压护栏：一次导入太多不会全部涌进来。'
                      '每天自动放 ${state.dailyNewLimit} 张，手上的学得差不多了就会补。',
                      style: const TextStyle(
                          fontSize: 11, height: 1.4, color: Color(0xFF8A6327)),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () async {
                        await state.releaseBatch(deck.id);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('已释放一批新卡')));
                      },
                      icon: const Icon(Icons.unfold_more, size: 16),
                      label: Text('现在就放一批（${state.dailyNewLimit} 张）'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF8A6327),
                        side: const BorderSide(color: Color(0xFFF5D9A8)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            Text('全部卡片（${cards.length}）',
                style: TextStyle(
                    color: AppTheme.ink2, fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            if (cards.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Text('这个卡包还没有卡片',
                      style: TextStyle(color: AppTheme.ink3, fontSize: 13)),
                ),
              )
            else
              ...cards.map((c) => _cardItem(context, c, color)).toList(),
          ],
        ),
      ),
    );
  }

  Future<void> _renameDialog(BuildContext context) async {
    final state = context.read<AppState>();
    final controller = TextEditingController(text: deck.name);
    final name = await showDialog<String>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('重命名卡包'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '卡包名称'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('取消')),
          TextButton(
              onPressed: () =>
                  Navigator.pop(dialogCtx, controller.text.trim()),
              child: const Text('保存')),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      await state.renameDeck(deck, name);
    }
  }

  Future<void> _deleteDialog(BuildContext context, AppState state) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('删除卡包？'),
        content: Text('「${deck.name}」和里面的 ${state.cardsOf(deck.id).length} 张卡片都会被删除，此操作不可恢复。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(dialogCtx, true),
              child: const Text('删除', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed == true) {
      await state.removeDeck(deck.id);
      if (context.mounted) Navigator.pop(context);
    }
  }

  Widget _miniStat(String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.cream,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(color: AppTheme.ink3, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _cardItem(BuildContext context, dynamic card, Color color) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) =>
                CardEditorScreen(deckId: card.deckId, card: card)),
      ),
      child: Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.paper,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.line),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text('Q',
                style: TextStyle(color: color, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(card.questionFace,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text('${card.tag ?? ''}',
                    style: TextStyle(color: AppTheme.ink3, fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }
}
