import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/dimensions.dart';
import '../../core/database/app_database.dart';
import '../../core/network/ai_api_service.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/ai_icon.dart';
import '../../core/widgets/shimmer_placeholder.dart';
import 'widgets/emotion_trend_chart.dart';

/// 首页仪表盘
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final dbAsync = ref.watch(databaseProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('知记'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: '搜索',
            onPressed: () => context.push('/search'),
          ),
        ],
      ),
      body: dbAsync.when(
        data: (db) => _buildContent(db, cs),
        loading: () => const ShimmerPlaceholder(height: 200),
        error: (e, _) {
          debugPrint('HomeScreen 加载失败: $e');
          return const Center(child: Text('加载失败，请重试'));
        },
      ),
    );
  }

  Widget _buildContent(AppDatabase db, ColorScheme cs) {
    return RefreshIndicator(
      onRefresh: () async => setState(() {}),
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          // 搜索入口
          Card(
            child: InkWell(
              onTap: () => context.push('/search'),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    Icon(Icons.search, color: cs.onSurfaceVariant),
                    const SizedBox(width: AppSpacing.sm),
                    Text('搜索日记和知识…',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // 统计卡片 2×2
          _StatRow(db: db, cs: cs),
          const SizedBox(height: AppSpacing.lg),

          // AI 洞察（可点击生成每周回顾）
          Card(
            color: cs.primaryContainer,
            child: InkWell(
              onTap: () => _showWeeklyReview(context, db),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Row(
                  children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                          color: cs.primary, borderRadius: BorderRadius.circular(AppRadius.sm)),
                      child: const AiIcon(size: 18),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('DeepSeek 洞察', style: Theme.of(context).textTheme.titleSmall),
                          const SizedBox(height: AppSpacing.xs),
                          Text('点击生成你的本周回顾报告',
                              style: Theme.of(context).textTheme.bodyMedium),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: cs.onPrimaryContainer),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // AI 智能问答入口
          Card(
            child: InkWell(
              onTap: () => context.go('/chat'),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Row(
                  children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                          color: cs.secondaryContainer, borderRadius: BorderRadius.circular(AppRadius.sm)),
                      child: const AiIcon(size: 18),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('AI 问答', style: Theme.of(context).textTheme.titleSmall),
                          const SizedBox(height: AppSpacing.xs),
                          Text('基于你的知识库自由提问',
                              style: Theme.of(context).textTheme.bodyMedium),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // 情绪趋势图
          const EmotionTrendChart(),
          const SizedBox(height: AppSpacing.lg),

          // 写作热力图
          const _HeatmapSection(),
          const SizedBox(height: AppSpacing.xl),

          // 最近更新（日记 + 知识混合）
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('最近更新', style: Theme.of(context).textTheme.titleLarge),
              TextButton(onPressed: () => context.push('/diary'), child: const Text('查看全部')),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _RecentCombined(db: db),
        ],
      ),
    );
  }

  void _showWeeklyReview(BuildContext context, AppDatabase db) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _WeeklyReviewSheet(db: db),
    );
  }
}

// 每周回顾弹窗
class _WeeklyReviewSheet extends ConsumerStatefulWidget {
  const _WeeklyReviewSheet({required this.db});
  final AppDatabase db;

  @override
  ConsumerState<_WeeklyReviewSheet> createState() => _WeeklyReviewSheetState();
}

class _WeeklyReviewSheetState extends ConsumerState<_WeeklyReviewSheet> {
  String? _review;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final diaries = await widget.db.diaryDao.watchAll().first;
    final contents = diaries
        .where((d) => d.createdAt.isAfter(DateTime.now().subtract(const Duration(days: 7))))
        .map((d) => '[${d.emotion ?? ''}] ${d.title}: ${d.bodyMarkdown}')
        .toList();
    if (contents.isEmpty) {
      setState(() { _review = '本周还没有日记记录。开始写点什么吧！'; _loading = false; });
      return;
    }
    final result = await AIService.weeklyReview(contents);
    if (mounted) {
      setState(() {
        _review = result ?? 'AI 服务暂时不可用，请检查 API Key 和网络。';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.3,
      expand: false,
      builder: (ctx, scrollCtrl) => Container(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            )),
            const SizedBox(height: AppSpacing.lg),
            Row(children: [
              const AiIcon(size: 24),
              const SizedBox(width: AppSpacing.sm),
              Text('本周回顾', style: Theme.of(context).textTheme.titleLarge),
            ]),
            const Divider(height: AppSpacing.xl),
            Expanded(
              child: _loading
                  ? const ShimmerPlaceholder(height: 160)
                  : SingleChildScrollView(
                      controller: scrollCtrl,
                      child: Text(_review ?? '', style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.7)),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// 统计卡片行（2×2 网格）
// ============================================================
class _StatRow extends StatelessWidget {
  const _StatRow({required this.db, required this.cs});
  final AppDatabase db;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 大主卡：连续记录天数
        _StreakCard(db: db, cs: cs),
        const SizedBox(height: AppSpacing.sm),
        // 3 小卡横排
        Row(children: [
          Expanded(child: _MiniStatCard(label: '日记', future: db.diaryDao.countAll(), cs: cs)),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: _MiniStatCard(label: '知识', future: db.knowledgeDao.countAll(), cs: cs)),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: _MiniStatCard(label: '字数', future: db.diaryDao.wordCountThisWeek(), cs: cs)),
        ]),
      ],
    );
  }
}

