import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../widgets/app_shell.dart';
import '../../features/home/home_screen.dart';
import '../../features/diary/diary_list_screen.dart';
import '../../features/diary/diary_editor_screen.dart';
import '../../features/knowledge/knowledge_browse_screen.dart';
import '../../features/knowledge/knowledge_editor_screen.dart';
import '../../features/knowledge/knowledge_detail_screen.dart';
import '../../features/search/search_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/chat/chat_screen.dart';

/// 全屏路由统一转场：fade + 8dp 上滑
CustomTransitionPage<T> _slideUpPage<T>({
  required BuildContext context,
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.05),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
          child: child,
        ),
      );
    },
    transitionDuration: const Duration(milliseconds: 250),
  );
}

/// GoRouter 完整路由配置
final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    // === 底部 Tab 导航壳 ===
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          AppShell(navigationShell: navigationShell),
      branches: [
        // Tab 1: 首页
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => const HomeScreen(),
            ),
          ],
        ),
        // Tab 2: 日记
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/diary',
              builder: (context, state) => const DiaryListScreen(),
            ),
          ],
        ),
        // Tab 3: 知识库
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/knowledge',
              builder: (context, state) => const KnowledgeBrowseScreen(),
            ),
          ],
        ),
        // Tab 4: 设置
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/settings',
              builder: (context, state) => const SettingsScreen(),
            ),
          ],
        ),
      ],
    ),

    // === 全屏路由（不在 Tab 内，统一 fade+slide 转场）===
    GoRoute(
      path: '/diary/new',
      pageBuilder: (context, state) => _slideUpPage(
        context: context,
        state: state,
        child: const DiaryEditorScreen(),
      ),
    ),
    GoRoute(
      path: '/diary/:id',
      pageBuilder: (context, state) {
        final id = int.tryParse(state.pathParameters['id'] ?? '');
        return _slideUpPage(
          context: context,
          state: state,
          child: id != null
              ? DiaryEditorScreen(entryId: id)
              : const Scaffold(body: Center(child: Text('无效ID'))),
        );
      },
    ),
    GoRoute(
      path: '/knowledge/new',
      pageBuilder: (context, state) => _slideUpPage(
        context: context,
        state: state,
        child: const KnowledgeEditorScreen(),
      ),
    ),
    GoRoute(
      path: '/knowledge/:id',
      pageBuilder: (context, state) {
        final id = int.tryParse(state.pathParameters['id'] ?? '');
        return _slideUpPage(
          context: context,
          state: state,
          child: id != null
              ? KnowledgeDetailScreen(entryId: id)
              : const Scaffold(body: Center(child: Text('无效ID'))),
        );
      },
    ),
    GoRoute(
      path: '/knowledge/:id/edit',
      pageBuilder: (context, state) {
        final id = int.tryParse(state.pathParameters['id'] ?? '');
        return _slideUpPage(
          context: context,
          state: state,
          child: id != null
              ? KnowledgeEditorScreen(entryId: id)
              : const Scaffold(body: Center(child: Text('无效ID'))),
        );
      },
    ),
    GoRoute(
      path: '/search',
      pageBuilder: (context, state) {
        final query = state.uri.queryParameters['q'] ?? '';
        return _slideUpPage(
          context: context,
          state: state,
          child: SearchScreen(initialQuery: query),
        );
      },
    ),
    GoRoute(
      path: '/chat',
      pageBuilder: (context, state) => _slideUpPage(
        context: context,
        state: state,
        child: const ChatScreen(),
      ),
    ),
  ],

  errorBuilder: (context, state) => Scaffold(
        appBar: AppBar(title: const Text('页面不存在')),
        body: const Center(child: Text('404 — 页面未找到')),
      ),
);
