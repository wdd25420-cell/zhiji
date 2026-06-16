import 'package:flutter/material.dart';
import '../theme/dimensions.dart';

/// 标签 Chip 组件（简化版）
class TagChip extends StatelessWidget {
  const TagChip({
    super.key,
    required this.label,
    this.onTap,
    this.onDelete,
    this.isAi = false,
    this.selected = false,
  });

  final String label;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final bool isAi;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.xs, bottom: AppSpacing.xs),
      child: InputChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        onPressed: onTap,
        backgroundColor: selected
            ? cs.secondaryContainer
            : isAi
                ? cs.primaryContainer
                : cs.surfaceContainerHigh,
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.full)),
        onDeleted: onDelete,
      ),
    );
  }
}

/// 标签输入框 + Chip 列表
class TagInputField extends StatefulWidget {
  const TagInputField({
    super.key,
    required this.tags,
    required this.onAdd,
    required this.onRemove,
    this.hint = '输入标签，回车添加…',
  });

  final List<String> tags;
  final ValueChanged<String> onAdd;
  final ValueChanged<String> onRemove;
  final String hint;

  @override
  State<TagInputField> createState() => _TagInputFieldState();
}

class _TagInputFieldState extends State<TagInputField> {
  final _controller = TextEditingController();

  void _submit(String text) {
    final trimmed = text.replaceAll(',', '').trim();
    if (trimmed.isNotEmpty && !widget.tags.contains(trimmed)) {
      widget.onAdd(trimmed);
    }
    _controller.clear();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.tags.isNotEmpty)
          Wrap(
            children: widget.tags
                .map((t) => TagChip(label: t, onDelete: () => widget.onRemove(t)))
                .toList(),
          ),
        TextField(
          controller: _controller,
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: Theme.of(context).textTheme.bodyMedium,
            filled: true,
            fillColor: cs.surfaceContainerLow,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              borderSide: BorderSide.none,
            ),
          ),
          onSubmitted: _submit,
          onChanged: (v) {
            if (v.endsWith(',') || v.endsWith('，')) _submit(v);
          },
        ),
      ],
    );
  }
}
