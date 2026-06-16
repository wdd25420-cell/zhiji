import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/dimensions.dart';
import '../../core/database/app_database.dart';
import '../../core/widgets/empty_state.dart';
import 'widgets/knowledge_card.dart';
import 'widgets/category_filter_chips.dart';

/// 知识库浏览
class KnowledgeBrowseScreen extends ConsumerStatefulWidget {
  const KnowledgeBrowseScreen({super.key, this.categoryId});
  final int? categoryId;

  @override
  ConsumerState<KnowledgeBrowseScreen> createState() => _KnowledgeBrowseScreenState();
}

class _KnowledgeBrowseScreenState extends ConsumerState<KnowledgeBrowseScreen> {
  int? _selectedCat;
  bool _selectMode = false;
  final _selectedIds = <int>{};

  @override
  void initState() {
    super.initState();
    _selectedCat = widget.categoryId;
  }

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

  void _toggleSelectAll(List<KnowledgeEntry> entries) {
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
        content: Text('确定要删除选中的 ${ids.length} 条知识条目吗？\n此操作不可撤销。'),
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
      await db.knowledgeDao.deleteEntries(ids);
      if (mounted) {
        _exitSelectMode();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已删除 ${ids.length} 条知识')),
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

  @override
  Widget build(BuildContext context) {
    final dbAsync = ref.watch(databaseProvider);

    return Scaffold(
      appBar: AppBar(
        title: _selectMode ? Text('已选 ${_selectedIds.length} 项') : const Text('知识库'),
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
        data: (db) => _buildContent(db),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) {
          debugPrint('KnowledgeBrowse 加载失败: $e');
          return const Center(child: Text('加载失败，请重试'));
        },
      ),
      floatingActionButton: _selectMode
          ? null
          : FloatingActionButton(
              heroTag: 'knowledge_fab',
              onPressed: () => context.push('/knowledge/new'),
              child: const Icon(Icons.post_add),
            ),
    );
  }

  Widget _buildContent(AppDatabase db) {
    return Column(
      children: [
        if (!_selectMode) ...[
          // 搜索入口
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Card(
              child: InkWell(
                onTap: () => context.push('/search'),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(children: [
                    Icon(Icons.search, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    const SizedBox(width: AppSpacing.sm),
                    Text('搜索知识条目…',
                        style: Theme.of(context)
                            .textTheme
                            .bodyLarge
                            ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  ]),
                ),
              ),
            ),
          ),

          // 分类筛选
          CategoryFilterChips(
            db: db,
            selected: _selectedCat,
            onChanged: (catId) => setState(() => _selectedCat = catId),
          ),
          const Divider(height: 1),
        ],

        // 列表
        Expanded(
          child: _selectedCat != null
              ? StreamBuilder<List<KnowledgeEntry>>(
                  stream: db.knowledgeDao.watchByCategory(_selectedCat!),
                  builder: (ctx, snap) {
                    if (snap.hasError) {
                      debugPrint('KnowledgeBrowse error: ${snap.error}');
                      return const Center(child: Text('加载失败，请重试'));
                    }
                    return _buildList(snap.data ?? []);
                  },
                )
              : StreamBuilder<List<KnowledgeEntry>>(
                  stream: db.knowledgeDao.watchAll(),
                  builder: (ctx, snap) {
                    if (snap.hasError) {
                      debugPrint('KnowledgeBrowse error: ${snap.error}');
                      return const Center(child: Text('加载失败，请重试'));
                    }
                    return _buildList(snap.data ?? []);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildList(List<KnowledgeEntry> entries) {
    if (entries.isEmpty && !_selectMode) {
      return EmptyState(
        icon: Icons.folder_outlined,
        title: '暂无知识条目',
        subtitle: '点击 + 添加第一条知识',
        actionLabel: '立即创建',
        onAction: () => context.push('/knowledge/new'),
      );
    }

    final allSelected = entries.isNotEmpty && _selectedIds.length == entries.length;

    return RefreshIndicator(
      onRefresh: _selectMode ? () async {} : () async => setState(() {}),
      child: Column(
        children: [
          if (_selectMode && entries.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
              child: Row(
                children: [
                  TextButton.icon(
                    icon: Icon(allSelected ? Icons.deselect : Icons.select_all),
                    label: Text(allSelected ? '取消全选' : '全选'),
                    onPressed: () => _toggleSelectAll(entries),
                  ),
                ],
              ),
            ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              itemCount: entries.length,
              itemBuilder: (ctx, i) => KnowledgeCard(
                entry: entries[i],
                selectMode: _selectMode,
                selected: _selectedIds.contains(entries[i].id),
                onSelect: () => _toggleSelect(entries[i].id),
                onTap: () => context.push('/knowledge/${entries[i].id}'),
                onLongPress: () => _enterSelectMode(entries[i].id),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