class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.db, required this.cs});
  final AppDatabase db;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(
      future: db.diaryDao.currentStreak(),
      builder: (ctx, snap) => Card(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [cs.primary, cs.tertiary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Text('🔥', style: TextStyle(fontSize: 28)),
                const SizedBox(width: AppSpacing.sm),
                Text('${snap.data ?? 0}',
                  style: TextStyle(fontSize: 40, fontWeight: FontWeight.w800, color: cs.onPrimary)),
              ]),
              const SizedBox(height: AppSpacing.xs),
              Text('连续记录天数', style: TextStyle(color: cs.onPrimary.withValues(alpha: 0.8))),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniStatCard extends StatelessWidget {
  const _MiniStatCard({required this.label, required this.future, required this.cs});
  final String label;
  final Future<int> future;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(
      future: future,
      builder: (ctx, snap) => Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: [
              Text('${snap.data ?? '—'}',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: AppSpacing.xs),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// 写作热力图
// ============================================================
class _HeatmapSection extends ConsumerWidget {
  const _HeatmapSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dbAsync = ref.watch(databaseProvider);
    final cs = Theme.of(context).colorScheme;

    return dbAsync.when(
      data: (db) => FutureBuilder<Map<String, int>>(
        future: db.diaryDao.countByDay(28),
        builder: (ctx, snap) {
          final data = snap.data ?? {};
          return SizedBox(
            height: 100,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('写作热力图', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                Expanded(
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 7,
                      mainAxisSpacing: 3,
                      crossAxisSpacing: 3,
                      childAspectRatio: 1,
                    ),
                    itemCount: 28,
                    itemBuilder: (ctx, i) {
                      final day = DateTime.now().subtract(Duration(days: 27 - i));
                      final key =
                          '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
                      final count = data[key] ?? 0;
                      final opacity =
                          count == 0 ? 0.1 : count == 1 ? 0.35 : count == 2 ? 0.6 : 1.0;
                      return Container(
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: opacity),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
      loading: () => const ShimmerPlaceholder(height: 100),
      error: (_, stack) => const SizedBox.shrink(),
    );
  }
}

// ============================================================
// 最近更新（日记 + 知识混合）
// ============================================================
class _RecentCombined extends StatelessWidget {
  const _RecentCombined({required this.db});
  final AppDatabase db;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: _loadCombined(),
      builder: (ctx, snap) {
        final items = snap.data ?? [];
        if (items.isEmpty) {
          return const EmptyState(icon: Icons.book_outlined, title: '还没有内容', subtitle: '点击 + 开始记录');
        }
        return Column(
          children: items.take(5).map((item) {
            if (item is DiaryEntry) {
              return _CombinedCard(
                title: item.title,
                preview: item.bodyMarkdown,
                timeLabel: _fmt(item.createdAt),
                badge: '日记',
                onTap: () => context.push('/diary/${item.id}'),
              );
            } else {
              final k = item as KnowledgeEntry;
              return _CombinedCard(
                title: k.title,
                preview: k.contentMarkdown,
                timeLabel: _fmt(k.createdAt),
                badge: '知识',
                onTap: () => context.push('/knowledge/${k.id}'),
              );
            }
          }).toList(),
        );
      },
    );
  }

  Future<List<dynamic>> _loadCombined() async {
    final diaries = await db.diaryDao.watchAll().first;
    final knowledges = await db.knowledgeDao.listRecent(5);
    final combined = <dynamic>[...diaries, ...knowledges];
    combined.sort((a, b) {
      final aTime = a is DiaryEntry ? a.createdAt : (a as KnowledgeEntry).createdAt;
      final bTime = b is DiaryEntry ? b.createdAt : (b as KnowledgeEntry).createdAt;
      return bTime.compareTo(aTime);
    });
    return combined.take(5).toList();
  }

  static String _fmt(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inHours < 24) return '${diff.inHours} 小时前';
    if (diff.inDays < 7) return '${diff.inDays} 天前';
    return '${dt.month}/${dt.day}';
  }
}

class _CombinedCard extends StatelessWidget {
  const _CombinedCard({required this.title, required this.preview, required this.timeLabel, required this.badge, this.onTap});
  final String title;
  final String preview;
  final String timeLabel;
  final String badge;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
                  decoration: BoxDecoration(
                      color: badge == '日记' ? cs.secondaryContainer : cs.tertiaryContainer,
                      borderRadius: BorderRadius.circular(AppRadius.xs)),
                  child: Text(badge,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: badge == '日记' ? cs.onSecondaryContainer : cs.onTertiaryContainer)),
                ),
                const Spacer(),
                Text(timeLabel, style: Theme.of(context).textTheme.labelSmall),
              ]),
              const SizedBox(height: AppSpacing.sm),
              Text(title, style: Theme.of(context).textTheme.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: AppSpacing.xs),
              Text(preview, style: Theme.of(context).textTheme.bodyMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}
