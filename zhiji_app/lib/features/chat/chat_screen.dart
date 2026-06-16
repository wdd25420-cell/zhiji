import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/dimensions.dart';
import '../../core/database/app_database.dart';
import '../../core/network/ai_api_service.dart';

/// AI 智能问答屏幕 (RAG)
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _messages = <_ChatMessage>[];
  bool _loading = false;

  @override
  void dispose() {
    _controller.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _send(String text) async {
    final question = text.trim();
    if (question.isEmpty) return;
    _controller.clear();
    setState(() {
      _messages.add(_ChatMessage(role: 'user', content: question));
      _loading = true;
    });
    _scrollDown();

    try {
      final db = await ref.read(databaseProvider.future);
      // FTS5 检索前5条相关上下文，每条截断到1500字防止超 token
      final results = await db.search(question);
      final context = results.take(5).map((r) {
        final type = r['source_type'] as String? ?? '';
        final title = r['title'] as String? ?? '';
        final rawBody = r['body'] as String? ?? '';
        final body = rawBody.length > 1500 ? '${rawBody.substring(0, 1500)}...' : rawBody;
        return '[$type] $title\n$body';
      }).join('\n---\n');

      final answer = await AIService.askQuestion(question, context);
      if (mounted) {
        setState(() {
          _loading = false;
          _messages.add(_ChatMessage(
            role: 'ai',
            content: answer ?? '抱歉，AI 服务暂时不可用。请检查 API Key 和网络连接。',
          ));
        });
        _scrollDown();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _messages.add(_ChatMessage(
            role: 'ai',
            content: '发生错误: $e',
          ));
        });
        _scrollDown();
      }
    }
  }

  void _scrollDown() {
    Future.microtask(() {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 问答'),
        actions: [
          if (_messages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: '清空对话',
              onPressed: () => setState(() => _messages.clear()),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? _buildWelcome(cs)
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: _messages.length + (_loading ? 1 : 0),
                    itemBuilder: (ctx, i) {
                      if (_loading && i == _messages.length) {
                        return _buildBubble(
                          cs: cs,
                          role: 'ai',
                          child: const Padding(
                            padding: EdgeInsets.all(AppSpacing.md),
                            child: Text('思考中…', style: TextStyle(fontStyle: FontStyle.italic)),
                          ),
                        );
                      }
                      final msg = _messages[i];
                      return _buildBubble(
                        cs: cs,
                        role: msg.role,
                        child: SelectableText(msg.content,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.6)),
                      );
                    },
                  ),
          ),
          _buildInput(cs),
        ],
      ),
    );
  }

  Widget _buildWelcome(ColorScheme cs) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(AppRadius.xl),
              ),
              child: Center(child: Text('🤖', style: TextStyle(fontSize: 36))),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('AI 智能问答', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '基于你的日记和知识库，我可以回答任何问题。\n试试问我你最近写了什么，或者某个话题的相关内容。',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                _QuickAsk(label: '最近一周的心情如何？', onTap: () => _send('最近一周的心情如何？')),
                _QuickAsk(label: '我写了哪些主题的笔记？', onTap: () => _send('我写了哪些主题的笔记？')),
                _QuickAsk(label: '帮我回顾本周重点', onTap: () => _send('帮我回顾本周重点')),
                _QuickAsk(label: '推荐一些相关知识', onTap: () => _send('根据我的笔记推荐一些值得回顾的内容')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBubble({required ColorScheme cs, required String role, required Widget child}) {
    final isUser = role == 'user';
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Center(child: Text('🤖', style: TextStyle(fontSize: 16))),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: isUser ? cs.primaryContainer : cs.surfaceContainerHighest,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(AppRadius.lg),
                  topRight: const Radius.circular(AppRadius.lg),
                  bottomLeft: isUser ? const Radius.circular(AppRadius.lg) : Radius.zero,
                  bottomRight: isUser ? Radius.zero : const Radius.circular(AppRadius.lg),
                ),
              ),
              child: child,
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: AppSpacing.sm),
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: cs.secondaryContainer,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(Icons.person, size: 18, color: cs.onSecondaryContainer),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInput(ColorScheme cs) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.sm, AppSpacing.md),
        decoration: BoxDecoration(
          color: cs.surface,
          border: Border(top: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.3))),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: _send,
                decoration: InputDecoration(
                  hintText: '问点什么…',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: cs.surfaceContainerHighest,
                  contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            IconButton(
              icon: const Icon(Icons.send),
              color: cs.primary,
              onPressed: _loading ? null : () => _send(_controller.text),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAsk extends StatelessWidget {
  const _QuickAsk({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: const Icon(Icons.auto_awesome, size: 14),
      label: Text(label),
      onPressed: onTap,
    );
  }
}

class _ChatMessage {
  final String role; // 'user' | 'ai'
  final String content;
  _ChatMessage({required this.role, required this.content});
}
