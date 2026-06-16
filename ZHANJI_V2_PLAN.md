# 知记 v2.0 产品化实施计划（可执行版）

> 本文档为可直接交给 Claude / 开发者逐条执行的实施手册。
> 所有内容基于对全部 32 个 Dart 源文件、DAO、主题、路由、构建配置的逐行审查。
> **每一步都标注了：改哪个文件 → 改什么 → 怎么改 → 如何验证。**

---

## 〇、执行总则

1. **严格按阶段顺序执行**。每个阶段结束跑一次 `flutter analyze`，必须 0 error 才进下一阶段。
2. **不升级现有依赖**（riverpod 2.x / go_router 14.x / drift 2.x 均稳定）。本计划只**新增** 3 个依赖。
3. **不改数据库 schema**（不加表/触发器），`schemaVersion` 保持 1。所有新功能靠新增 DAO 查询方法实现，无需 `build_runner` 重新生成。
4. 每个新增的 DAO 方法，按现有测试模式（`test/` 下 in-memory DB）补 1 个单元测试。
5. 中文注释，与现有代码风格一致。

---

## 阶段 0：依赖与环境准备

### 0.1 新增依赖
**文件**：`zhiji_app/pubspec.yaml`

在 `dependencies:` 下新增 3 个包：
```yaml
dependencies:
  # ... 保留现有所有依赖 ...
  fl_chart: ^0.69.0          # 图表（情绪趋势、热力图）
  permission_handler: ^11.3.0 # 运行时权限（麦克风）
```

> ⚠️ **不新增 `image_picker` / `local_auth`**——经产品决策，本期不做图片附件和应用锁。

### 0.2 验证
```cmd
cd /d C:\AI\claudecode\projects\zhiji\zhiji_app
flutter pub get
flutter analyze
```
**通过标准**：pub get 成功，analyze 仍为 0 error（info 警告可暂留）。

---

## 阶段 1：硬 Bug 修复（必做）

### 1.1 深色模式真正生效 🔴

**问题**：`main.dart` 的 `themeMode` 写死，设置页切换后存了 DB 但 `MaterialApp` 不读，导致切换无效。

#### 步骤 a：新建主题 Provider
**新建文件**：`zhiji_app/lib/core/providers/theme_provider.dart`
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import '../database/daos/common_daos.dart';

/// 全局主题模式状态，启动时从 settings_table 恢复
final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>(
  (ref) => ThemeModeNotifier(ref),
);

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier(this._ref) : super(ThemeMode.system) {
    _load();
  }
  final Ref _ref;

  Future<void> _load() async {
    final db = await _ref.read(databaseProvider.future);
    final raw = await SettingsDao(db).getValue('theme_mode');
    state = _parse(raw);
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    final db = await _ref.read(databaseProvider.future);
    await SettingsDao(db).setValue('theme_mode', _key(mode));
  }

  static ThemeMode _parse(String? raw) => switch (raw) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
  static String _key(ThemeMode m) => switch (m) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        _ => 'system',
      };
}
```

#### 步骤 b：让 MaterialApp 响应主题
**文件**：`zhiji_app/lib/main.dart`

把 `ZhijiApp` 从 `StatelessWidget` 改为 `ConsumerWidget`，监听 provider：
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/providers/theme_provider.dart';
// ... 其它 import

class ZhijiApp extends ConsumerWidget {
  const ZhijiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      title: '知记',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,        // ← 关键：响应式读取
      routerConfig: appRouter,
    );
  }
}
```

#### 步骤 c：设置页切换立即生效
**文件**：`zhiji_app/lib/features/settings/settings_screen.dart`

把 `_themeMode` 字段（约 247-263 行）的 `onTap` 改为调用 provider，删除"重启App生效"提示：
```dart
// onTap 内：
final modes = [ThemeMode.system, ThemeMode.light, ThemeMode.dark];
final labels = ['跟随系统', '浅色', '深色'];
final current = modes.indexOf(ref.read(themeModeProvider));
final next = modes[(current + 1) % 3];
ref.read(themeModeProvider.notifier).set(next);
setState(() {});  // 仅刷新本页副标题显示
// 删除原 "已切换为X，重启App生效" 的 SnackBar
```
> 设置页已是 `ConsumerStatefulWidget`，可直接用 `ref`。subtitle 显示用 `ref.watch(themeModeProvider)` 映射成中文。

