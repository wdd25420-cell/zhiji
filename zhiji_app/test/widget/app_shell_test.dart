import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:zhiji/main.dart";

/// T-UI-1: 底部 4 Tab 导航（首页首屏版）
void main() {
  group("T-UI-1 AppShell 底部 Tab 结构", () {
    testWidgets("AppShell 渲染底部 NavigationBar（4 Tab）", (tester) async {
      await tester.pumpWidget(const ProviderScope(child: ZhijiApp()));
      await tester.pump();

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.text("首页"), findsOneWidget);
      expect(find.text("日记"), findsOneWidget);
      expect(find.text("知识库"), findsOneWidget);
      expect(find.text("AI 对话"), findsOneWidget);
    });

    testWidgets("首页是默认首屏", (tester) async {
      await tester.pumpWidget(const ProviderScope(child: ZhijiApp()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text("知记"), findsOneWidget);
    });

    testWidgets("点击各 Tab 不崩溃", (tester) async {
      await tester.pumpWidget(const ProviderScope(child: ZhijiApp()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final tabs = ["日记", "知识库", "AI 对话", "首页"];
      for (final tab in tabs) {
        await tester.tap(find.text(tab));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.byType(Scaffold), findsWidgets);
      }
    });
  });

  group("T-UI-1 路由跳转", () {
    testWidgets("App 启动不崩溃", (tester) async {
      await tester.pumpWidget(const ProviderScope(child: ZhijiApp()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(Scaffold), findsWidgets);
    });
  });
}
