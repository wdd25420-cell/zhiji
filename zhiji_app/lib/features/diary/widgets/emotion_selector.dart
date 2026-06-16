import 'package:flutter/material.dart';
import '../../../core/models/emotion.dart';
import '../../../core/theme/dimensions.dart';

class EmotionSelector extends StatelessWidget {
  const EmotionSelector({super.key, required this.selected, required this.onChanged});
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: Emotion.values.map((e) {
          final isSelected = selected == e.name;
          return GestureDetector(
            onTap: () => onChanged(isSelected ? '' : e.name),
            child: Container(
              margin: const EdgeInsets.only(right: AppSpacing.xs),
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: isSelected ? cs.primaryContainer : cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Column(
                children: [
                  Text(e.emoji, style: const TextStyle(fontSize: 24)),
                  const SizedBox(height: 4),
                  Text(e.label, style: const TextStyle(fontSize: 10)),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
