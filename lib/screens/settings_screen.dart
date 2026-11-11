import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../services/app_state.dart';
import '../services/file_pick.dart';
import '../services/sync_service.dart';
import '../theme/app_theme.dart';

/// 设置页：目标保持率、每日上限、手动同步
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _darkMode = false;
  bool _flipAnim = true;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        children: [
          Text('我的', style: TextStyle(color: AppTheme.ink2, fontSize: 13)),
          const SizedBox(height: 2),
          const Text('设置',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 20),
          _group('学习偏好', [
            _sliderItem(
              '目标保持率',
              '想记多牢（0.95 复习量暴涨，0.85 调不出来）',
              state.desiredRetention * 100,
              (v) => state.setDesiredRetention(v / 100),
            ),
            // C1 新卡上限（默认 8）
            _stepperItem(
              '每日新卡上限',
              '默认 8：8×7≈56 张/周，与提取 3–5 个知识点的节奏匹配',
              state.dailyNewLimit,
              0,
              50,
              state.setDailyNewLimit,
            ),
            // C1 复习上限（默认不限）
            _stepperItem(
              '每日复习上限',
              '默认不限：还债不许设上限',
              state.dailyReviewLimit,
              20,
              9999,
              state.setDailyReviewLimit,
            ),
            // C7 每日时间预算（默认 10 分钟）
            _stepperItem(
              '每日时间预算',
              '默认 10 分钟：真实约束是分钟，不是张数',
              state.dailyMinutesBudget,
              5,
              60,
              state.setDailyMinutesBudget,
            ),
            _switchItem('深色模式', '复习多在睡前，夜间模式是刚需', _darkMode,
                (v) => setState(() => _darkMode = v)),
            _switchItem('翻面动画', '', _flipAnim, (v) => setState(() => _flipAnim = v)),
          ]),
          // C6 学习步进参数（暴露可调）
          _group('学习步进（C6）', [
            _stepperItem(
              '新卡步进 1',
              '当天第一遍间隔（分钟）',
              state.newStep1Minutes,
              1,
              60,
              (v) => state.setLearningSteps(step1: v),
            ),
            _stepperItem(
              '新卡步进 2',
              '当天第二遍间隔（分钟）',
              state.newStep2Minutes,
              1,
              120,
              (v) => state.setLearningSteps(step2: v),
            ),
            _stepperItem(
              '毕业间隔',
              '新卡进入正式复习的初始间隔（天）',
              state.graduatingIntervalDays,
              1,
              30,
              (v) => state.setLearningSteps(graduating: v),
            ),
            _stepperItem(
              '简单间隔',
              '评为「简单」的间隔（天）',
              state.easyIntervalDays,
              1,
              30,
              (v) => state.setLearningSteps(easy: v),
            ),
          ]),
          // C1/C2/C3 护栏状态（只读）
          _group('护栏状态（自动）', [
            _rowItem('当前积压', '>150 自动暂停新卡', '${state.backlogCount} 张'),
            _rowItem('顽固卡 Leech', 'Again ≥${state.leechThreshold} 次自动暂停',
                '${state.leechCards.length} 张'),
            _rowItem('断卡状态', '≥3 天回归只清复习',
                state.isReturningFromBreak ? '已断 ${state.breakDays} 天' : '连续学习中'),
          ]),
          _group('手动同步', [
            _arrowItem('导出学习数据包', '生成 JSON，拷到另一台设备导入', _exportData),
            _arrowItem('导入学习数据包', '按卡片智能合并，不会互相覆盖', _importData),
            _arrowItem('导出为 CSV', '兼容其他卡片软件', _exportCsv),
          ]),
          _group('演示数据', [
            state.hasDemo
                ? _arrowItem('清除演示数据', '移除示例卡包，保留你自己的卡片',
                    _clearDemo)
                : _arrowItem(
                    '载入演示数据', '3 个示例卡包，含复习历史，方便体验完整流程',
                    _loadDemo),
          ]),
          // 数据位置：卡片到底存在哪，一键看得到、打得到
          FutureBuilder<String>(
            future: context.read<AppState>().dataDirectory(),
            builder: (context, snap) {
              final dir = snap.data ?? '读取中…';
              return _group('数据位置', [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('卡片存在这个文件夹里（hermes_cards.json）',
                          style: TextStyle(fontSize: 12, color: AppTheme.ink3)),
                      const SizedBox(height: 6),
                      SelectableText(dir,
                          style: const TextStyle(fontSize: 11, height: 1.4)),
                      const SizedBox(height: 10),
                      if (Platform.isWindows ||
                          Platform.isMacOS ||
                          Platform.isLinux)
                        OutlinedButton.icon(
                          onPressed: () => _openFolder(
                              '$dir${Platform.pathSeparator}hermes_cards.json'),
                          icon: const Icon(Icons.folder_open, size: 16),
                          label: const Text('打开文件夹'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.mintDark,
                            side: BorderSide(
                                color: AppTheme.mint.withValues(alpha: 0.6)),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                    ],
                  ),
                ),
              ]);
            },
          ),
          _group('关于', [
            _rowItem('版本', '', 'v0.3.0'),
            _rowItem('算法', '', 'FSRS'),
          ]),
        ],
      ),
    );
  }

  // ===== 手动同步 =====

  bool get _isMobile => Platform.isAndroid || Platform.isIOS;

  /// 手机上的文件在应用私有目录里，用户自己取不到，只能走系统分享
  Future<void> _shareFile(String path, String text) async {
    try {
      final r = await Share.shareXFiles([XFile(path)], text: text);
      if (!mounted) return;
      if (r.status == ShareResultStatus.dismissed) {
        _toast('已取消分享，文件仍保存在应用目录里');
      }
    } catch (e) {
      if (!mounted) return;
      _toast('分享失败：$e');
    }
  }

  Future<void> _exportData() async {
    final state = context.read<AppState>();
    try {
      final path = await state.exportPackage();
      if (!mounted) return;
      if (_isMobile) {
        await _shareFile(path, 'Hermes Cards 学习数据包（含卡片与复习进度）');
        return;
      }
      await _showResult(
        title: '已导出学习数据包',
        body: '把这个文件拷到手机或另一台电脑，在「导入学习数据包」里选中它即可。',
        path: path,
      );
    } catch (e) {
      _toast('导出失败：$e');
    }
  }

  Future<void> _exportCsv() async {
    final state = context.read<AppState>();
    try {
      final path = await state.exportCsv('');
      if (!mounted) return;
      if (_isMobile) {
        await _shareFile(path, 'Hermes Cards 卡片导出（CSV）');
        return;
      }
      await _showResult(
        title: '已导出 CSV',
        body: '包含 提问 / 答案 / 语境 / 标签 / 来源 五列，可导入其他卡片软件。',
        path: path,
      );
    } catch (e) {
      _toast('导出失败：$e');
    }
  }

  Future<void> _importData() async {
    final state = context.read<AppState>();
    late final PlatformFile file;
    try {
      final picked = await FilePick.pick(
        extensions: const ['json'],
        dialogTitle: '选择学习数据包',
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
        content = String.fromCharCodes(file.bytes!);
      } else if (file.path != null) {
        content = await File(file.path!).readAsString();
      } else {
        _toast('读取文件失败');
        return;
      }
    } catch (e) {
      _toast('读取文件失败：$e');
      return;
    }

    Map<String, dynamic> data;
    try {
      data = state.parsePackage(content);
    } catch (e) {
      _toast('$e');
      return;
    }

    // 先算差异，让用户确认后再写入——避免误导入覆盖
    final diff = await state.previewPackage(data);
    if (!mounted) return;
    final ok = await _confirmImport(diff);
    if (ok != true) return;

    final applied = await state.importPackage(data);
    if (!mounted) return;
    _toast('同步完成：${applied.summary()}');
  }

  Future<bool?> _confirmImport(SyncDiff diff) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('确认合并',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(diff.summary(),
                style: const TextStyle(fontSize: 13, height: 1.5)),
            const SizedBox(height: 12),
            Text(
              '合并以「卡片」为单位：同一张卡取更新时间较新的一方，'
              '你在本地更新的不会被覆盖。',
              style: TextStyle(fontSize: 11, color: AppTheme.ink3, height: 1.5),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('取消', style: TextStyle(color: AppTheme.ink3)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认合并'),
          ),
        ],
      ),
    );
  }

  Future<void> _showResult(
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
      // 打开文件夹失败不影响导出结果
    }
  }

  // ===== 演示数据 =====

  Future<void> _loadDemo() async {
    final state = context.read<AppState>();
    final n = await state.loadDemoData();
    if (!mounted) return;
    _toast('已载入 $n 张示例卡片，去首页开始学习吧');
  }

  Future<void> _clearDemo() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('清除演示数据',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: const Text('将删除 3 个示例卡包及其复习记录，你自己的卡片不受影响。',
            style: TextStyle(fontSize: 13, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('取消', style: TextStyle(color: AppTheme.ink3)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('清除'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await context.read<AppState>().clearDemoData();
    if (!mounted) return;
    _toast('演示数据已清除');
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Widget _group(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 4),
          child: Text(title,
              style: TextStyle(
                  color: AppTheme.ink3,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.paper,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.line),
          ),
          child: Column(children: children),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _rowItem(String title, String sub, String trailing) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14)),
                if (sub.isNotEmpty)
                  Text(sub,
                      style: TextStyle(color: AppTheme.ink3, fontSize: 11)),
              ],
            ),
          ),
          Text(trailing, style: TextStyle(color: AppTheme.ink3, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _switchItem(String title, String sub, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14)),
                if (sub.isNotEmpty)
                  Text(sub,
                      style: TextStyle(color: AppTheme.ink3, fontSize: 11)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppTheme.mint,
          ),
        ],
      ),
    );
  }

  Widget _sliderItem(String title, String sub, double value, ValueChanged<double> onChanged) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 14)),
                    Text(sub,
                        style: TextStyle(color: AppTheme.ink3, fontSize: 11)),
                  ],
                ),
              ),
              Text('${value.round()}%',
                  style: const TextStyle(
                      color: AppTheme.mintDark, fontWeight: FontWeight.w700)),
            ],
          ),
          Slider(
            value: value,
            min: 70,
            max: 97,
            activeColor: AppTheme.mint,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  /// 数值步进控件（用于 C1/C6/C7 各项参数）
  Widget _stepperItem(
    String title,
    String sub,
    int value,
    int min,
    int max,
    ValueChanged<int> onChanged,
  ) {
    final display = value >= 9999 ? '不限' : '$value';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14)),
                if (sub.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(sub,
                        style:
                            TextStyle(color: AppTheme.ink3, fontSize: 11)),
                  ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.cream,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: value > min ? () => onChanged(value - 1) : null,
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    child: Icon(Icons.remove,
                        size: 16,
                        color: value > min ? AppTheme.ink2 : AppTheme.ink3),
                  ),
                ),
                SizedBox(
                  width: 44,
                  child: Text(display,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700)),
                ),
                InkWell(
                  onTap: value < max ? () => onChanged(value + 1) : null,
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    child: Icon(Icons.add,
                        size: 16,
                        color: value < max ? AppTheme.ink2 : AppTheme.ink3),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _arrowItem(String title, String sub, VoidCallback onTap) {
    return ListTile(
      onTap: onTap,
      title: Text(title, style: const TextStyle(fontSize: 14)),
      subtitle: sub.isNotEmpty
          ? Text(sub, style: TextStyle(color: AppTheme.ink3, fontSize: 11))
          : null,
      trailing: Icon(Icons.chevron_right, color: AppTheme.ink3),
    );
  }
}
