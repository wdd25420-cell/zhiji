import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zhiji/main.dart';
import 'package:zhiji/core/widgets/empty_state.dart';
import 'package:zhiji/core/widgets/loading_indicator.dart';
import 'package:zhiji/core/widgets/shimmer_placeholder.dart';
import 'package:zhiji/core/widgets/undo_manager.dart';

void main() {
  group('Widget 渲染', () {
    testWidgets('App 启动并渲染首页仪表盘', (tester) async {
      await tester.pumpWidget(const ProviderScope(child: ZhijiApp()));
      await tester.pump();

      // 底部 4 Tab NavigationBar
      expect(find.byType(NavigationBar), findsOneWidget);
      // 首页标题
      expect(find.text("知记"), findsOneWidget);
    });

    testWidgets('切换到 AI 对话 Tab 显示输入区域', (tester) async {
      await tester.pumpWidget(const ProviderScope(child: ZhijiApp()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // 点击 "AI 对话" Tab 切换
      await tester.tap(find.text("AI 对话"));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Agent 对话输入框应存在
      expect(find.text('说点什么…'), findsOneWidget);
    });
  });

  group('共享组件独立渲染', () {
    testWidgets('EmptyState 渲染引导文案', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: EmptyState(
            icon: Icons.book_outlined,
            title: '还没有日记',
            subtitle: '点击右下角开始写日记',
          ),
        ),
      ));
      expect(find.text('还没有日记'), findsOneWidget);
      expect(find.text('点击右下角开始写日记'), findsOneWidget);
    });

    testWidgets('EmptyState 含 action 按钮', (tester) async {
      var tapped = false;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: EmptyState(
            icon: Icons.book_outlined,
            title: '测试标题',
            subtitle: '测试副标题',
            actionLabel: '立即创建',
            onAction: () => tapped = true,
          ),
        ),
      ));
      expect(find.text('立即创建'), findsOneWidget);
      await tester.tap(find.text('立即创建'));
      expect(tapped, isTrue);
    });

    testWidgets('LoadingIndicator 渲染', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: LoadingIndicator()),
      ));
      expect(find.byType(ShimmerPlaceholder), findsOneWidget);
    });
  });

  group('UndoManager 逻辑', () {
    test('push 两次后 canUndo 为 true', () {
      final um = UndoManager();
      um.push('v1', const TextSelection.collapsed(offset: 2));
      um.push('v2', const TextSelection.collapsed(offset: 2));
      expect(um.canUndo, isTrue);
    });

    test('初始状态 canUndo 为 false', () {
      final um = UndoManager();
      expect(um.canUndo, isFalse);
      expect(um.canRedo, isFalse);
    });

    test('undo 后 canRedo 为 true', () {
      final um = UndoManager();
      um.push('v1', const TextSelection.collapsed(offset: 2));
      um.push('v2', const TextSelection.collapsed(offset: 2));
      final snap = um.undo();
      expect(snap, isNotNull);
      expect(um.canRedo, isTrue);
    });

    test('redo 后 canRedo 为 false', () {
      final um = UndoManager();
      um.push('v1', const TextSelection.collapsed(offset: 2));
      um.push('v2', const TextSelection.collapsed(offset: 2));
      um.undo();
      final snap = um.redo();
      expect(snap, isNotNull);
      expect(um.canRedo, isFalse);
    });

    test('连续相同内容不重复入栈', () {
      final um = UndoManager();
      um.push('same', const TextSelection.collapsed(offset: 4));
      um.push('same', const TextSelection.collapsed(offset: 4));
      um.undo();
      expect(um.canUndo, isFalse);
    });

    test('clear 清空历史', () {
      final um = UndoManager();
      um.push('v1', const TextSelection.collapsed(offset: 2));
      um.push('v2', const TextSelection.collapsed(offset: 2));
      um.clear();
      expect(um.canUndo, isFalse);
      expect(um.canRedo, isFalse);
    });
  });
}
