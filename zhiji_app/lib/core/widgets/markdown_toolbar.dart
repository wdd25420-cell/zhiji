import 'package:flutter/material.dart';

/// Markdown 格式工具栏 — 可复用的编辑辅助工具栏
/// 对传入的 TextEditingController 操作，支持加粗/斜体/标题/列表/引用/代码
class MarkdownToolbar extends StatelessWidget {
  const MarkdownToolbar({super.key, required this.controller, this.onBeforeAction});
  final TextEditingController controller;
  final VoidCallback? onBeforeAction;

  /// 对选中文本包裹前后缀（如 **bold**），无选中则插入占位文本
  void _wrap(String prefix, [String? suffix]) {
    suffix ??= prefix;
    final t = controller.text;
    final sel = controller.selection;
    if (!sel.isValid || sel.start == sel.end) {
      final placeholder = '文本';
      final insert = '$prefix$placeholder$suffix';
      controller.value = TextEditingValue(
        text: t.replaceRange(sel.start, sel.end, insert),
        selection: TextSelection.collapsed(
            offset: sel.start + prefix.length + placeholder.length),
      );
    } else {
      final selected = t.substring(sel.start, sel.end);
      final replaced = '$prefix$selected$suffix';
      controller.value = TextEditingValue(
        text: t.replaceRange(sel.start, sel.end, replaced),
        selection:
            TextSelection(baseOffset: sel.start, extentOffset: sel.start + replaced.length),
      );
    }
  }

  /// 在当前行首加前缀（#、-、>）
  void _prefixLine(String prefix) {
    final t = controller.text;
    final sel = controller.selection;
    final lineStart = t.lastIndexOf('\n', sel.start - 1) + 1;
    controller.value = TextEditingValue(
      text: t.replaceRange(lineStart, lineStart, prefix),
      selection: TextSelection.collapsed(offset: sel.start + prefix.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 0,
      children: [
        _btn(Icons.format_bold, () { onBeforeAction?.call(); _wrap('**'); }),
        _btn(Icons.format_italic, () { onBeforeAction?.call(); _wrap('*'); }),
        _btn(Icons.title, () { onBeforeAction?.call(); _prefixLine('### '); }),
        _btn(Icons.format_list_bulleted, () { onBeforeAction?.call(); _prefixLine('- '); }),
        _btn(Icons.format_quote, () { onBeforeAction?.call(); _prefixLine('> '); }),
        _btn(Icons.code, () { onBeforeAction?.call(); _wrap('`'); }),
      ],
    );
  }

  Widget _btn(IconData icon, VoidCallback onTap) => IconButton(
        icon: Icon(icon, size: 20),
        onPressed: onTap,
        visualDensity: VisualDensity.compact,
        tooltip: _tooltip(icon),
      );

  String _tooltip(IconData icon) => switch (icon) {
        Icons.format_bold => '加粗',
        Icons.format_italic => '斜体',
        Icons.title => '标题',
        Icons.format_list_bulleted => '列表',
        Icons.format_quote => '引用',
        Icons.code => '代码',
        _ => '',
      };
}
