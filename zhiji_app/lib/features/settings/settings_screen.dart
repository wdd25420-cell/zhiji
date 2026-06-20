import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../../core/theme/dimensions.dart';
import '../../core/database/app_database.dart';
import '../../core/database/daos/common_daos.dart';
import '../../core/providers/theme_provider.dart';
import '../lock/app_lock_screen.dart';

/// 设置页
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _apiKeyCtrl = TextEditingController();
  bool _aiEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final db = await ref.read(databaseProvider.future);
    final settingsDao = SettingsDao(db);
    final key = await settingsDao.getApiKey();
    final ai = await settingsDao.getValue('ai_enabled');
    if (mounted) {
      setState(() {
        if (key != null) _apiKeyCtrl.text = key;
        _aiEnabled = ai != 'false';
      });
    }
  }

  Future<void> _saveApiKey() async {
    final db = await ref.read(databaseProvider.future);
    await SettingsDao(db).setApiKey(_apiKeyCtrl.text.trim());
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('✅ API Key 已保存')));
    }
  }

  Future<void> _exportData() async {
    final db = await ref.read(databaseProvider.future);
    final tagDao = TagDao(db);
    final diaries = await db.diaryDao.watchAll().first;
    final knowledges = await db.knowledgeDao.watchAll().first;
    final categories = await db.knowledgeDao.listCategories();

    // 收集标签关联
    final diaryTags = <int, List<String>>{};
    for (final d in diaries) {
      final tagIds = await tagDao.getForDiary(d.id);
      final tags = await tagDao.listAll();
      diaryTags[d.id] = tags.where((t) => tagIds.contains(t.id)).map((t) => t.name).toList();
    }
    final knowledgeTags = <int, List<String>>{};
    for (final k in knowledges) {
      final tagIds = await tagDao.getForKnowledge(k.id);
      final tags = await tagDao.listAll();
      knowledgeTags[k.id] = tags.where((t) => tagIds.contains(t.id)).map((t) => t.name).toList();
    }

    final data = {
      'exported': DateTime.now().toIso8601String(),
      'version': '1.0.0',
      'categories': categories.map((c) => {'name': c.name, 'icon': c.icon}).toList(),
      'diaries': diaries.map((d) => {
        'title': d.title,
        'body': d.bodyMarkdown,
        'emotion': d.emotion,
        'aiSummary': d.aiSummary,
        'aiTags': d.aiTags?.split(','),
        'tags': diaryTags[d.id],
        'createdAt': d.createdAt.toIso8601String(),
      }).toList(),
      'knowledges': knowledges.map((k) => {
        'title': k.title,
        'content': k.contentMarkdown,
        'sourceUrl': k.sourceUrl,
        'categoryId': k.categoryId,
        'categoryName': categories.where((c) => c.id == k.categoryId).firstOrNull?.name,
        'aiSummary': k.aiSummary,
        'aiTags': k.aiTags?.split(','),
        'tags': knowledgeTags[k.id],
        'createdAt': k.createdAt.toIso8601String(),
      }).toList(),
    };
    final json = const JsonEncoder.withIndent('  ').convert(data);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/zhiji_backup_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.json');
    await file.writeAsString(json);
    await Share.shareXFiles([XFile(file.path)], subject: '知记数据备份');
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('✅ 数据已导出')));
    }
  }

  Future<void> _importData() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null || result.files.isEmpty || result.files.first.path == null) return;
    final file = File(result.files.first.path!);
    String content;
    try {
      content = await file.readAsString();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('文件读取失败')));
      }
      return;
    }
    try {
      final data = jsonDecode(content);
      if (data is! Map<String, dynamic>) throw const FormatException('JSON 格式错误');
      final version = data['version'] as String?;
      if (version == null) throw const FormatException('缺少 version 字段');

      final db = await ref.read(databaseProvider.future);
      final tagDao = TagDao(db);
      int count = 0;

      // 事务包裹：全部或全不
      await db.transaction(() async {
        // 导入日记
        for (final d in (data['diaries'] as List? ?? [])) {
          final title = d['title'] as String? ?? '';
          if (title.isEmpty) continue;
          final id = await db.diaryDao.insertEntry(
            DiaryEntriesCompanion.insert(
              title: title,
              bodyMarkdown: Value(d['body'] as String? ?? ''),
              emotion: d['emotion'] != null ? Value(d['emotion'] as String) : const Value.absent(),
              aiSummary: d['aiSummary'] != null ? Value(d['aiSummary'] as String) : const Value.absent(),
              aiTags: d['aiTags'] != null ? Value((d['aiTags'] as List).join(',')) : const Value.absent(),
            ),
          );
          final tags = (d['tags'] as List? ?? []).cast<String>();
          for (final t in tags) {
            final tag = await tagDao.getOrCreate(t);
            await tagDao.linkDiary(id, tag.id);
          }
          count++;
        }
        // 导入知识
        for (final k in (data['knowledges'] as List? ?? [])) {
          final title = k['title'] as String? ?? '';
          if (title.isEmpty) continue;
          // 优先按分类名匹配，回退到 categoryId
          int? resolvedCatId = k['categoryId'] as int?;
          if (k['categoryName'] != null) {
            final cats = await db.knowledgeDao.listCategories();
            final found = cats.where((c) => c.name == k['categoryName']).firstOrNull;
            if (found != null) resolvedCatId = found.id;
          }
          final id = await db.knowledgeDao.insertEntry(
            KnowledgeEntriesCompanion.insert(
              title: title,
              contentMarkdown: Value(k['content'] as String? ?? ''),
              sourceUrl: k['sourceUrl'] != null ? Value(k['sourceUrl'] as String) : const Value.absent(),
              categoryId: resolvedCatId != null ? Value(resolvedCatId) : const Value.absent(),
              aiSummary: k['aiSummary'] != null ? Value(k['aiSummary'] as String) : const Value.absent(),
              aiTags: k['aiTags'] != null ? Value((k['aiTags'] as List).join(',')) : const Value.absent(),
            ),
          );
          final tags = (k['tags'] as List? ?? []).cast<String>();
          for (final t in tags) {
            final tag = await tagDao.getOrCreate(t);
            await tagDao.linkKnowledge(id, tag.id);
          }
          count++;
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('✅ 已导入 $count 条数据')));
      }
    } on FormatException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('格式错误: ${e.message}')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('导入失败: $e')));
      }
    }
  }

  @override
  void dispose() {
    _apiKeyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          // AI 服务
          const _SectionTitle('AI 服务'),
          Card(
            child: Column(
              children: [
                ListTile(
                  title: const Text('DeepSeek API Key'),
                  subtitle: TextField(
                    controller: _apiKeyCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                        border: InputBorder.none, hintText: 'sk-…', isDense: true),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  trailing: IconButton(
                      icon: const Icon(Icons.save_outlined), onPressed: _saveApiKey),
                ),
                SwitchListTile(
                  title: const Text('自动 AI 分析'),
                  subtitle: const Text('新建条目时自动分析'),
                  value: _aiEnabled,
                  onChanged: (v) async {
                    setState(() => _aiEnabled = v);
                    final db = await ref.read(databaseProvider.future);
                    await SettingsDao(db).setValue('ai_enabled', v.toString());
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  title: const Text('深色模式'),
                  leading: const Icon(Icons.dark_mode_outlined),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: SegmentedButton<ThemeMode>(
                      segments: const [
                        ButtonSegment(value: ThemeMode.system, label: Text('系统'), icon: Icon(Icons.settings_suggest)),
                        ButtonSegment(value: ThemeMode.light, label: Text('浅色'), icon: Icon(Icons.light_mode)),
                        ButtonSegment(value: ThemeMode.dark, label: Text('深色'), icon: Icon(Icons.dark_mode)),
                      ],
                      selected: {ref.watch(themeModeProvider)},
                      onSelectionChanged: (modes) {
                        ref.read(themeModeProvider.notifier).set(modes.first);
                      },
                      style: const ButtonStyle(
                        visualDensity: VisualDensity.compact,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          // 安全
          const _SectionTitle('安全'),
          Card(
            child: ListTile(
              leading: const Icon(Icons.lock_outline),
              title: const Text('应用锁'),
              subtitle: const Text('设置 PIN 码保护应用隐私'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final db = await ref.read(databaseProvider.future);
                if (context.mounted) {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => AppLockScreen(db: db)),
                  );
                }
              },
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          // 数据管理
          const _SectionTitle('数据管理'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.upload),
                  title: const Text('导出数据'),
                  subtitle: const Text('导出为 JSON 格式'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _exportData,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.download),
                  title: const Text('导入数据'),
                  subtitle: const Text('从 JSON 文件恢复'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _importData,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          // 关于
          const _SectionTitle('关于'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('知记'),
                  subtitle: const Text('v1.0.0 · AI 个人知识库'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: const Text('隐私政策'),
                  subtitle: const Text('数据仅保存在本地，不上传云端'),
                  onTap: () => _showPrivacyPolicy(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.feedback_outlined),
                  title: const Text('用户反馈'),
                  subtitle: const Text('AI 原生个人知识管理'),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('感谢使用知记！如有建议请通过应用商店反馈联系我们。')),
                    );
                  },
                ),
              ],
            ),
          ),

          // 删除按钮
          const SizedBox(height: AppSpacing.xl),
          Center(
            child: OutlinedButton(
              onPressed: () => showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('删除所有数据'),
                  content: const Text('将清除所有日记和知识条目（保留你的设置与 API Key），确定吗？'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
                    TextButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        if (!context.mounted) return;
                        final db = await ref.read(databaseProvider.future);
                        await db.transaction(() async {
                          await db.delete(db.diaryTags).go();
                          await db.delete(db.knowledgeTags).go();
                          await db.delete(db.tags).go();
                          await db.delete(db.diaryEntries).go();
                          await db.delete(db.knowledgeEntries).go();
                          // 保留 settingsTable（API Key、主题、搜索历史）
                          await db.customStatement('DELETE FROM search_index');
                        });
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('✅ 所有数据已清除')));
                          setState(() {});
                        }
                      },
                      child: Text('确认删除', style: TextStyle(color: cs.error)),
                    ),
                  ],
                ),
              ),
              style: OutlinedButton.styleFrom(foregroundColor: cs.error),
              child: const Text('删除所有数据'),
            ),
          ),
        ],
      ),
    );
  }

  void _showPrivacyPolicy(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        expand: false,
        builder: (ctx, scrollCtrl) => SingleChildScrollView(
          controller: scrollCtrl,
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('隐私政策', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: AppSpacing.sm),
              Text('最后更新：2026年6月17日', style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: AppSpacing.lg),

              _section('一、数据收集与存储'),
              _body('知记是一款离线优先的个人知识管理应用。你的所有数据——包括日记内容、知识条目、标签、分类、设置——均仅保存在你的设备本地存储中。'),
              _body('我们不会将你的任何个人数据上传到任何服务器。知记没有后端服务，没有用户账户系统，也不会收集使用统计数据。'),

              _section('二、AI 功能与第三方服务'),
              _body('知记提供基于 DeepSeek API 的 AI 分析、续写、润色、总结和智能问答功能。当你在编辑器中使用 AI 功能或使用 AI 问答屏幕时，你的日记/知识文本会被发送到 DeepSeek API（api.deepseek.com）进行处理。'),
              _body('AI 请求通过 HTTPS 加密传输。你的 API Key 通过 Android 系统级密钥库（Keystore）加密存储在本设备中。知记不会将你的 API Key 分享给任何第三方。'),
              _body('AI 功能是可选的。你可以在设置页面移除 API Key 以禁用所有 AI 功能，其余功能不受影响。'),

              _section('三、文件与附件'),
              _body('你在日记或知识条目中添加的附件（照片、文档等）保存在应用私有目录中，不会上传到云端。卸载应用时，附件随应用数据一起被系统清除。'),

              _section('四、数据导出与删除'),
              _body('你可以随时在设置页面导出所有数据为 JSON 格式，或通过导入功能从备份恢复。你可以随时在设置页面清空所有数据（保留 API Key 和主题设置），或直接卸载应用。'),

              _section('五、权限使用说明'),
              _body('• 网络（INTERNET）：仅用于连接 DeepSeek API。\n'
                  '• 麦克风（RECORD_AUDIO）：仅在语音输入功能时使用，非持续监听。\n'
                  '• 相机（CAMERA）：仅在拍照添加附件时使用。\n'
                  '所有权限均可通过系统设置随时关闭。'),

              _section('六、儿童隐私'),
              _body('本应用不面向 13 岁以下儿童。我们不会知情地收集儿童的个人信息。'),

              _section('七、联系我们'),
              _body('如有任何关于隐私的疑问或建议，请在应用商店的评论或反馈渠道联系我们。'),
              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.sm),
      child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
    );
  }

  Widget _body(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(text, style: const TextStyle(height: 1.6, fontSize: 14)),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm, left: AppSpacing.sm),
      child: Text(title,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              )),
    );
  }
}
