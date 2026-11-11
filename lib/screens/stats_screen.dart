import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';

/// 统计页：连续打卡、累计复习、保持率、热力图
class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final totalCards = state.decks.fold<int>(
        0, (sum, d) => sum + state.cardsOf(d.id).length);
    final reviewed = state.decks.fold<int>(
        0, (sum, d) => sum + state.cardsOf(d.id).where((c) => c.reps > 0).length);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        children: [
          Text('学习统计', style: TextStyle(color: AppTheme.ink2, fontSize: 13)),
          const SizedBox(height: 2),
          const Text('坚持是最酷的事 ✨',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 20),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.6,
            children: [
              _statBox('6', '连续打卡（天）', AppTheme.mintDark),
              _statBox('$reviewed', '累计复习（张）', AppTheme.ink),
              _statBox('$totalCards', '卡片总数', AppTheme.blue),
              _statBox('91%', '保持率', AppTheme.coral),
            ],
          ),
          const SizedBox(height: 20),
          // 诊断型指标（3.5 新增）：提前预警崩溃
          const _SectionTitle('健康诊断'),
          const SizedBox(height: 10),
          FutureBuilder<double>(
            future: state.matureAccuracy(),
            builder: (context, snap) {
              final acc = snap.data ?? 1.0;
              final pct = (acc * 100).round();
              final warning = acc < 0.80;
              return _diagRow(
                '成熟卡正确率',
                '$pct%',
                warning
                    ? '低于 80%：新卡加太快或卡片质量差，考虑放慢节奏'
                    : '健康（≥80% 说明节奏合适）',
                warning ? AppTheme.again : AppTheme.mintDark,
              );
            },
          ),
          const SizedBox(height: 10),
          _diagRow(
            '顽固卡 Leech',
            '${state.leechCards.length} 张',
            state.leechCards.isEmpty
                ? '没有写坏的卡片'
                : '这些卡连错多次，建议改写或删除',
            state.leechCards.isEmpty ? AppTheme.mintDark : AppTheme.hard,
          ),
          const SizedBox(height: 10),
          _diagRow(
            '平均单卡耗时',
            '${(state.avgCardMs / 1000).toStringAsFixed(1)} 秒',
            '用于估算首页「今日约 N 分钟」',
            AppTheme.blue,
          ),
          const SizedBox(height: 20),
          _heatmap(),
          const SizedBox(height: 16),
          _weeklyBars(),
        ],
      ),
    );
  }

  /// 诊断型指标行
  Widget _diagRow(String title, String value, String hint, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.paper,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.line),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(hint,
                    style: TextStyle(color: AppTheme.ink3, fontSize: 11, height: 1.3)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(value,
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }

  Widget _statBox(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.paper,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(value,
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: AppTheme.ink3, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _heatmap() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.paper,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('复习热力图 · 近 12 周',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          // 简化热力图：用 GridView 表示
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 12,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
            ),
            itemCount: 84,
            itemBuilder: (context, i) {
              final v = (i * 7) % 5;
              const colors = [
                Color(0xFFECEFED),
                Color(0xFFB8E8D6),
                Color(0xFF7DD5B4),
                Color(0xFF3BB08A),
                Color(0xFF1D9E75),
              ];
              return Container(
                decoration: BoxDecoration(
                  color: colors[v],
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _weeklyBars() {
    const days = ['一', '二', '三', '四', '五', '六', '日'];
    const vals = [42, 68, 35, 90, 55, 120, 0];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.paper,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('每日复习量（近 7 天）',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(7, (i) {
              final h = (vals[i] / 120 * 80).clamp(4.0, 80.0);
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: Column(
                    children: [
                      Container(
                        height: h,
                        decoration: BoxDecoration(
                          color: i == 5 ? AppTheme.mintDark : AppTheme.mint,
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(6)),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(days[i],
                          style: TextStyle(color: AppTheme.ink3, fontSize: 9)),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
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
