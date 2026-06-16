import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zhiji/main.dart';

void main() {
  testWidgets('App 启动 smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: ZhijiApp()));
    expect(find.byType(Scaffold), findsWidgets);
  });
}
