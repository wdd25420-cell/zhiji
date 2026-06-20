import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide Column;
import '../../core/theme/dimensions.dart';
import '../../core/database/app_database.dart';
import '../../core/database/daos/common_daos.dart';
import '../../core/widgets/tag_chip.dart';
import '../../core/widgets/voice_input_button.dart';
import '../../core/widgets/markdown_toolbar.dart';
import '../../core/widgets/undo_manager.dart';
import '../../core/utils/file_importer.dart';
import '../../core/utils/file_attachment_manager.dart';
import '../../core/widgets/attachment_list.dart';
import '../../core/widgets/ai_icon.dart';
import '../../core/network/ai_api_service.dart';
import '../../core/agent/agent_provider.dart';
import '../../core/utils/editor_ai_actions.dart';
import 'widgets/emotion_selector.dart';

/// 日记编辑器（新建 + 编辑）
class DiaryEditorScreen extends ConsumerStatefulWidget {
  const DiaryEditorScreen({super.key, this.entryId});
  final int? entryId;

  @override
  ConsumerState<DiaryEditorScreen> createState() => _DiaryEditorScreenState();
}

class _DiaryEditorScreenState extends ConsumerState<DiaryEditorScreen> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  String _emotion = '';
  final _tags = <String>[];
  String _aiSummary = '';
  final _aiTagsList = <String>[];
  final _attachments = <AttachedFile>[];
  final _undoManager = UndoManager();
  late final TypingSnapshotTimer _snapshotTimer;
  bool _isAnalyzing = false;
  bool _isAiAction = false; // 续写/润色/总结 进行中
  bool _isSaving = false;

  bool get _hasChanges =>
      _titleCtrl.text.isNotEmpty ||
      _bodyCtrl.text.isNotEmpty ||
      _tags.isNotEmpty ||
      _attachments.isNotEmpty ||
      _emotion.isNotEmpty ||
      _aiSummary.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _snapshotTimer = TypingSnapshotTimer(
      undoManager: _undoManager,
      controller: _bodyCtrl,
    );
    _bodyCtrl.addListener(_snapshotTimer.onTextChanged);
    if (widget.entryId != null) {
      _loadEntry();
    } else {
      _restoreDraft(); // 恢复被系统 kill 前保存的草稿
    }
  }

  /// 保存草稿到 settings_table（防止相机/相册等外部 Activity 导致进程被杀后内容丢失）
  Future<void> _saveDraft() async {
    try {
      final db = await ref.read(databaseProvider.future);
      final draft = jsonEncode({
        'title': _titleCtrl.text,
        'body': _bodyCtrl.text,
        'emotion': _emotion,
        'tags': _tags,
        'aiSummary': _aiSummary,
        'aiTags': _aiTagsList,
        'attachments': FileAttachmentManager.encode(_attachments),
      });
      await SettingsDao(db).setValue('diary_draft', draft);
    } catch (_) {}
  }

  /// 恢复草稿（进程被系统 kill 后 initState 中调用）
  Future<void> _restoreDraft() async {
    try {
      final db = await ref.read(databaseProvider.future);
      final raw = await SettingsDao(db).getValue('diary_draft');
      if (raw == null || !mounted) return;
      await SettingsDao(db).remove('diary_draft'); // 恢复后立即清除
      final draft = jsonDecode(raw) as Map<String, dynamic>;
      setState(() {
        _titleCtrl.text = draft['title'] as String? ?? '';
        _bodyCtrl.text = draft['body'] as String? ?? '';
        _emotion = draft['emotion'] as String? ?? '';
        _aiSummary = draft['aiSummary'] as String? ?? '';
        _tags.addAll((draft['tags'] as List?)?.cast<String>() ?? []);
        _aiTagsList.addAll((draft['aiTags'] as List?)?.cast<String>() ?? []);
        _attachments.addAll(FileAttachmentManager.decode(draft['attachments'] as String?));
      });
    } catch (_) {}
  }

  Future<void> _loadEntry() async {
    final db = await ref.read(databaseProvider.future);
    final entry = await db.diaryDao.getById(widget.entryId!);
    if (entry == null || !mounted) return;
    final tagDao = TagDao(db);
    final tagIds = await tagDao.getForDiary(entry.id);
    final allTags = await tagDao.listAll();
    final tagNames = allTags.where((t) => tagIds.contains(t.id)).map((t) => t.name).toList();
    // 先尝试恢复草稿（系统 kill 后未保存的编辑）
    final draftDao = SettingsDao(db);
    final raw = await draftDao.getValue('diary_draft');
    if (raw != null) {
      await draftDao.remove('diary_draft');
      try {
        final draft = jsonDecode(raw) as Map<String, dynamic>;
        setState(() {
          _titleCtrl.text = draft['title'] as String? ?? entry.title;
          _bodyCtrl.text = draft['body'] as String? ?? entry.bodyMarkdown;
          _emotion = draft['emotion'] as String? ?? entry.emotion ?? '';
          _aiSummary = draft['aiSummary'] as String? ?? entry.aiSummary ?? '';
          _tags.addAll((draft['tags'] as List?)?.cast<String>() ?? tagNames);
          _aiTagsList.addAll((draft['aiTags'] as List?)?.cast<String>() ?? (entry.aiTags != null ? entry.aiTags!.split(',') : <String>[]));
          _attachments.addAll(FileAttachmentManager.decode(draft['attachments'] as String?));
        });
        return;
      } catch (_) {}
    }
    setState(() {
      _titleCtrl.text = entry.title;
      _bodyCtrl.text = entry.bodyMarkdown;
      _emotion = entry.emotion ?? '';
      _aiSummary = entry.aiSummary ?? '';
      if (entry.aiTags != null) {
        _aiTagsList.addAll(entry.aiTags!.split(','));
      }
      _tags.addAll(tagNames);
      _attachments.addAll(FileAttachmentManager.decode(entry.filePaths));
    });
  }

  /// 清除草稿
  Future<void> _clearDraft() async {
    try {
      final db = await ref.read(databaseProvider.future);
      await SettingsDao(db).remove('diary_draft');
    } catch (_) {}
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入标题')),
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      final db = await ref.read(databaseProvider.future);
      final tagDao = TagDao(db);
      final companion = DiaryEntriesCompanion(
        title: Value(_titleCtrl.text.trim()),
        bodyMarkdown: Value(_bodyCtrl.text),
        emotion: _emotion.isNotEmpty ? Value(_emotion) : const Value.absent(),
        aiSummary: _aiSummary.isNotEmpty ? Value(_aiSummary) : const Value.absent(),
        aiTags: _aiTagsList.isNotEmpty ? Value(_aiTagsList.join(',')) : const Value.absent(),
        filePaths: Value<String?>(FileAttachmentManager.encode(_attachments)),
        updatedAt: Value(DateTime.now()),
      );
      int id;
      if (widget.entryId != null) {
        // 编辑模式：更新已有条目
        await db.diaryDao.updateEntry(widget.entryId!, companion);
        id = widget.entryId!;
        // 批量清理旧标签关联
        await (db.delete(db.diaryTags)..where((t) => t.diaryEntryId.equals(id))).go();
      } else {
        id = await db.diaryDao.insertEntry(companion);
      }
      for (final t in _tags) {
        final tag = await tagDao.getOrCreate(t);
        await tagDao.linkDiary(id, tag.id);
      }
      if (mounted) {
        _clearDraft();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ 日记已保存')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteEntry() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除日记'),
        content: const Text('此操作不可撤销，确定删除这篇日记吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('确认删除', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );
    if (confirmed != true || widget.entryId == null) return;
    try {
      final db = await ref.read(databaseProvider.future);
      await db.diaryDao.deleteEntry(widget.entryId!);
      await FileAttachmentManager.deleteFiles(_attachments);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ 日记已删除')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('删除失败: $e')));
      }
    }
  }

  Future<void> _runAIAnalysis() async {
    setState(() => _isAnalyzing = true);
    try {
      final result = await AIService.analyzeDiary(
        _titleCtrl.text,
        _bodyCtrl.text,
      );
      if (!mounted) return;
      if (result != null) {
        final (summary, tags) = result;
        setState(() {
          _isAnalyzing = false;
          _aiSummary = summary;
          _aiTagsList.clear();
          _aiTagsList.addAll(tags);
        });
      } else {
        setState(() {
          _isAnalyzing = false;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('AI 分析失败，请检查 API Key 和网络')),
          );
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isAnalyzing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('AI 分析失败: $e')),
        );
      }
    }
  }

  /// AI 三件套：续写 / 润色 / 总结
  Future<void> _runAiAction(String action) async {
    _snapshotTimer.snapshotNow();
    setState(() => _isAiAction = true);
    final body = _bodyCtrl.text;
    final sel = _bodyCtrl.selection;
    final selectedText = sel.isValid && sel.start != sel.end
        ? body.substring(sel.start, sel.end)
        : '';
    try {
      final agent = await ref.read(agentServiceProvider.future);
      String? result;
      switch (action) {
        case '续写':
          result = await EditorAiActions.continueWriting(agent, body);
          if (result != null && mounted) {
            // 续写追加到末尾
            _bodyCtrl.text = '$body\n$result';
            _bodyCtrl.selection = TextSelection.collapsed(offset: _bodyCtrl.text.length);
          }
          break;
        case '润色':
          if (selectedText.isEmpty) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('请先选中要润色的文本')),
              );
            }
            setState(() => _isAiAction = false);
            return;
          }
          result = await EditorAiActions.polish(agent, selectedText);
          if (result != null && mounted) {
            _bodyCtrl.text = body.replaceRange(sel.start, sel.end, result);
            _bodyCtrl.selection = TextSelection.collapsed(offset: sel.start + result.length);
          }
          break;
        case '总结':
          final text = selectedText.isEmpty ? body : selectedText;
          result = await EditorAiActions.summarize(agent, text);
          if (result != null && mounted) {
            // 总结插入到末尾
            final prefix = body.isEmpty ? '' : '\n\n## AI 总结\n$result';
            _bodyCtrl.text = '$body$prefix';
            _bodyCtrl.selection = TextSelection.collapsed(offset: _bodyCtrl.text.length);
          }
          break;
      }
      if (mounted) {
        setState(() => _isAiAction = false);
        if (result != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ AI 处理完成')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isAiAction = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('AI 处理失败: $e')),
        );
      }
    }
  }

  Future<void> _showAttachmentPicker() async {
    final cs = Theme.of(context).colorScheme;
    final choice = await showModalBottomSheet<int>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('添加附件', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.md),
              ListTile(
                leading: Icon(Icons.camera_alt, color: cs.primary),
                title: const Text('拍照'),
                onTap: () => Navigator.pop(ctx, 0),
              ),
              ListTile(
                leading: Icon(Icons.photo_library, color: cs.primary),
                title: const Text('相册'),
                onTap: () => Navigator.pop(ctx, 1),
              ),
              ListTile(
                leading: Icon(Icons.attach_file, color: cs.primary),
                title: const Text('文件 (PDF/Word/Excel等)'),
                onTap: () => Navigator.pop(ctx, 2),
              ),
            ],
          ),
        ),
      ),
    );
    if (choice == null || !mounted) return;
    // 启动外部 Activity 前保存草稿（相机/相册/文件选择器可能导致进程被杀）
    await _saveDraft();
    if (!context.mounted) return;
    List<AttachedFile> picked;
    switch (choice) {
      case 0:
        // ignore: use_build_context_synchronously
        if (!await FileAttachmentManager.ensureCameraPermission(context)) return;
        final photo = await FileAttachmentManager.takePhoto();
        picked = photo != null ? [photo] : [];
        break;
      case 1:
        // ignore: use_build_context_synchronously
        if (!await FileAttachmentManager.ensureGalleryPermission(context)) return;
        picked = await FileAttachmentManager.pickImages();
        break;
      case 2:
        picked = await FileAttachmentManager.pickDocuments();
        break;
      default:
        picked = [];
    }
    if (picked.isNotEmpty && mounted) {
      setState(() => _attachments.addAll(picked));
    }
    _clearDraft(); // 成功返回后清除草稿
  }

  @override
  void dispose() {
    _snapshotTimer.dispose();
    _bodyCtrl.removeListener(_snapshotTimer.onTextChanged);
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('放弃编辑？'),
            content: const Text('你有未保存的内容，确定要退出吗？'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('继续编辑')),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text('放弃', style: TextStyle(color: cs.error)),
              ),
            ],
          ),
        );
        if (confirm == true && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
      appBar: AppBar(
        title: Text(widget.entryId != null ? '编辑日记' : '写日记'),
        actions: [
          if (widget.entryId != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _deleteEntry,
            ),
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Text('保存', style: TextStyle(color: cs.primary, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            EmotionSelector(selected: _emotion, onChanged: (v) => setState(() => _emotion = v)),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _titleCtrl,
              enabled: !_isSaving,
              decoration: const InputDecoration(
                hintText: '给今天的日记起个标题…',
                border: InputBorder.none,
              ),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.md),
            // 工具栏：撤销/重做 + 语音 + 文件导入 + Markdown + AI
            Row(
              children: [
                UndoRedoButtons(
                  undoManager: _undoManager,
                  controller: _bodyCtrl,
                ),
                VoiceInputButton(
                  onTextReady: (text) {
                    _snapshotTimer.snapshotNow();
                    final current = _bodyCtrl.text;
                    final insert = current.isEmpty ? text : '$current\n$text';
                    _bodyCtrl.text = insert;
                    _bodyCtrl.selection = TextSelection.collapsed(offset: insert.length);
                  },
                ),
                const SizedBox(width: AppSpacing.sm),
                IconButton(
                  icon: const Icon(Icons.attach_file),
                  tooltip: '导入文件',
                  onPressed: () => FileImporter.pickAndInsert(
                    context,
                    onInsert: (name, content) {
                      _snapshotTimer.snapshotNow();
                      final prefix = _bodyCtrl.text.isEmpty ? '' : '\n\n--- $name ---\n';
                      final insert = '${_bodyCtrl.text}$prefix$content';
                      _bodyCtrl.text = insert;
                      _bodyCtrl.selection = TextSelection.collapsed(offset: insert.length);
                    },
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                MarkdownToolbar(
                  controller: _bodyCtrl,
                  onBeforeAction: _snapshotTimer.snapshotNow,
                ),
                const SizedBox(width: AppSpacing.xs),
                _isAiAction
                    ? const SizedBox(
                        width: 24, height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : PopupMenuButton<String>(
                        icon: Icon(Icons.auto_awesome, size: 20, color: cs.primary),
                        tooltip: 'AI 工具',
                        onSelected: _runAiAction,
                        itemBuilder: (ctx) => const [
                          PopupMenuItem(value: '续写', child: ListTile(
                              leading: Icon(Icons.text_increase), title: Text('续写'), dense: true)),
                          PopupMenuItem(value: '润色', child: ListTile(
                              leading: Icon(Icons.auto_fix_high), title: Text('润色'), dense: true)),
                          PopupMenuItem(value: '总结', child: ListTile(
                              leading: Icon(Icons.summarize), title: Text('总结'), dense: true)),
                        ],
                      ),
                const Spacer(),
                Text('${_bodyCtrl.text.length} 字',
                    style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _bodyCtrl,
              enabled: !_isSaving,
              maxLines: null,
              minLines: 6,
              decoration: const InputDecoration(
                hintText: '今天发生了什么？想到了什么？…',
                border: InputBorder.none,
              ),
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: AppSpacing.lg),
            TagInputField(
              tags: _tags,
              onAdd: (t) => setState(() => _tags.add(t)),
              onRemove: (t) => setState(() => _tags.remove(t)),
            ),
            const SizedBox(height: AppSpacing.lg),
            // 附件区域
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('附件 (${_attachments.length})', style: Theme.of(context).textTheme.labelLarge),
                TextButton.icon(
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('添加'),
                  onPressed: _showAttachmentPicker,
                ),
              ],
            ),
            AttachmentList(
              files: _attachments,
              editable: true,
              onRemove: (i) => setState(() {
                FileAttachmentManager.deleteFile(_attachments[i]);
                _attachments.removeAt(i);
              }),
            ),
            const SizedBox(height: AppSpacing.lg),
            Card(
              color: cs.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const AiIcon(size: 20),
                      const SizedBox(width: AppSpacing.sm),
                      Text('DeepSeek AI 分析', style: Theme.of(context).textTheme.titleSmall),
                    ]),
                    const SizedBox(height: AppSpacing.md),
                    if (_isAnalyzing)
                      const LinearProgressIndicator()
                    else
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _runAIAnalysis,
                          icon: const Icon(Icons.auto_awesome, size: 18),
                          label: const Text('分析这篇日记'),
                        ),
                      ),
                    if (_aiSummary.isNotEmpty && !_isAnalyzing) ...[
                      const SizedBox(height: AppSpacing.md),
                      Text(_aiSummary, style: Theme.of(context).textTheme.bodyMedium),
                      if (_aiTagsList.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Wrap(
                          children: _aiTagsList
                              .map((t) => TagChip(
                                    label: t,
                                    isAi: true,
                                    onTap: () => setState(() {
                                      if (!_tags.contains(t)) _tags.add(t);
                                    }),
                                  ))
                              .toList(),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
            SizedBox(height: AppSpacing.massive),
          ],
        ),
      ),
    ),
    );
  }
}
