import "package:flutter/material.dart";

/// 骨架屏占位组件 — 替代所有 CircularProgressIndicator
class ShimmerPlaceholder extends StatefulWidget {
  const ShimmerPlaceholder({
    super.key,
    this.width,
    this.height = 100,
    this.borderRadius = 12,
  });

  final double? width;
  final double height;
  final double borderRadius;

  @override
  State<ShimmerPlaceholder> createState() => _ShimmerPlaceholderState();
}

class _ShimmerPlaceholderState extends State<ShimmerPlaceholder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final t = _ctrl.value;
        final opacity = 0.3 + 0.3 * (t <= 0.5 ? t * 2 : (1 - t) * 2);
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: cs.onSurface.withValues(alpha: opacity),
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
        );
      },
    );
  }
}
