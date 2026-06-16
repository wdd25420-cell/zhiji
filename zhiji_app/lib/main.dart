import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/providers/theme_provider.dart';

void main() {
  // 全局未捕获异常兜底
  PlatformDispatcher.instance.onError = (exception, stack) {
    debugPrint('FATAL: $exception\n$stack');
    return true; // 阻止崩溃，继续运行
  };

  runApp(const ProviderScope(child: ZhijiApp()));
}

class ZhijiApp extends ConsumerWidget {
  const ZhijiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      title: '知记',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: appRouter,
    );
  }
}
