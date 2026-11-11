import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';
import 'card_editor_screen.dart';
import 'study_screen.dart';

/// 3.6 标签与搜索：跨卡包全文搜索 + 按标签筛选 + 按筛选结果组队学习
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  String _query = '';
  String? _tag;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final all = state.allCards;
    final tags = all
        .map((c) => c.tag)
        .where((t) => t != null && t.trim().isNotEmpty)
        .cast<String>()
        .toSet()
        .toList()
      ..sort();

    final q = _query.trim().toLowerCase();
    final results = all.where((c) {
      if (_tag != null && c.tag != _tag) return false;
      if (q.isEmpty) return true;
      return c.front.toLowerCase().contains(q) ||
          c.back.toLowerCase().contains(q) ||
          (c.context ?? '').toLowerCase().contains(q) ||
          (c.source ?? '').toLowerCase().contains(q);
    }).toList();

    // 按标签临时组队学习：只带真正可学的卡（已启用、未暂停、到期）
    final now = DateTime.now();
    final studyable = results
        .where((c) =>
            c.enabled && !c.suspended && state.scheduler.isDue(c, now))
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('搜索卡片')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: TextField(
                controller: _controller,
                autofocus: true,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: '搜索正面 / 反面 / 语境 / 来源',
                  hintStyle: TextStyle(color: AppTheme.ink3, fontSize: 13),
                  prefixIcon: const Icon(Icons.search, size: 20),
                  filled: true,
                  fillColor: AppTheme.cream,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            if (tags.isNotEmpty)
              SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        label: const Text('全部'),
                        selected: _tag == null,
                        onSelected: (_) => setState(() => _tag = null),
                      ),
                    ),
                    ...tags.map((t) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: ChoiceChip(
                            label: Text(t),
                            selected: _tag == t,
                            onSelected: (_) => setState(() => _tag = t),
                          ),
                        )),
                  ],
                ),
              ),
            Expanded(
              child: results.isEmpty
                  ? Center(
                      child: Text('没有找到相关卡片',
                          style: TextStyle(color: AppTheme.ink3)))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                      itemCount: results.length,
                      itemBuilder: (context, i) {
                        final c = results[i];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => CardEditorScreen(
                                      deckId: c.deckId, card: c)),
                            ),
                            title: Text(c.questionFace,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600)),
                            subtitle: Text(c.answerFace,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 12, color: AppTheme.ink2)),
                            trailing: c.tag != null
                                ? Text(c.tag!,
                                    style: TextStyle(
                                        fontSize: 11, color: AppTheme.ink3))
                                : null,
                          ),
                        );
                      },
                    ),
            ),
            if (results.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: studyable.isEmpty
                        ? null
                        : () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      StudyScreen(cards: studyable)),
                            ),
                    child: Text(studyable.isEmpty
                        ? '筛选结果里还没有到期可学的卡'
                        : '学习这些卡片（${studyable.length} 张到期）'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
