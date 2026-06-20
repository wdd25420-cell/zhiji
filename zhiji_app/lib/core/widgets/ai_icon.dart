import "package:flutter/material.dart";

/// 统一的 AI 功能图标 — 紫蓝渐变 (#7C3AED → #3B82F6)
class AiIcon extends StatelessWidget {
  const AiIcon({super.key, this.size = 24, this.withBackground = true});

  final double size;
  final bool withBackground;

  static const _gradient = LinearGradient(
    colors: [Color(0xFF7C3AED), Color(0xFF3B82F6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  @override
  Widget build(BuildContext context) {
    if (!withBackground) {
      return ShaderMask(
        shaderCallback: (bounds) => _gradient.createShader(bounds),
        child: Icon(Icons.auto_awesome, size: size, color: Colors.white),
      );
    }
    return Container(
      width: size + 8,
      height: size + 8,
      decoration: BoxDecoration(
        gradient: _gradient,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(Icons.auto_awesome, size: size, color: Colors.white),
    );
  }
}
