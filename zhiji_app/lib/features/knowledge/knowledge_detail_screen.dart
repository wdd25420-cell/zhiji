import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/dimensions.dart';
import '../../core/database/app_database.dart';
import '../../core/database/daos/common_daos.dart';
import '../../core/utils/file_attachment_manager.dart';
import '../../core/widgets/attachment_list.dart';
import '../../core/widgets/shimmer_placeholder.dart';

/// 知识详情
class KnowledgeDetailScreen extends ConsumerStatefulWidget {
  const KnowledgeDetailScreen({super.key, required this.entryId});
  final int entryId;

  @override
  ConsumerState<KnowledgeDetailScreen> createState() => _KnowledgeDetailScreenState();
}

class _KnowledgeDetailScreenState extends ConsumerState<KnowledgeDetailScreen> {
  KnowledgeEntry? _entry;
  List<String> _tags = [];
  List<int> _tagIds = [];
  String _categoryName = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = await ref.read(databaseProvider.future);
    final entry = await db.knowledgeDao.getById(widget.entryId);
    final tagDao = TagDao(db);
    final tagIds = await tagDao.getForKnowledge(widget.entryId);
    final allTags = await tagDao.listAll();
    if (!mounted) return;
    // 加载分类名
    String catName = '';
    if (entry?.categoryId != null) {
      final cats = await db.knowledgeDao.listCategories();
      catName = cats.where((c) => c.id == entry!.categoryId).firstOrNull?.name ?? '';
    }
    setState(() {
      _entry = entry;
      _categoryName = catName;
      _tags = allTags.where((t) => tagIds.contains(t.id)).map((t) => t.name).toList();
      _tagIds = tagIds;
    });
  }

  Future<List<KnowledgeEntry>> _loadRelated() async {
    if (!mounted || _tagIds.isEmpty) return [];
    final db = await ref.read(databaseProvider.future);
    return db.knowledgeDao.listRelatedByTags(
      widget.entryId,
      _tagIds,
      limit: 3,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (_entry == null) {
      return Scaffold(
          appBar: AppBar(title: const Text('知识详情')),
          body: const ShimmerPlaceholder(height: 200));
    }

    final e = _entry!;
    return Scaffold(
      appBar: AppBar(
        title: const Text('知识详情'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () =>
                context.push('/knowledge/${e.id}/edit'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 来源
            if (e.sourceUrl != null)
              Text('来源: ${e.sourceUrl!}',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(color: cs.primary)),
            const SizedBox(height: AppSpacing.sm),

            // 标题
            Text(e.title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.sm),

            // 元数据
            Row(
              children: [
                Text('${e.createdAt.month}月${e.createdAt.day}日',
                    style: Theme.of(context).textTheme.labelMedium),
                if (_categoryName.isNotEmpty) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
                    decoration: BoxDecoration(
                      color: cs.tertiaryContainer,
                      borderRadius: BorderRadius.circular(AppRadius.xs),
                    ),
                    child: Text(_categoryName,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.onTertiaryContainer)),
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // AI 摘要（如果有）
            if (e.aiSummary != null) ...[
              Card(
                color: cs.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(Icons.auto_awesome, size: 16, color: cs.primary),
                        const SizedBox(width: AppSpacing.sm),
                        Text('AI 摘要', style: Theme.of(context).textTheme.labelLarge),
                      ]),
                      const SizedBox(height: AppSpacing.sm),
                      Text(e.aiSummary!, style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],

            // 正文
            if (e.contentMarkdown.isNotEmpty)
              MarkdownBody(
                data: e.contentMarkdown,
                styleSheet: MarkdownStyleSheet(
                  p: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.7),
                  h2: Theme.of(context).textTheme.titleLarge,
                  code: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        backgroundColor: cs.surfaceContainerHighest,
                      ),
                ),
              ),

            const SizedBox(height: AppSpacing.xl),

            // 标签
            if (_tags.isNotEmpty) ...[
              Wrap(
                children: _tags
                    .map((t) => ActionChip(
                          label: Text(t, style: const TextStyle(fontSize: 12)),
                          onPressed: () {},
                        ))
                    .toList(),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],

            // 附件
            if (e.filePaths != null && e.filePaths!.isNotEmpty) ...[
              AttachmentList(files: FileAttachmentManager.decode(e.filePaths)),
              const SizedBox(height: AppSpacing.lg),
            ],

            // 关联推荐
            const Divider(),
            const SizedBox(height: AppSpacing.sm),
            Text('最近更新', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            FutureBuilder<List<KnowledgeEntry>>(
              future: _loadRelated(),
              builder: (ctx, snap) {
                final related = snap.data ?? [];
                if (related.isEmpty) return const Text('暂无相关推荐');
                return Column(
                  children: related
                      .map((r) => ListTile(
                            leading: const Icon(Icons.article_outlined, size: 20),
                            title: Text(r.title, maxLines: 1),
                            onTap: () =>
                                context.push('/knowledge/${r.id}'),
                          ))
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
