import 'package:flutter/material.dart';
import '../theme/dimensions.dart';
import 'shimmer_placeholder.dart';

/// 加载指示器
class LoadingIndicator extends StatelessWidget {
  const LoadingIndicator({super.key, this.message});
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ShimmerPlaceholder(height: 40, width: 40, borderRadius: 20),
          if (message != null) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(message!, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}