#### 验证
- `flutter analyze` 0 error
- 手动：设置页点深色 → 界面立即变深；杀进程重开 → 仍是深色。

---

### 1.2 语音权限修复 🔴

**问题**：`AndroidManifest.xml` 无 `RECORD_AUDIO`，语音按钮必然失败。

#### 步骤 a：声明权限
**文件**：`zhiji_app/android/app/src/main/AndroidManifest.xml`
在 `<uses-permission android:name="android.permission.INTERNET"/>` 下一行加：
```xml
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
```

#### 步骤 b：运行时申请
**文件**：`zhiji_app/lib/core/widgets/voice_input_button.dart`

在 `_toggleListening` 方法开头（`if (!_available)` 之前）插入权限检查：
```dart
Future<void> _toggleListening() async {
  // 新增：运行时权限
  final mic = await Permission.microphone.request();
  if (!mic.isGranted) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('需要麦克风权限才能使用语音输入')),
    );
    return;
  }
  if (!_available) { /* 保留原逻辑 */ }
  // ... 其余不变
}
```
文件顶部加 `import 'package:permission_handler/permission_handler.dart';`

#### 验证
- `flutter analyze` 0 error
- 手动：编辑器点麦克风 → 弹权限框 → 允许 → 出现"正在聆听"。

---

### 1.3 标签筛选改为基于关联表 🔴

**问题**：`diary_list_screen.dart:28` 用 `bodyMarkdown.contains(filter)` 假筛选，标签系统形同虚设。

#### 步骤 a：DiaryDao 加按标签查询
**文件**：`zhiji_app/lib/core/database/daos/diary_dao.dart`

在 `search` 方法后新增（DiaryDao 已声明 `tables: [DiaryEntries, DiaryTags, Tags]`，可直接 join）：
```dart
/// 查询包含指定标签的所有日记（按创建时间倒序）
Future<List<DiaryEntry>> listByTag(int tagId) {
  final query = select(diaryEntries).join()
    ..where(diaryTags.tagId.equals(tagId))
    ..orderBy([OrderingTerm.desc(diaryEntries.createdAt)]);
  // join diaryTags
  query.join(
    innerJoin(diaryTags, diaryTags.diaryEntryId.equals(diaryEntries.id)),
  );
  return query.map((row) => row.readTable(diaryEntries)).get();
}
```
> 注意：drift 的 join 写法，需 `innerJoin` 把 diaryTags 显式连进来。如果上面 join 语法报错，改用 `customSelect` 写原生 SQL：
> ```dart
> Future<List<DiaryEntry>> listByTag(int tagId) async {
>   final rows = await customSelect(
>     'SELECT d.* FROM diary_entries d '
>     'INNER JOIN diary_tags t ON t.diary_entry_id = d.id '
>     'WHERE t.tag_id = ? ORDER BY d.created_at DESC',
>     variables: [Variable.withInt(tagId)],
>     readsFrom: [diaryEntries],
>   ).get();
>   return rows.map((r) => r.readTable(diaryEntries)).toList();
> }
> ```
> **优先用 customSelect 版本，最稳。**

#### 步骤 b：替换列表筛选逻辑
**文件**：`zhiji_app/lib/features/diary/diary_list_screen.dart`

