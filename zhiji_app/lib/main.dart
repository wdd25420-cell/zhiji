import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/providers/theme_provider.dart';
import 'core/database/app_database.dart';
import 'core/database/daos/common_daos.dart';
import 'core/network/dio_client.dart';
import 'features/lock/app_lock_screen.dart';

/// 启动时从 secure storage 加载 API Key 并注入 Dio
final apiKeyInitProvider = FutureProvider<void>((ref) async {
  final db = await ref.read(databaseProvider.future);
  final key = await SettingsDao(db).getApiKey();
  if (key != null && key.isNotEmpty) {
    AppDio.setApiKey(key);
  }
});

void main() {
  PlatformDispatcher.instance.onError = (exception, stack) {
    debugPrint('FATAL: $exception\n$stack');
    return true;
  };

  runApp(const ProviderScope(child: ZhijiApp()));
}

class ZhijiApp extends ConsumerStatefulWidget {
  const ZhijiApp({super.key});

  @override
  ConsumerState<ZhijiApp> createState() => _ZhijiAppState();
}

class _ZhijiAppState extends ConsumerState<ZhijiApp>
    with WidgetsBindingObserver {
  bool _lockChecked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _lockChecked) {
      _checkLock();
    }
  }

  Future<void> _checkLock() async {
    final db = await ref.read(databaseProvider.future);
    final hash = await SettingsDao(db).getValue("lock_pin_hash");
    if (hash == null || hash.isEmpty) return;
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AppLockScreen(db: db)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    ref.watch(apiKeyInitProvider);

    if (!_lockChecked) {
      _lockChecked = true;
      Future.microtask(() => _checkLock());
    }

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
