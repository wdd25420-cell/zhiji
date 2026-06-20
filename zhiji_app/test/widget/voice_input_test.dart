import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:zhiji/core/widgets/voice_input_button.dart";

/// T11 验收: Agent 对话语音输入
void main() {
  group("T11 验收: Agent 对话语音输入", () {
    // --- 验收1: 语音按钮独立渲染 ---
    testWidgets("VoiceInputButton 渲染麦克风图标", (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VoiceInputButton(
              onTextReady: (_) {},
              size: 40,
            ),
          ),
        ),
      );
      await tester.pump();

      // 应渲染麦克风图标
      expect(find.byIcon(Icons.mic_none), findsOneWidget);
    });

    // --- 验收2: size 参数生效 ---
    testWidgets("VoiceInputButton 响应 size 参数", (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VoiceInputButton(
              onTextReady: (_) {},
              size: 36,
            ),
          ),
        ),
      );
      await tester.pump();

      // 验证 Container 渲染为 36×36
      final container = tester.widget<Container>(find.byType(Container).first);
      expect(container.constraints, isNotNull);
      final size = tester.getSize(find.byType(Container).first);
      expect(size.width, 36);
      expect(size.height, 36);
    });

    // --- 验收3: onTextReady 回调未触发时状态正确 ---
    testWidgets("VoiceInputButton 初始状态麦克风关闭", (tester) async {
      String? received;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VoiceInputButton(
              onTextReady: (text) => received = text,
              size: 40,
            ),
          ),
        ),
      );
      await tester.pump();

      // 组件应正常渲染
      expect(find.byType(VoiceInputButton), findsOneWidget);
      // 初始状态显示 mic_none（未录音）
      expect(find.byIcon(Icons.mic_none), findsOneWidget);
      // 回调尚未触发
      expect(received, isNull);
    });

    // --- 验收4: ProviderScope 内可正常使用 ---
    testWidgets("VoiceInputButton 在 ProviderScope 中不崩溃", (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: VoiceInputButton(
                onTextReady: _noop,
                size: 40,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(VoiceInputButton), findsOneWidget);
    });
  });
}

void _noop(String _) {}
