import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/deck.dart';
import '../models/card_item.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';
import 'deck_screen.dart';
import 'study_screen.dart';
import 'search_screen.dart';

export '../services/app_state.dart' show StudyMode;

/// 首页：今日任务卡 + 卡包网格
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    if (state.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final due = state.dueCards();
    // v1.2：新卡数受护栏约束（C1 积压 / C2 断卡 / L5 分批释放）
    final newCards = state.newCards();
    final newCount = newCards.length;
    final guardMsg = state.guardMessage;
    final minutes = state.estimateMinutes(StudyMode.normal);
    final totalNewInLibrary =
        state.allCards.where((c) => c.state == 'new' && c.enabled).length;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        children: [
          Text('下午好，宇痕', style: TextStyle(color: AppTheme.ink2, fontSize: 13)),
          const SizedBox(height: 2),
          const Text('今天也要元气满满地复习 🌿',
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w800, height: 1.3)),
          const SizedBox(height: 18),
          // C1/C2 护栏提示
          if (guardMsg != null) _GuardBanner(message: guardMsg),
          if (guardMsg != null) const SizedBox(height: 14),
          _TodayCard(
            dueCount: due.length,
            newCount: newCount,
            cards: [...due, ...newCards],
            estimateMinutes: minutes,
            totalNewInLibrary: totalNewInLibrary,
          ),
          // C8 快速复习入口
          if (due.isNotEmpty) ...[
            const SizedBox(height: 10),
            _QuickReviewButton(dueCount: due.length, cards: due),
          ],
          // C7 超预算提示：真实约束是分钟不是张数
          if (state.isOverBudget(StudyMode.normal) && due.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.cream,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '今天的内容超过 ${state.dailyMinutesBudget} 分钟预算了，'
                '学不完也别硬撑——今天够了，明天再来 🌙',
                style: TextStyle(
                    fontSize: 12, height: 1.5, color: AppTheme.ink2),
              ),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              const _SectionTitle('我的卡包'),
              const Spacer(),
              // 3.6 搜索入口
              IconButton(
                tooltip: '搜索卡片',
                icon: const Icon(Icons.search, size: 22),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SearchScreen()),
                ),
              ),
              // 3.1 新建卡包
              TextButton.icon(
                onPressed: () => _createDeckDialog(context),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('新建', style: TextStyle(fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _DeckGrid(decks: state.decks, state: state),
        ],
      ),
    );
  }
}

/// 3.1 新建卡包对话框
Future<void> _createDeckDialog(BuildContext context) async {
  final state = context.read<AppState>();
  final nameCtrl = TextEditingController();
  final emojiCtrl = TextEditingController(text: '📚');
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialogCtx) => AlertDialog(
      title: const Text('新建卡包'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nameCtrl,
            autofocus: true,
            decoration: const InputDecoration(hintText: '卡包名称，例如：雅思核心词'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: emojiCtrl,
            decoration: const InputDecoration(hintText: '封面 emoji（可选）'),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('取消')),
        TextButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('创建')),
      ],
    ),
  );
  if (ok == true && nameCtrl.text.trim().isNotEmpty) {
    final deck = Deck(
      id: '${DateTime.now().microsecondsSinceEpoch}_deck',
      name: nameCtrl.text.trim(),
      emoji: emojiCtrl.text.trim().isEmpty ? '📚' : emojiCtrl.text.trim(),
      tag: '手动创建',
    );
    await state.createDeck(deck);
  }
}

/// C1 积压保护 / C2 断卡恢复 —— 首页降级提示
class _GuardBanner extends StatelessWidget {
  final String message;
  const _GuardBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF5D9A8)),
      ),
      child: Row(
        children: [
          const Text('🛟', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF8A6327))),
          ),
        ],
      ),
    );
  }
}