把 `_applyFilter`（22-30 行）整体替换为**异步**逻辑。由于要查 DB，改为在 StreamBuilder 里处理：
```dart
// 删除原 _applyFilter 同步方法
// 在 StreamBuilder 的 builder 里：
builder: (ctx, snap) async {
  final entries = snap.data ?? [];
  // ...
  final filtered = _filter == '全部'
      ? entries
      : _filter == 'AI 已分析'
          ? entries.where((e) => e.aiSummary != null).toList()
          : await _filterByTag(entries);  // 异步按标签
  // ...
}

Future<List<DiaryEntry>> _filterByTag(List<DiaryEntry> all) async {
  final db = await ref.read(databaseProvider.future);
  final tag = await TagDao(db).getByName(_filter);
  if (tag == null) return [];
  final ids = (await db.diaryDao.listByTag(tag.id)).map((e) => e.id).toSet();
  return all.where((e) => ids.contains(e.id)).toList();
}
```
> 因为 `FutureBuilder` 内不能直接 await，实际实现建议：把筛选结果缓存为 state，或在 `_buildFilterChips` 选定标签后立即触发一次查询存到 `_filteredEntries`，UI 只渲染它。**推荐后者**——更符合现有 setState 模式。

#### 验证
- 新增测试 `test/tag_filter_test.dart`：建 2 篇日记，给其中 1 篇打"工作"标签（正文不写"工作"二字），断言 `listByTag` 只返回那 1 篇。
- 手动：给日记打标签 → 列表选该标签 → 正确筛出，哪怕正文不含标签名。

---

### 1.4 清空数据保留设置 + 导入分类映射 🟡

#### 步骤 a：清空数据不删设置表
**文件**：`zhiji_app/lib/features/settings/settings_screen.dart`（约 347-355 行事务内）

**删除**这一行：
```dart
await db.delete(db.settingsTable).go();  // ← 删掉
```
确认对话框文案（约 338 行）改为：
```dart
content: const Text('将清除所有日记和知识条目（保留你的设置与 API Key），确定吗？'),
```

#### 步骤 b：导出/导入按分类名映射
**导出**（`_exportData`，约 78 行 data map）：categories 已存 name+icon，✓ 保持。
**导入**（`_importData`，约 170 行）：把 `categoryId` 直接写入改为按名查找/创建：
```dart
// 导入知识时：
int? resolvedCatId;
if (k['categoryName'] != null) {
  // 先在已导入的分类里找
  final existing = await db.knowledgeDao.listCategories();
  final found = existing.where((c) => c.name == k['categoryName']).firstOrNull;
  if (found != null) resolvedCatId = found.id;
}
// 用 resolvedCatId 替代原来的 categoryId
```
> 同时：**导出时 knowledge 条目增加 `categoryName` 字段**（在 `_exportData` 的 knowledges map 里加 `'categoryName': categories.where((c)=>c.id==k.categoryId).firstOrNull?.name`）。

#### 验证
- 手动：导出 → 清空数据 → API Key 仍在 → 导入 → 分类正确归位。

---

## 阶段 2：编辑体验升级

### 2.1 Markdown 格式工具栏

**新建文件**：`zhiji_app/lib/core/widgets/markdown_toolbar.dart`

