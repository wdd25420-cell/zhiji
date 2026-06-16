import 'package:flutter/material.dart';
import '../../../core/theme/dimensions.dart';
import '../../../core/database/app_database.dart';
import '../../../core/models/emotion.dart';

class DiaryCard extends StatelessWidget {
  const DiaryCard({super.key, required this.entry, this.onTap, this.onLongPress, this.selected = false, this.selectMode = false, this.onSelect});
  final DiaryEntry entry;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool selected;
  final bool selectMode;
  final VoidCallback? onSelect;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      color: selected ? cs.primaryContainer.withValues(alpha: 0.3) : null,
      child: InkWell(
        onTap: selectMode ? onSelect : onTap,
        onLongPress: selectMode ? null : onLongPress,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (selectMode) ...[
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.md, top: 2),
                  child: Icon(
                    selected ? Icons.check_box : Icons.check_box_outline_blank,
                    color: selected ? cs.primary : cs.onSurfaceVariant,
                  ),
                ),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
                        decoration: BoxDecoration(
                          color: cs.secondaryContainer,
                          borderRadius: BorderRadius.circular(AppRadius.xs),
                        ),
                        child: Text('日记',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(color: cs.onSecondaryContainer)),
                      ),
                      if (entry.emotion != null) ...[
                        const SizedBox(width: AppSpacing.sm),
                        Text(_emotionLabel(entry.emotion!), style: const TextStyle(fontSize: 16)),
                      ],
                      const Spacer(),
                      if (entry.filePaths != null && entry.filePaths!.isNotEmpty) ...[
                        Icon(Icons.attach_file, size: 14, color: cs.onSurfaceVariant),
                        const SizedBox(width: 2),
                      ],
                      Text(_formatDate(entry.createdAt),
                          style: Theme.of(context).textTheme.labelSmall),
                    ]),
                    const SizedBox(height: AppSpacing.sm),
                    Text(entry.title,
                        style: Theme.of(context).textTheme.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    if (entry.bodyMarkdown.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(entry.bodyMarkdown,
                          style: Theme.of(context).textTheme.bodyMedium,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                    ],
                    if (entry.aiSummary != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Row(children: [
                        Icon(Icons.auto_awesome, size: 14, color: cs.primary),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(entry.aiSummary!,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: cs.primary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                      ]),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _emotionLabel(String emotionName) {
    final emotion = Emotion.values.firstWhere(
      (e) => e.name == emotionName,
      orElse: () => Emotion.reflective,
    );
    return emotion.emoji;
  }

  String _formatDate(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inHours < 1) return '刚刚';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    if (diff.inDays < 7) return '${diff.inDays}天前';
    return '${dt.month}月${dt.day}日';
  }
}
