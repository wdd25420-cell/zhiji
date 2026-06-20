import 'dart:convert';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/dimensions.dart';
import '../../core/database/app_database.dart';
import '../../core/database/daos/common_daos.dart';
import '../../core/widgets/shimmer_placeholder.dart';

/// 全文搜索
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key, this.initialQuery});
  final String? initialQuery;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  final _history = <String>[];
  List<Map<String, Object?>> _results = [];
  bool _searching = false;
  static const _historyKey = 'search_history';

  @override
  void initState() {
    super.initState();
    _loadHistory();
    if (widget.initialQuery != null) {
      _controller.text = widget.initialQuery!;
      _doSearch(widget.initialQuery!);
    }
  }

  Future<void> _loadHistory() async {
    try {
      final db = await ref.read(databaseProvider.future);
      final raw = await SettingsDao(db).getValue(_historyKey);
      if (raw != null && mounted) {
        final list = (jsonDecode(raw) as List).cast<String>();
        setState(() => _history.addAll(list.take(20)));
      }
    } catch (_) {}
  }

  Future<void> _saveHistory() async {
    try {
      final db = await ref.read(databaseProvider.future);
      await SettingsDao(db).setValue(_historyKey, jsonEncode(_history.take(20).toList()));
    } catch (_) {}
  }

  Future<void> _doSearch(String query) async {
    if (query.trim().isEmpty) return;
    setState(() => _searching = true);
    try {
      final db = await ref.read(databaseProvider.future);
      final results = await db.search(query.trim());
      if (mounted) {
        setState(() {
          _results = results;
          _searching = false;
          if (query.isNotEmpty && !_history.contains(query)) {
            _history.insert(0, query);
            _saveHistory();
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _searching = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('搜索失败: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 构建搜索高亮文本——匹配词用 primary 色加粗
  static Widget _buildHighlighted(String? text, String query, Color highlightColor, {int maxLines = 1}) {
    final content = text ?? '';
    if (query.isEmpty || !content.toLowerCase().contains(query.toLowerCase())) {
      return Text(content, maxLines: maxLines, overflow: TextOverflow.ellipsis);
    }
    final lower = content.toLowerCase();
    final qLower = query.toLowerCase();
    final spans = <TextSpan>[];
    var start = 0;
    while (true) {
      final idx = lower.indexOf(qLower, start);
      if (idx < 0) {
        spans.add(TextSpan(text: content.substring(start)));
        break;
      }
      if (idx > start) {
        spans.add(TextSpan(text: content.substring(start, idx)));
      }
      spans.add(TextSpan(
        text: content.substring(idx, idx + query.length),
        style: TextStyle(color: highlightColor, fontWeight: FontWeight.w700),
      ));
      start = idx + query.length;
    }
    return RichText(
      text: TextSpan(
        style: TextStyle(color: highlightColor.withValues(alpha: 0.8), fontSize: 14),
        children: spans,
      ),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: '搜索所有日记和知识…',
            hintStyle: Theme.of(context).textTheme.bodyLarge,
            border: InputBorder.none,
          ),
          onSubmitted: _doSearch,
        ),
        actions: [
          if (_controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _controller.clear();
                setState(() => _results = []);
              },
            ),
          IconButton(
              icon: const Icon(Icons.search), onPressed: () => _doSearch(_controller.text)),
        ],
      ),
      body: Column(
        children: [
          if (_results.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
              child: Text('共找到 ${_results.length} 条结果',
                  style: Theme.of(context).textTheme.labelMedium),
            ),
          Expanded(
            child: _searching
          ? const ShimmerPlaceholder(height: 200)
          : _results.isNotEmpty
              ? ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: _results.length,
                  separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (ctx, i) {
                    final r = _results[i];
                    final type = r['source_type'] as String? ?? '';
                    final title = r['title'] as String? ?? '';
                    final body = r['body'] as String? ?? '';
                    final sourceId = r['source_id'] as int? ?? 0;
                    final isKnowledge = type == 'knowledge';
                    final query = _controller.text.trim();
                    return Card(
                      child: ListTile(
                        title: _buildHighlighted(title, query, cs.primary),
                        subtitle: _buildHighlighted(body, query, cs.primary, maxLines: 2),
                        leading: Icon(isKnowledge ? Icons.folder : Icons.book,
                            color: cs.primary),
                        trailing: Text(isKnowledge ? '知识库' : '日记',
                            style: Theme.of(context).textTheme.labelSmall),
                        onTap: () {
                          final route = isKnowledge
                              ? '/knowledge/$sourceId'
                              : '/diary/$sourceId';
                          context.push(route);
                        },
                      ),
                    );
                  },
                )
              : _history.isNotEmpty
                  ? ListView(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      children: [
                        Text('搜索历史', style: Theme.of(context).textTheme.titleSmall),
                        const SizedBox(height: AppSpacing.sm),
                        Wrap(
                          children: _history
                              .map((h) => Padding(
                                    padding: const EdgeInsets.only(right: AppSpacing.sm, bottom: AppSpacing.sm),
                                    child: ActionChip(
                                        label: Text(h),
                                        onPressed: () {
                                          _controller.text = h;
                                          _doSearch(h);
                                        }),
                                  ))
                              .toList(),
                        ),
                      ],
                    )
                  : const Center(child: Text('输入关键词开始搜索')),
            ),
          ],
        ),
      );
  }
}