一个可复用的 StatefulWidget，对传入的 `TextEditingController` 操作：
```dart
class MarkdownToolbar extends StatelessWidget {
  const MarkdownToolbar({super.key, required this.controller});
  final TextEditingController controller;

  /// 对选中文本包裹前后缀（如 **bold**），无选中则插入占位
  void _wrap(String prefix, [String suffix]) {
    suffix ??= prefix;
    final t = controller.text;
    final sel = controller.selection;
    if (!sel.isValid || sel.start == sel.end) {
      // 无选中：插入 prefix+placeholder+suffix
      final placeholder = '文本';
      final insert = '$prefix$placeholder$suffix';
      controller.value = TextEditingValue(
        text: t.replaceRange(sel.start, sel.end, insert),
        selection: TextSelection.collapsed(offset: sel.start + prefix.length + placeholder.length),
      );
    } else {
      final selected = t.substring(sel.start, sel.end);
      final replaced = '$prefix$selected$suffix';
      controller.value = TextEditingValue(
        text: t.replaceRange(sel.start, sel.end, replaced),
        selection: TextSelection(baseOffset: sel.start, extentOffset: sel.start + replaced.length),
      );
    }
  }

  void _prefixLine(String prefix) {
    // 在当前行首加前缀（#、-、>）
    final t = controller.text;
    final sel = controller.selection;
    final lineStart = t.lastIndexOf('\n', sel.start - 1) + 1;
    controller.value = TextEditingValue(
      text: t.replaceRange(lineStart, lineStart, prefix),
      selection: TextSelection.collapsed(offset: sel.start + prefix.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 0,
      children: [
        _btn(Icons.format_bold, () => _wrap('**')),
        _btn(Icons.format_italic, () => _wrap('*')),
        _btn(Icons.title, () => _prefixLine('### ')),
        _btn(Icons.format_list_bulleted, () => _prefixLine('- ')),
        _btn(Icons.format_quote, () => _prefixLine('> ')),
        _btn(Icons.code, () => _wrap('`')),
      ],
    );
  }

  Widget _btn(IconData icon, VoidCallback onTap) =>
      IconButton(icon: Icon(icon, size: 20), onPressed: onTap, visualDensity: VisualDensity.compact);
}
```

**接入**：`diary_editor_screen.dart` 和 `knowledge_editor_screen.dart` 的工具栏 Row（约 244 行），在语音/附件按钮和 Spacer 之间插入：
```dart
const SizedBox(width: AppSpacing.sm),
MarkdownToolbar(controller: _bodyCtrl),
```

### 2.2 AI 续写/润色（选中文本）

**文件**：`zhiji_app/lib/core/network/ai_api_service.dart`，新增方法：
```dart
/// AI 续写：基于已有内容续写下文
static Future<String?> continueWriting(String context) async {
  // POST /v1/chat/completions，system: "你是写作助手，请续写用户的内容，风格保持一致，200字内"
  // 返回 choices[0].message.content
}

/// AI 润色：优化选中段落的表达
static Future<String?> polish(String selection) async {
  // system: "请润色优化以下文字，保持原意，使其更流畅"
}

/// AI 总结：把长文压成要点
static Future<String?> summarize(String selection) async {
  // system: "请用要点形式总结以下内容"
}
```
> 三个方法复用同一 `_post` 私有方法（封装 baseUrl + model + 解析），避免重复。

**接入编辑器**：在工具栏 MarkdownToolbar 旁加一个"AI"下拉按钮（PopupMenuButton），选项「续写/润色/总结」，对 `_bodyCtrl` 当前选区调用，结果**替换选区**（续写则追加到末尾）。loading 时按钮转圈。

#### 验证
- `flutter analyze` 0 error
- 手动：选中一段 → 点润色 → 内容被替换；点续写 → 末尾追加。

---

## 阶段 3：首页仪表盘 + 数据可视化

### 3.1 新增统计查询 DAO 方法

**文件**：`zhiji_app/lib/core/database/daos/diary_dao.dart`，新增聚合方法（用 `customSelect` + `GROUP BY`）：
```dart
/// 按情绪分组计数
Future<Map<String, int>> countByEmotion() async {
  final rows = await customSelect(
    'SELECT emotion, COUNT(*) as c FROM diary_entries '
    'WHERE emotion IS NOT NULL GROUP BY emotion',
    readsFrom: [diaryEntries],
  ).get();
  return {for (final r in rows) r.read<String>('emotion'): r.read<int>('c')};
}

/// 当前连续记录天数（从今天往前数，遇到断档即停）
Future<int> currentStreak() async {
  final rows = await customSelect(
    "SELECT DISTINCT date(created_at/1000,'unixepoch','localtime') as d "
    "FROM diary_entries ORDER BY d DESC",
    readsFrom: [diaryEntries],
  ).get();
  if (rows.isEmpty) return 0;
  // 在 Dart 里算连续天数（更易处理跨天边界）
  final days = rows.map((r) => r.read<String>('d')).toSet();
  var streak = 0;
  var cursor = DateTime.now();
  for (;;) {
    final key = '${cursor.year}-${cursor.month.toString().padLeft(2,'0')}-${cursor.day.toString().padLeft(2,'0')}';
    if (days.contains(key)) { streak++; cursor = cursor.subtract(const Duration(days:1)); }
    else break;
  }
  return streak;
}

