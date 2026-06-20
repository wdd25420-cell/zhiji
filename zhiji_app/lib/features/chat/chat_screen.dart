import "package:flutter/material.dart";
import "package:drift/drift.dart" hide Column;
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "../../core/theme/dimensions.dart";
import "../../core/utils/file_attachment_manager.dart";
import "../../core/widgets/attachment_list.dart";
import "../../core/widgets/voice_input_button.dart";
import "../../core/widgets/ai_icon.dart";
import "../../core/agent/agent_provider.dart";
import "../../core/agent/agent_service.dart";
import "../../core/database/app_database.dart";
import "../../core/database/daos/common_daos.dart";

/// AI Agent 对话屏幕
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _messages = <_ChatMessage>[];
  final _attachments = <AttachedFile>[];
  bool _loading = false;
  String _toolStatus = "";
  String _sessionId = "";
  bool _historyLoaded = false;

  @override
  void initState() {
    super.initState();
    _sessionId = DateTime.now().millisecondsSinceEpoch.toString();
    _loadHistory();
  }

  /// 从 agent_messages 表加载最近会话历史
  Future<void> _loadHistory() async {
    try {
      final db = await ref.read(databaseProvider.future);
      final rows = await db.customSelect(
        "SELECT session_id, role, content FROM agent_messages "
        "ORDER BY created_at DESC LIMIT 50",
        readsFrom: {db.agentMessages},
      ).get();

      if (rows.isEmpty) return;
      // 按时间正序（从旧到新）
      final reversed = rows.reversed.toList();
      // 取最后一条消息的 session_id 作为当前会话
      final lastRow = rows.first;
      _sessionId = lastRow.read<String>("session_id");

      final loaded = <_ChatMessage>[];
      for (final row in reversed) {
        final sid = row.read<String>("session_id");
        if (sid != _sessionId) continue;
        loaded.add(_ChatMessage(
          role: row.read<String>("role"),
          content: row.read<String>("content"),
        ));
      }
      if (mounted) {
        setState(() {
          _messages.addAll(loaded);
          _historyLoaded = true;
        });
      }
    } catch (_) {
      // DB 不可用时静默降级，不影响对话功能
    }
  }

  /// 保存单条消息到 agent_messages 表
  Future<void> _saveMessage(String role, String content, {String? toolName}) async {
    try {
      final db = await ref.read(databaseProvider.future);
      await db.customInsert(
        "INSERT INTO agent_messages (session_id, role, content, tool_name) "
        "VALUES (?, ?, ?, ?)",
        variables: [
          Variable.withString(_sessionId),
          Variable.withString(role),
          Variable.withString(content),
          Variable.withString(toolName ?? ""),
        ],
        updates: {db.agentMessages},
      );
    } catch (_) {
      // 持久化失败不阻塞对话
    }
  }

  /// 构建多轮对话历史（不含当前 system prompt 和最新用户消息）
  List<Map<String, dynamic>> _buildHistory() {
    return _messages
        .where((m) => m.role == "user" || m.role == "ai")
        .map((m) => {"role": m.role == "ai" ? "assistant" : m.role, "content": m.content})
        .toList();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onVoiceText(String text) {
    if (text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("未识别到语音，请重试")),
      );
      return;
    }
    _controller.text = text;
    _send(text);
  }

  Future<void> _pickAttachments() async {
    final files = await FileAttachmentManager.pickDocuments(allowMultiple: true);
    if (files.isNotEmpty && mounted) {
      setState(() => _attachments.addAll(files));
    }
  }

  void _removeAttachment(int index) {
    setState(() {
      FileAttachmentManager.deleteFile(_attachments[index]);
      _attachments.removeAt(index);
    });
  }

  void _clearAttachments() {
    for (final f in _attachments) {
      FileAttachmentManager.deleteFile(f);
    }
    setState(() => _attachments.clear());
  }

  Future<void> _send(String text) async {
    final question = text.trim();
    if (question.isEmpty) return;
    _controller.clear();

    // 检测 API Key 是否已配置
    final db = await ref.read(databaseProvider.future);
    final key = await SettingsDao(db).getApiKey();
    if (key == null || key.isEmpty) {
      if (mounted) {
        setState(() {
          _messages.add(_ChatMessage(
            role: "ai",
            content: "👋 欢迎使用知记！\n\n"
                "我注意到你还没有设置 API Key。请在设置中配置 DeepSeek API Key 以启用 AI 功能。\n\n"
                "在没有 AI 的情况下，你仍然可以：\n"
                "• 📝 写日记 — 从功能菜单进入\n"
                "• 📚 管理知识库 — 添加和整理你的知识\n"
                "• 🔍 搜索 — 全文搜索你的所有内容\n"
                "• 📊 查看仪表盘 — 写作统计和趋势\n\n"
                "前往 **设置 → DeepSeek API Key** 完成配置。",
          ));
        });
        _scrollDown();
      }
      return;
    }

    final attachedCopy = List<AttachedFile>.from(_attachments);

    setState(() {
      _messages.add(_ChatMessage(role: "user", content: question));
      _loading = true;
    });
    _scrollDown();

    // 持久化用户消息
    _saveMessage("user", question);

    try {
      final agent = await ref.read(agentServiceProvider.future);
      final history = _buildHistory();

      final stream = agent.runStream(
        question,
        history: history.isNotEmpty ? history : null,
        attachments: attachedCopy.isNotEmpty ? attachedCopy : null,
      );

      final aiBuffer = StringBuffer();
      bool aiMsgAdded = false;

      await for (final step in stream) {
        if (!mounted) break;
        switch (step.type) {
          case AgentStepType.thinking:
            _toolStatus = "思考中…";
            break;
          case AgentStepType.searching:
            _toolStatus = "正在搜索知识库…";
            break;
          case AgentStepType.webSearching:
            _toolStatus = "正在联网搜索…";
            break;
          case AgentStepType.analyzing:
            _toolStatus = "正在分析结果…";
            break;
          case AgentStepType.writing:
            _toolStatus = "正在写入…";
            break;
          case AgentStepType.responding:
            if (!aiMsgAdded && mounted) {
              aiMsgAdded = true;
              setState(() {
                _loading = false;
                _messages.add(_ChatMessage(role: "ai", content: ""));
              });
            }
            aiBuffer.write(step.contentDelta ?? "");
            if (mounted && _messages.isNotEmpty && _messages.last.role == "ai") {
              setState(() {
                _messages.last.content = aiBuffer.toString();
              });
            }
            break;
          case AgentStepType.done:
            if (aiBuffer.isNotEmpty) {
              _saveMessage("assistant", aiBuffer.toString());
            }
            break;
          case AgentStepType.error:
            // 错误由流内 contentDelta 携带，不应重复处理
            break;
        }
        if (mounted && step.type != AgentStepType.responding && step.type != AgentStepType.done) {
          setState(() {}); // 刷新工具状态显示
        }
      }

      // T12: 记录用户提问话题到记忆
      final notifier = ref.read(agentMemoryNotifierProvider);
      await notifier.addRecentTopic(question);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _messages.add(_ChatMessage(
            role: "ai",
            content: "处理请求时出错，请稍后重试。",
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
        title: const Text("AI Agent"),
        actions: [
          if (_messages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: "新对话",
              onPressed: () {
                _clearAttachments();
                setState(() {
                  _messages.clear();
                  _sessionId = DateTime.now().millisecondsSinceEpoch.toString();
                });
              },
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty && !_historyLoaded
                ? _buildWelcome(cs)
                : _messages.isEmpty
                    ? _buildWelcome(cs)
                    : ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.all(AppSpacing.md),
                        itemCount: _messages.length + (_loading ? 1 : 0),
                        itemBuilder: (ctx, i) {
                          if (_loading && i == _messages.length) {
                            return _buildBubble(
                              cs: cs,
                              role: "ai",
                              child: Padding(
                                padding: const EdgeInsets.all(AppSpacing.md),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const _BreathingDots(),
                                    if (_toolStatus.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Text(_toolStatus,
                                        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                                    ],
                                  ],
                                ),
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
              child: const AiIcon(size: 36),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text("知记 Agent", style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.sm),
            Text(
              "我是你的知识管家。\n你可以问我任何问题，我会搜索你的日记、知识库，也能联网查找。",
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                _QuickAsk(label: "最近一周的心情如何？", onTap: () => _send("最近一周的心情如何？")),
                _QuickAsk(label: "我写了哪些主题的笔记？", onTap: () => _send("我写了哪些主题的笔记？")),
                _QuickAsk(label: "帮我回顾本周重点", onTap: () => _send("帮我回顾本周重点")),
                _QuickAsk(label: "推荐一些相关知识", onTap: () => _send("根据我的笔记推荐一些值得回顾的内容")),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            ActionChip(
              avatar: const Icon(Icons.settings, size: 14),
              label: const Text("前往设置"),
              onPressed: () => context.push('/settings'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBubble({required ColorScheme cs, required String role, required Widget child}) {
    final isUser = role == "user";
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
              child: const AiIcon(size: 16, withBackground: false),
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_attachments.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
              child: AttachmentList(
                files: _attachments,
                editable: true,
                onRemove: _removeAttachment,
              ),
            ),
          Container(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.sm, AppSpacing.md),
            decoration: BoxDecoration(
              color: cs.surface,
              border: Border(top: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.3))),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.attach_file),
                  color: cs.onSurfaceVariant,
                  tooltip: "添加附件",
                  onPressed: _pickAttachments,
                ),
                VoiceInputButton(
                  onTextReady: _onVoiceText,
                  size: 36,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: _send,
                    decoration: InputDecoration(
                      hintText: "说点什么…",
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
        ],
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
  final String role;
  String content;
  _ChatMessage({required this.role, required this.content});
}

class _BreathingDots extends StatefulWidget {
  const _BreathingDots();
  @override
  State<_BreathingDots> createState() => _BreathingDotsState();
}

class _BreathingDotsState extends State<_BreathingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        final t = (_ctrl.value + i * 0.33) % 1.0;
        final opacity = (t <= 0.5 ? t * 2 : 2 - t * 2);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Container(
            width: 6, height: 6,
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.3 + opacity * 0.5),
              shape: BoxShape.circle,
            ),
          ),
        );
      }),
    );
  }
}
