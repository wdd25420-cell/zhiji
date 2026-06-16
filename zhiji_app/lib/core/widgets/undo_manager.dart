import 'dart:async';
import 'package:flutter/material.dart';

/// 单个历史快照：文本内容 + 光标位置
class EditorSnapshot {
  final String text;
  final int selectionStart;
  final int selectionEnd;
  const EditorSnapshot(this.text, this.selectionStart, this.selectionEnd);
}

/// 文本撤销/重做管理器
///
/// 用法：
/// ```dart
/// final undo = UndoManager();
/// // 每次重大操作前推入快照
/// undo.push(controller.text, controller.selection);
/// // 撤销
/// undo.undo()?.applyTo(controller);
/// // 重做
/// undo.redo()?.applyTo(controller);
/// ```
class UndoManager extends ChangeNotifier {
  final List<EditorSnapshot> _history = [];
  int _index = -1;
  final int _maxSize;
  String? _lastPushedText;

  UndoManager({int maxSize = 50}) : _maxSize = maxSize;

  /// 推入当前状态到历史
  void push(String text, TextSelection selection) {
    final start = selection.isValid ? selection.start : 0;
    final end = selection.isValid ? selection.end : 0;
    // 去重：连续相同内容不重复入栈
    if (_lastPushedText == text) return;
    _lastPushedText = text;
    // 丢弃当前索引之后的历史（新的分支）
    if (_index < _history.length - 1) {
      _history.removeRange(_index + 1, _history.length);
    }
    _history.add(EditorSnapshot(text, start, end));
    // 超出上限删最旧
    if (_history.length > _maxSize) {
      _history.removeAt(0);
    }
    _index = _history.length - 1;
    notifyListeners();
  }

  /// 撤销，返回上一个快照（不修改 controller）
  EditorSnapshot? undo() {
    if (!canUndo) return null;
    _index--;
    notifyListeners();
    return _history[_index];
  }

  /// 重做，返回下一个快照
  EditorSnapshot? redo() {
    if (!canRedo) return null;
    _index++;
    notifyListeners();
    return _history[_index];
  }

  bool get canUndo => _index > 0;
  bool get canRedo => _index < _history.length - 1;

  /// 清空历史
  void clear() {
    _history.clear();
    _index = -1;
    _lastPushedText = null;
    notifyListeners();
  }
}

/// 将快照应用到 TextEditingController
extension _Apply on EditorSnapshot {
  void applyTo(TextEditingController controller) {
    controller.value = TextEditingValue(
      text: text,
      selection: TextSelection(
        baseOffset: selectionStart.clamp(0, text.length),
        extentOffset: selectionEnd.clamp(0, text.length),
      ),
    );
  }
}

/// 撤销/重做按钮对，可嵌入工具栏
class UndoRedoButtons extends StatelessWidget {
  const UndoRedoButtons({
    super.key,
    required this.undoManager,
    required this.controller,
  });
  final UndoManager undoManager;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: undoManager,
      builder: (context, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.undo, size: 20),
            onPressed: undoManager.canUndo
                ? () {
                    final snap = undoManager.undo();
                    if (snap != null) snap.applyTo(controller);
                  }
                : null,
            visualDensity: VisualDensity.compact,
            tooltip: '撤销',
          ),
          IconButton(
            icon: const Icon(Icons.redo, size: 20),
            onPressed: undoManager.canRedo
                ? () {
                    final snap = undoManager.redo();
                    if (snap != null) snap.applyTo(controller);
                  }
                : null,
            visualDensity: VisualDensity.compact,
            tooltip: '重做',
          ),
        ],
      ),
    );
  }
}

/// 文本变化定时快照助手
/// 在用户停止输入 ~1.5 秒后自动推入快照
class TypingSnapshotTimer {
  final UndoManager undoManager;
  final TextEditingController controller;
  Timer? _timer;
  String _lastSnapshot = '';

  TypingSnapshotTimer({
    required this.undoManager,
    required this.controller,
  }) {
    _lastSnapshot = controller.text;
  }

  /// 在 controller.addListener 回调中调用
  void onTextChanged() {
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 1500), () {
      final current = controller.text;
      if (current != _lastSnapshot) {
        _lastSnapshot = current;
        undoManager.push(current, controller.selection);
      }
    });
  }

  /// 手动触发快照（操作前调用）
  void snapshotNow() {
    _timer?.cancel();
    final current = controller.text;
    if (current != _lastSnapshot) {
      _lastSnapshot = current;
      undoManager.push(current, controller.selection);
    }
  }

  void dispose() {
    _timer?.cancel();
  }
}