/// 本周（近7天）总字数
Future<int> wordCountThisWeek() async {
  final since = DateTime.now().subtract(const Duration(days:7)).millisecondsSinceEpoch;
  final rows = await customSelect(
    'SELECT COALESCE(SUM(LENGTH(body_markdown)),0) as w FROM diary_entries WHERE created_at >= ?',
    variables: [Variable.withInt(since)],
    readsFrom: [diaryEntries],
  ).get();
  return rows.first.read<int>('w');
}

/// 最近 N 天每天的条目数（热力图用）
Future<Map<String,int>> countByDay(int days) async {
  final since = DateTime.now().subtract(Duration(days:days)).millisecondsSinceEpoch;
  final rows = await customSelect(
    "SELECT date(created_at/1000,'unixepoch','localtime') as d, COUNT(*) as c "
    "FROM diary_entries WHERE created_at >= ? GROUP BY d",
    variables: [Variable.withInt(since)],
    readsFrom: [diaryEntries],
  ).get();
  return {for (final r in rows) r.read<String>('d'): r.read<int>('c')};
}
```
> ⚠️ drift 的 `customSelect` 列名用**下划线形式**（`body_markdown` 而非 `bodyMarkdown`），对应 SQLite 实际列名。

### 3.2 情绪趋势图组件

**新建文件**：`zhiji_app/lib/features/home/widgets/emotion_trend_chart.dart`

用 `fl_chart` 的 `LineChart`，X 轴最近 7 天，Y 轴该天记录的情绪数量（或情绪强度）。简化版：直接画 7 天每天日记条数的柱状图 + 每天主导情绪 emoji 标注。

```dart
class EmotionTrendChart extends ConsumerWidget {
  // 读取 countByDay(7) + countByEmotion()
  // 用 fl_chart BarChart 渲染
}
```
> 图表配色用 `Theme.of(context).colorScheme.primary` 系列，不硬编码颜色。

### 3.3 写作热力图组件

**新建文件**：`zhiji_app/lib/features/home/widgets/writing_heatmap.dart`

GitHub 风格 12 周 × 7 天网格，用 `GridView` 或 `CustomPaint`：
```dart
class WritingHeatmap extends ConsumerWidget {
  // 读取 countByDay(84)（12周）
  // 每个格子颜色深浅按条目数：0=灰、1-2=浅绿、3+=深绿（用 colorScheme.primary 的不同 opacity）
}
```

### 3.4 首页改造

**文件**：`zhiji_app/lib/features/home/home_screen.dart`

1. **右上角人物图标改搜索**（约 27 行）：
   ```dart
   IconButton(icon: const Icon(Icons.search), onPressed: () => context.push('/search')),
   ```
   （设置交给底部 Tab，去掉重复入口）

2. **统计卡从 2 个扩到 4 个**（约 72-78 行）：日记数 / 知识数 / **连续记录天数** / **本周字数**。把 `_StatCard` 的 `Row` 改成 2×2 网格或横滑。

3. **新增两个卡片**（在"最近更新"上方）：
   - `EmotionTrendChart()` 情绪趋势
   - `WritingHeatmap()` 写作热力图

4. **"最近更新"合并日记+知识**：当前 `_RecentEntries` 只读 diary（约 186 行）。改为同时读 `db.knowledgeDao.listRecent(3)`，按 `createdAt` 混合排序，badge 区分"日记/知识"。

#### 验证
- 新增测试 `test/stats_test.dart`：插入若干日记，断言 `countByEmotion` / `currentStreak` / `wordCountThisWeek` 返回正确。
- 手动：首页能看到 4 个统计 + 趋势图 + 热力图，连续记录天数正确。

---

## 阶段 4：AI 能力扩展

### 4.1 AI 服务统一重构

**文件**：`zhiji_app/lib/core/network/ai_api_service.dart`

抽取私有 `_post` 方法，所有 AI 调用复用，统一超时与错误处理：
```dart
static Future<String?> _post(String systemPrompt, String userContent, {int maxTokens = 500}) async {
  final dio = AppDio.instance;
  try {
    final response = await dio.post('$_baseUrl/v1/chat/completions', data: {
      'model': _model,
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': userContent},
      ],
      'temperature': 0.5,
      'max_tokens': maxTokens,
      'stream': false,
    }).timeout(const Duration(seconds: 30));
    final choices = (response.data['choices'] as List);
    if (choices.isEmpty) return null;
    return choices[0]['message']['content'] as String?;
  } on DioException catch (e) {
    // 区分：401=无Key/Key错、429=配额、其它=网络
    debugPrint('AI request failed: $e');
    return null;
  } catch (e) {
    debugPrint('AI error: $e');
    return null;
  }
}
```
把现有 `analyzeDiary` / `analyzeKnowledge` 改为调用 `_post` + 解析 JSON。

### 4.2 每日回顾

**文件**：`ai_api_service.dart` 新增：
```dart
/// 基于本周所有日记生成回顾
static Future<String?> weeklyReview(List<DiaryEntry> diaries) async {
  if (diaries.isEmpty) return null;
  final content = diaries.map((d) =>
    '[${d.createdAt.month}/${d.createdAt.day} ${d.emotion ?? ''}] ${d.title}: ${d.bodyMarkdown}'
  ).join('\n\n');
  return _post(
    '你是日记回顾助手。请基于用户本周日记，总结情绪模式、主要主题、并给出 1-2 条积极建议。300字内。',
    content,
    maxTokens: 800,
  );
}
```

**接入**：首页"DeepSeek 洞察"卡片（约 80-105 行）改为可点击，点击后弹 BottomSheet 或新路由展示 `weeklyReview` 结果。loading 用 `LinearProgressIndicator`。

### 4.3 智能问答（知识库 RAG）

**方案**：FTS5 检索 + 长上下文。用户提问 → 分词 → `db.search()` 取 Top 5 相关知识 → 拼进 prompt → DeepSeek 回答 + 标注引用来源。**不引入向量库。**

**新建文件**：`zhiji_app/lib/features/ai/knowledge_chat_screen.dart`

气泡式对话界面：
```dart
class KnowledgeChatScreen extends ConsumerStatefulWidget {
  // 消息列表 List<_Message>（含 role: user/assistant、text、sources: List<KnowledgeEntry>）
  // 底部输入框，发送后：
  //   1. db.search(question) 取 5 条知识
  //   2. 拼 context 调 AIService.askKnowledge()
  //   3. 流式/非流式显示回答 + 下方列出引用（点击跳 /knowledge/:id）
}
```

**文件**：`ai_api_service.dart` 新增：
```dart
/// 知识库问答：基于检索到的相关条目回答
static Future<({String answer, List<int> sourceIds})?> askKnowledge(
  String question, List<KnowledgeEntry> context,
) async {
  if (context.isEmpty) return null;
  final contextText = context.map((k) =>
    '【${k.title}】\n${k.contentMarkdown}'
  ).join('\n---\n');
  final answer = await _post(
    '你是知识助手。基于以下用户知识库内容回答问题。'
    '若内容中没有相关信息，请诚实说"知识库中暂无相关记录"。'
    '回答末尾用 [来源n] 标注引用。\n\n知识库：\n$contextText',
    question,
    maxTokens: 1000,
  );
  if (answer == null) return null;
  return (answer: answer, sourceIds: context.map((k) => k.id).toList());
}
```

**路由**：`zhiji_app/lib/core/router/app_router.dart` 加：
```dart
GoRoute(path: '/ai-chat', builder: (c, s) => const KnowledgeChatScreen()),
```
**入口**：知识库浏览页 AppBar 加"AI 问答"图标按钮。

#### 验证
- 手动：录几条知识 → 进 AI 问答 → 问相关问题 → 回答带引用 → 点引用跳详情。

---

## 阶段 5：体验细节打磨

| # | 文件 | 改动 |
|---|------|------|
| 5.1 | `diary_list_screen.dart` / `knowledge_browse_screen.dart` | 列表项入场动画：包一层 `AnimatedSwitcher` 或 `TweenAnimationBuilder`，fade + 上移 |
| 5.2 | `search_screen.dart` | 搜索结果高亮：`RichText` + `TextSpan`，把查询词片段标红（`colorScheme.primary` + `fontWeight: w600`）。抽一个 `buildHighlighted(text, query)` 工具函数 |
| 5.3 | `knowledge_detail_screen.dart` | "最近更新"假推荐改真推荐：`knowledge_dao.dart` 加 `listRelatedByTags(entryId, tagIds)`（查有共同标签的其它知识，排除自身，limit 3）；detail 页调用它 |
| 5.4 | `empty_state.dart` 各调用处 | 空状态加引导按钮：EmptyState 已有 `actionLabel`+`onAction` 字段但未用，在日记/知识库空列表处传"立即创建"→跳编辑器 |
| 5.5 | `knowledge_browse_screen.dart` | 确认有 `RefreshIndicator`（代码已有，116 行），✓ 无需改 |

#### 验证
- `flutter analyze` 0 error
- 手动：列表有入场动画、搜索词高亮、知识详情推荐相关。

---

## 阶段 6：交付工程化

### 6.1 构建环境修复

**文件**：`zhiji_app/android/gradle.properties`

删除硬编码 JDK 路径，改用环境变量：
```properties
# 删除这行：org.gradle.java.home=C:/Program Files/Android/Android Studio/jbr
# 改为（或不写，让 Gradle 用 JAVA_HOME）：
org.gradle.java.home=${JAVA_HOME}
```
> 如果 `${JAVA_HOME}` 在 properties 里不展开，直接删掉这行，确保系统 `JAVA_HOME` 指向 JDK 17。

### 6.2 Release 自签名（内测用）

**新建文件**：`zhiji_app/android/key.properties`（加入 .gitignore）
```properties
storePassword=zhiji_keystore
keyPassword=zhiji_keystore
keyAlias=zhiji
storeFile=keystore/zhiji.jks
```

**生成 keystore**（执行一次，命令）：
```cmd
cd /d C:\AI\claudecode\projects\zhiji\zhiji_app\android
mkdir keystore
"C:\Program Files\Android\Android Studio\jbr\bin\keytool" -genkey -v -keystore keystore\zhiji.jks -keyalg RSA -keysize 2048 -validity 10000 -alias zhiji -storepass zhiji_keystore -keypass zhiji_keystore -dname "CN=Zhiji, OU=Dev, O=Zhiji, L=CN, ST=CN, C=CN"
```

**文件**：`zhiji_app/android/app/build.gradle.kts`，在 `android { }` 块内、`buildTypes` 前加：
```kotlin
val keystoreProperties = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) load(FileInputStream(f))
}
signingConfigs {
    create("release") {
        keyAlias = keystoreProperties["keyAlias"] as String?
        keyPassword = keystoreProperties["keyPassword"] as String?
        storeFile = keystoreProperties["storeFile"]?.let { file(it as String) }
        storePassword = keystoreProperties["storePassword"] as String?
    }
}
buildTypes {
    release {
        signingConfig = signingConfigs.getByName("release")  // ← 改这里
        isMinifyEnabled = true
        isShrinkResources = true
        proguardFiles(
            getDefaultProguardFile("proguard-android-optimize.txt"),
            "proguard-rules.pro"
        )
    }
}
```
顶部加 `import java.util.Properties` 和 `import java.io.FileInputStream`。

**文件**：`zhiji_app/android/app/proguard-rules.pro`，确保 Drift 不被混淆（追加）：
```
-keep class * extends com.squareup.moshi.JsonAdapter { *; }
-dontwarn io.flutter.embedding.**
-keep class app.fwk.** { *; }
# Drift 生成的代码
-keep class com.zhiji.zhiji.database.** { *; }
-keep class * implements androidx.sqlite.db.SupportSQLiteOpenHelper { *; }
```

### 6.3 应用图标

**新建文件**：`zhiji_app/flutter_launcher_icons.yaml`
```yaml
flutter_launcher_icons:
  android: true
  ios: false
  image_path: "assets/icon.png"   # 1024x1024 源图
  adaptive_icon_background: "#00897B"
  adaptive_icon_foreground: "assets/icon_fg.png"
  min_sdk_android: 21
