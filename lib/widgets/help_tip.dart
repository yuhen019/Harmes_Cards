import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// 悬浮说明的一条字段
class HelpField {
  final String name;
  final String desc;
  final bool required;
  const HelpField(this.name, this.desc, {this.required = false});
}

/// 小问号解释图标
///
/// 桌面端：鼠标悬浮展开说明浮层，移开收起
/// 移动端：点击展开，再点收起
///
/// 说明内容 = 标题 + 若干字段说明 + 可选示例
class HelpTip extends StatefulWidget {
  final String title;
  final List<HelpField> fields;
  final String? example;
  final String? exampleLabel;
  final double width;

  const HelpTip({
    super.key,
    required this.title,
    required this.fields,
    this.example,
    this.exampleLabel,
    this.width = 330,
  });

  @override
  State<HelpTip> createState() => _HelpTipState();
}

class _HelpTipState extends State<HelpTip> {
  final LayerLink _link = LayerLink();
  OverlayEntry? _entry;
  bool _showing = false;
  // 问号图标的屏幕坐标，用于防止浮层撑出屏幕
  double? _iconDx;
  double? _iconDy;

  void _show() {
    if (_showing) return;
    final box = context.findRenderObject();
    if (box is RenderBox) {
      final pos = box.localToGlobal(Offset.zero);
      _iconDx = pos.dx;
      _iconDy = pos.dy;
    }
    _showing = true;
    _entry = OverlayEntry(builder: (_) => _buildBubble());
    Overlay.of(context).insert(_entry!);
  }

  void _hide() {
    _entry?.remove();
    _entry = null;
    _showing = false;
  }

  void _toggle() => _showing ? _hide() : _show();

  @override
  void dispose() {
    _hide();
    super.dispose();
  }

  Widget _buildBubble() {
    final mq = MediaQuery.maybeOf(context);
    final screenW = mq?.size.width ?? 420;
    final screenH = mq?.size.height ?? 800;
    // 手机窄屏：浮层宽度不能超出屏幕，且要避开左右边缘
    final w = widget.width > screenW - 24 ? screenW - 24 : widget.width;
    var dx = -12.0;
    if (_iconDx != null) {
      final overRight = (_iconDx! + dx + w) - (screenW - 8);
      if (overRight > 0) dx -= overRight;
      if (_iconDx! + dx < 8) dx = 8 - _iconDx!;
    }
    // 浮层高度只能估算（未布局前拿不到真实高度）：标题 + 每条字段 + 示例块
    final estH = 60.0 +
        widget.fields.length * 34 +
        (widget.example != null ? 76 : 0) +
        (widget.exampleLabel != null ? 14 : 0);
    var dy = 26.0;
    // 靠近屏幕底部时改向上展开，否则下半截在屏幕外（手机竖屏尤其容易触发）
    if (_iconDy != null && _iconDy! + 20 + dy + estH > screenH - 16) {
      dy = -(estH + 8);
    }
    // 触摸端没有 hover，必须能点空白处收起
    final touch = Platform.isAndroid || Platform.isIOS;

    return Stack(
      children: [
        if (touch)
          Positioned.fill(
            child: GestureDetector(
              onTap: _hide,
              behavior: HitTestBehavior.translucent,
              child: const SizedBox.expand(),
            ),
          ),
        Positioned(
          width: w,
          child: CompositedTransformFollower(
            link: _link,
            showWhenUnlinked: false,
            // 图标左对齐往右展开，略微下移避开图标本身
            offset: Offset(dx, dy),
            child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.paper,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.line),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.10),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(widget.title,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                ...widget.fields.map((f) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 2),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: f.required
                                  ? AppTheme.mintLight
                                  : AppTheme.cream,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              f.name,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: f.required
                                    ? AppTheme.mintDark
                                    : AppTheme.ink3,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(f.desc,
                                style: TextStyle(
                                    fontSize: 11,
                                    height: 1.45,
                                    color: AppTheme.ink2)),
                          ),
                        ],
                      ),
                    )),
                if (widget.example != null) ...[
                  const SizedBox(height: 2),
                  if (widget.exampleLabel != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(widget.exampleLabel!,
                          style: TextStyle(
                              fontSize: 10, color: AppTheme.ink3)),
                    ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7FBF9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.line),
                    ),
                    child: SelectableText(
                      widget.example!,
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.5,
                        color: AppTheme.ink,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _link,
      child: MouseRegion(
        onEnter: (_) => _show(),
        onExit: (_) => _hide(),
        child: GestureDetector(
          onTap: _toggle,
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: AppTheme.cream,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.line2),
            ),
            alignment: Alignment.center,
            child: Icon(Icons.help_outline,
                size: 13, color: AppTheme.ink3),
          ),
        ),
      ),
    );
  }
}
