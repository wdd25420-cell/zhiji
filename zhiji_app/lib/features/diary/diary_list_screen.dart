import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/dimensions.dart';
import '../../core/database/app_database.dart';
import '../../core/database/daos/common_daos.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/shimmer_placeholder.dart';
import 'widgets/diary_card.dart';

/// 日记列表
class DiaryListScreen extends ConsumerStatefulWidget {
  const DiaryListScreen({super.key});

  @override
  ConsumerState<DiaryListScreen> createState() => _DiaryListScreenState();
}

class _DiaryListScreenState extends ConsumerState<DiaryListScreen> {
  String _filter = '全部';
  List<DiaryEntry>? _filteredEntries;
  bool _selectMode = false;
  final _selectedIds = <int>{};

  void _enterSelectMode(int id) {
    setState(() {
      _selectMode = true;
      _selectedIds.add(id);
    });
  }

  void _exitSelectMode() {
    setState(() {
      _selectMode = false;
      _selectedIds.clear();
    });
  }

  void _toggleSelect(int id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) _selectMode = false;
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _toggleSelectAll(List<DiaryEntry> entries) {
    setState(() {
      if (_selectedIds.length == entries.length) {
        _selectedIds.clear();
        _selectMode = false;
      } else {
        _selectedIds.addAll(entries.map((e) => e.id));
      }
    });
  }