```
> 需要先在 `pubspec.yaml` 的 `dev_dependencies` 加 `flutter_launcher_icons: ^0.14.0`，并在项目根放一张 1024×1024 的 `assets/icon.png`（用主色 #00897B + 白色"知"字，可用任意工具生成占位）。
> 然后执行 `dart run flutter_launcher_icons`。

### 6.4 Web 元信息（顺带）

**文件**：`zhiji_app/web/index.html` 的 `<title>` 改为「知记」；
**文件**：`zhiji_app/web/manifest.json` 的 name/short_name/description 改为「知记」相关文案。

### 6.5 最终打包验证

```cmd
cd /d C:\AI\claudecode\projects\zhiji\zhiji_app
flutter analyze          # 必须 0 error
flutter test             # 现有 42 + 新增测试，全过
flutter build apk --release --split-per-abi
```
**通过标准**：
- analyze 0 error
- test 全过
- 产出 3 个 APK（arm64-v8a / armeabi-v7a / x86_64），每个 < 30MB
- 装到 BlueStacks（x86_64 版）能启动、核心功能正常

---

## 阶段执行顺序（推荐）

```
阶段0 → 阶段1 → flutter analyze
         ↓
   阶段6.1（环境修复，确保能编译）
         ↓
   阶段2（编辑体验）→ flutter analyze
         ↓
   阶段3（可视化）→ flutter analyze + 新测试
         ↓
   阶段4（AI）→ flutter analyze
         ↓
   阶段5（打磨）→ flutter analyze
         ↓
   阶段6.2~6.5（签名/图标/打包）