class _TodayCard extends StatelessWidget {
  final int dueCount;
  final int newCount;
  final List<CardItem> cards;
  final int estimateMinutes;
  final int totalNewInLibrary;
  const _TodayCard({
    required this.dueCount,
    required this.newCount,
    required this.cards,
    required this.estimateMinutes,
    required this.totalNewInLibrary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF5DCAA5), Color(0xFF3BB08A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('今日待复习',
              style: TextStyle(color: Colors.white, fontSize: 12)),
          Text('$dueCount',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 40,
                  fontWeight: FontWeight.w800,
                  height: 1.1)),
          // C7 预计用时
          Row(
            children: [
              Text('今日约 $estimateMinutes 分钟',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.95),
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              Text('·',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6), fontSize: 12)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  newCount > 0 ? '含 $newCount 张新卡' : '今天不加新卡',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9), fontSize: 12)),
              ),
            ],
          ),
          // L5 分批释放提示
          if (newCount < totalNewInLibrary)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('已启用 $newCount / 共 $totalNewInLibrary 张新卡',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75), fontSize: 11)),
            ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () {
              if (cards.isNotEmpty) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => StudyScreen(
                            cards: cards,
                            mode: StudyMode.normal,
                          )),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('今天没有待复习的卡片，休息一下吧 🎉')),
                );
              }
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: const Text('开始学习',
                  style: TextStyle(
                      color: AppTheme.mintDark,
                      fontWeight: FontWeight.w700,
                      fontSize: 14)),
            ),
          ),
        ],
      ),
    );
  }
}

/// C8 快速复习模式：只清复习，不加新卡
class _QuickReviewButton extends StatelessWidget {
  final int dueCount;
  final List<CardItem> cards;
  const _QuickReviewButton({required this.dueCount, required this.cards});

  @override
  Widget build(BuildContext context) {
    if (dueCount == 0) return const SizedBox.shrink();
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => StudyScreen(
                  cards: cards,
                  mode: StudyMode.reviewOnly,
                )),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.paper,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.line),
        ),
        alignment: Alignment.center,
        child: Text('只清复习（$dueCount 张）',
            style: TextStyle(
                color: AppTheme.ink2,
                fontWeight: FontWeight.w600,
                fontSize: 13)),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);
  @override
  Widget build(BuildContext context) {
    return Text(title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700));
  }
}

class _DeckGrid extends StatelessWidget {
  final List<Deck> decks;
  final AppState state;
  const _DeckGrid({required this.decks, required this.state});

  @override
  Widget build(BuildContext context) {
    if (decks.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        alignment: Alignment.center,
        child: Column(
          children: [
            const Text('📭', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 12),
            Text('还没有卡包，去「导入」创建第一个吧',
                style: TextStyle(color: AppTheme.ink3, fontSize: 13)),
            const SizedBox(height: 18),
            // 空库引导：一键体验完整流程
            GestureDetector(
              onTap: () async {
                final n = await state.loadDemoData();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('已载入 $n 张示例卡片，开始体验吧 🌿')),
                );
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                decoration: BoxDecoration(
                  color: AppTheme.cream,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppTheme.mint),
                ),
                child: const Text('先载入示例卡包看看 ✨',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.mintDark)),
              ),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (ctx, c) {
        // 手机窄屏：格子要变窄，同时加高才能装下「名称+进度条」，否则会溢出
        final narrow = c.maxWidth < 400;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: narrow ? 0.92 : 1.15,
          ),
          itemCount: decks.length,
          itemBuilder: (context, i) {
        final d = decks[i];
        final cards = state.cardsOf(d.id);
        final learned = cards.where((c) => c.state != 'new').length;
        final due = cards
            .where((c) =>
                c.enabled &&
                !c.suspended &&
                state.scheduler.isDue(c, DateTime.now()))
            .length;
        // L5 分批释放：已启用 / 总数
        final enabledCount = cards.where((c) => c.enabled).length;
        final pending = cards.length - enabledCount;
        final pct = cards.isEmpty ? 0 : (learned / cards.length * 100).round();
        final color = Color(d.colorValue);

        return GestureDetector(
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => DeckScreen(deck: d))),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.paper,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(d.emoji, style: const TextStyle(fontSize: 26)),
                    if (due > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text('$due待复习',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: color)),
                      ),
                  ],
                ),
                const Spacer(),
                // 窄屏（320dp）下格子内宽只有 100px，卡名/副标题一换行就把进度条挤出卡片，
                // 所以两者都限单行 + 省略号
                Text(d.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                    pending > 0
                        ? '已启用 $enabledCount / 共 ${cards.length} 张'
                        : '${cards.length} 张 · ${d.tag ?? ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppTheme.ink3, fontSize: 11)),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: pct / 100,
                    backgroundColor: AppTheme.line,
                    color: color,
                    minHeight: 5,
                  ),
                ),
              ],
            ),
          ),
        );
          },
        );
      },
    );
  }
}