  Future<void> _deleteSelected() async {
    final ids = _selectedIds.toList();
    if (ids.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除选中的 ${ids.length} 条日记吗？\n此操作不可撤销。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('删除', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final db = await ref.read(databaseProvider.future);
      await db.diaryDao.deleteEntries(ids);
      if (mounted) {
        _exitSelectMode();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已删除 ${ids.length} 条日记')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除失败: $e')),
        );
      }
    }
  }

  Future<void> _onFilterChanged(String label) async {
    setState(() {
      _filter = label;
      _filteredEntries = null;
    });
    if (label == '全部' || label == 'AI 已分析') return;
    try {
      final db = await ref.read(databaseProvider.future);
      final tag = await TagDao(db).getByName(label);
      if (tag != null && mounted) {
        final tagged = await db.diaryDao.listByTag(tag.id);
        if (mounted) setState(() => _filteredEntries = tagged);
      }
    } catch (_) {}
  }

  List<DiaryEntry> _applyFilter(List<DiaryEntry> entries) {
    if (_filter == '全部') return entries;
    if (_filter == 'AI 已分析') return entries.where((e) => e.aiSummary != null).toList();
    if (_filteredEntries != null) {
      final ids = _filteredEntries!.map((e) => e.id).toSet();
      return entries.where((e) => ids.contains(e.id)).toList();
    }
    return entries;
  }

  Widget _buildFilterChips(AppDatabase db) {
    return FutureBuilder<List<Tag>>(
      future: TagDao(db).listAll(),
      builder: (ctx, snap) {
        final tags = (snap.data ?? [])
            .where((t) => t.usageCount > 0)
            .take(8)
            .toList();
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
          child: Row(
            children: [
              _chip('全部'),
              _chip('AI 已分析'),
              ...tags.map((t) => _chip(t.name)),
            ],
          ),
        );
      },
    );
  }

  Widget _chip(String label) {
    final selected = _filter == label;
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => _onFilterChanged(label),
      ),
    );
  }

  List<(String, List<DiaryEntry>)> _groupByDate(List<DiaryEntry> entries) {
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final yesterdayStart = todayStart.subtract(const Duration(days: 1));
    final weekStart = todayStart.subtract(Duration(days: today.weekday - 1));

    final groups = <String, List<DiaryEntry>>{};
    for (final e in entries) {
      final d = e.createdAt;
      final dayStart = DateTime(d.year, d.month, d.day);
      final String key;
      if (dayStart == todayStart) {
        key = '今天';
      } else if (dayStart == yesterdayStart) {
        key = '昨天';
      } else if (dayStart.isAfter(weekStart) || dayStart == weekStart) {
        key = '本周';
      } else {
        key = DateFormat('yyyy年M月').format(d);
      }
      groups.putIfAbsent(key, () => []).add(e);
    }

    final ordered = <(String, List<DiaryEntry>)>[];
    for (final k in ['今天', '昨天', '本周']) {
      if (groups.containsKey(k)) {
        ordered.add((k, groups[k]!));
        groups.remove(k);
      }
    }
    final rest = groups.entries.toList()..sort((a, b) => b.key.compareTo(a.key));
    for (final e in rest) {
      ordered.add((e.key, e.value));
    }
    return ordered;
  }

  @override
  Widget build(BuildContext context) {
    final dbAsync = ref.watch(databaseProvider);

    return Scaffold(
      appBar: AppBar(
        title: _selectMode ? Text('已选 ${_selectedIds.length} 项') : const Text('日记'),
        leading: _selectMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: _exitSelectMode,
              )
            : null,
        actions: _selectMode
            ? [
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: '删除选中',
                  onPressed: _selectedIds.isNotEmpty ? _deleteSelected : null,
                ),
              ]
            : null,
      ),
      body: dbAsync.when(
        data: (db) => _buildList(db),
        loading: () => const ShimmerPlaceholder(height: 200),
        error: (e, _) {
          debugPrint('DiaryList 加载失败: $e');
          return const Center(child: Text('加载失败，请重试'));
        },
      ),
      floatingActionButton: _selectMode
          ? null
          : FloatingActionButton(
              heroTag: 'diary_fab',
              onPressed: () => context.push('/diary/new'),
              child: const Icon(Icons.edit),
            ),
    );
  }

  Widget _buildList(AppDatabase db) {
    return Column(
      children: [
        if (!_selectMode) _buildFilterChips(db),

        Expanded(
          child: StreamBuilder<List<DiaryEntry>>(
            stream: db.diaryDao.watchAll(),
            builder: (ctx, snap) {
              final entries = snap.data ?? [];
              if (snap.hasError) {
                debugPrint('DiaryList error: ${snap.error}');
                return const Center(child: Text('加载失败，请重试'));
              }
              final filtered = _applyFilter(entries);
              if (filtered.isEmpty && !_selectMode) {
                return EmptyState(
                  icon: Icons.book_outlined,
                  title: '还没有日记',
                  subtitle: '点击右下角 + 开始写日记',
                  actionLabel: '立即创建',
                  onAction: () => context.push('/diary/new'),
                );
              }

              // 选择模式下的全选/取消全选栏
              final allSelected = filtered.isNotEmpty && _selectedIds.length == filtered.length;

              return RefreshIndicator(
                onRefresh: _selectMode
                    ? () async {} // 选择模式下禁用下拉刷新
                    : () async => setState(() {}),
                child: Column(
                  children: [
                    if (_selectMode && filtered.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                        child: Row(
                          children: [
                            TextButton.icon(
                              icon: Icon(allSelected ? Icons.deselect : Icons.select_all),
                              label: Text(allSelected ? '取消全选' : '全选'),
                              onPressed: () => _toggleSelectAll(filtered),
                            ),
                          ],
                        ),
                      ),
                    Expanded(
                      child: _buildGroupedList(filtered),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildGroupedList(List<DiaryEntry> filtered) {
    final groups = _groupByDate(filtered);
    final listKey = ValueKey(filtered.length);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: ListView.builder(
        key: listKey,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        itemCount: filtered.length + groups.length,
        itemBuilder: (ctx, i) {
          var offset = 0;
          for (final (title, items) in groups) {
            if (i == offset) {
              return Padding(
                padding: const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.sm),
                child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary,
                    )),
              );
            }
            offset += 1;
            if (i < offset + items.length) {
              final entry = items[i - offset];
              return DiaryCard(
                entry: entry,
                selectMode: _selectMode,
                selected: _selectedIds.contains(entry.id),
                onSelect: () => _toggleSelect(entry.id),
                onTap: () => context.push('/diary/${entry.id}'),
                onLongPress: () => _enterSelectMode(entry.id),
              );
            }
            offset += items.length;
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}