```

---

## 完整改动文件清单

| 阶段 | 修改文件 | 新增文件 |
|------|---------|---------|
| 0 | pubspec.yaml | — |
| 1.1 | main.dart, settings_screen.dart | theme_provider.dart |
| 1.2 | AndroidManifest.xml, voice_input_button.dart | — |
| 1.3 | diary_dao.dart, diary_list_screen.dart | tag_filter_test.dart |
| 1.4 | settings_screen.dart | — |
| 2 | ai_api_service.dart, diary_editor_screen.dart, knowledge_editor_screen.dart | markdown_toolbar.dart |
| 3 | diary_dao.dart, home_screen.dart | emotion_trend_chart.dart, writing_heatmap.dart, stats_test.dart |
| 4 | ai_api_service.dart, app_router.dart, home_screen.dart, knowledge_browse_screen.dart | knowledge_chat_screen.dart |
| 5 | search_screen.dart, knowledge_detail_screen.dart, knowledge_dao.dart, diary_list_screen.dart, knowledge_browse_screen.dart | — |
| 6 | build.gradle.kts, gradle.properties, proguard-rules.pro, web/index.html, web/manifest.json, pubspec.yaml | key.properties, flutter_launcher_icons.yaml, assets/icon.png |

**合计：约 18 个文件修改 + 6 个新文件 + 2 个测试文件**

---

## 执行后需人工确认的事项

1. **应用图标源图**：需要一张 1024×1024 的 `assets/icon.png`。无设计稿时，用主色 #00897B 背景 + 白色"知"字生成占位。
2. **DeepSeek API Key**：测试 AI 三件套（续写/回顾/问答）需真实 Key。可在 settings 页手动输入。
3. **Release keystore 密码**：文档用占位 `zhiji_keystore`，正式分发前自行更换。

---

*文档结束。Claude 可从阶段 0 开始逐条执行，每阶段完成后回报 analyze 与 test 结果。*
