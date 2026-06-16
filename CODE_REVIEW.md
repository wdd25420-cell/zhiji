# 知记 (Zhiji) 代码审查报告

> 审查日期：2026-06-16 | 审查范围：全部 33 个文件 | 约 6600 行

---

## 1. 审查概要

| 项目 | 结果 |
|------|------|
| 审查文件数 | 33（30 源码 + 3 测试） |
| `flutter analyze` | ✅ 0 error, 0 warning, 1 info |
| `flutter test` | ✅ 42/42 passed |
| P0 严重问题 | 2 |
| P1 中等问题 | 5 |
| P2/P3 轻微问题 | 3 |

---

## 2. 🔴 严重问题 (P0)

### 2.1 `knowledge_editor_screen.dart:168` — `initialValue` 应为 `value`

```dart
// ❌ 当前
DropdownButtonFormField<int>(
  initialValue: _categoryId,

// ✅ 应改为
DropdownButtonFormField<int>(
  value: _categoryId,
```

**影响**：`initialValue` 仅在首次构建时生效，`setState` 后不会更新。编辑已有知识条目时，分类下拉框显示的不是当前已保存的分类。

**文件**：`lib\features\knowledge\knowledge_editor_screen.dart`

---

### 2.2 `common_daos.dart:21-27` — `getOrCreate` 竞态条件

```dart
// ❌ 当前：读-改-写三步非原子
await _db.customStatement('INSERT OR IGNORE INTO tags ...');
final tag = await getByName(name);
final newCount = tag.usageCount + 1;
await (_db.update(_db.tags)...).write(TagsCompanion(usageCount: Value(newCount)));

// ✅ 建议：让 SQLite 原子递增
await _db.customStatement(
  'INSERT INTO tags (name, usage_count) VALUES (?, 1) '
  'ON CONFLICT(name) DO UPDATE SET usage_count = usage_count + 1',
  [name],
);
```

**影响**：多步操作之间存在窗口，并发调用可能导致 `usageCount` 计数不准确。

**文件**：`lib\core\database\daos\common_daos.dart`

---

## 3. 🟡 中等问题 (P1)

### 3.1 `app_database.dart:107-111` — FTS5 knowledge update 触发器缺少 rowid

diary 的 update 触发器包含 `rowid = new.id * 2 + 1`，但 knowledge 的 update 触发器只更新 `title` 和 `body`，未更新 `rowid`：

```sql
-- diary_fts_update ✅
UPDATE search_index SET title = new.title, body = new.body_markdown,
  rowid = new.id * 2 + 1 WHERE source_type = 'diary' AND source_id = old.id;

-- knowledge_fts_update ❌ 缺少 rowid
UPDATE search_index SET title = new.title, body = new.content_markdown
  WHERE source_type = 'knowledge' AND source_id = new.id;
```

**建议**：加上 `rowid = new.id * 2`，并统一 WHERE 子句使用 `old.id`。

**文件**：`lib\core\database\app_database.dart`

---

### 3.2 `knowledge_detail_screen.dart:50-54` — "相关推荐" 名实不符

```dart
Future<List<KnowledgeEntry>> _loadRelated() async {
  ...
  return db.knowledgeDao.listRecent(3);  // 返回最近 3 条，非"相关"
}
```

**建议**：短期改 UI 标签为"最近更新"；长期实现基于标签/分类的关联推荐。

**文件**：`lib\features\knowledge\knowledge_detail_screen.dart`

---

### 3.3 `settings_screen.dart:226-243` — 清除全部数据后分类丢失

`onCreate` 迁移中的 6 个预设分类只在数据库首次创建时写入。清空 `category_models` 表后，分类不会自动恢复。

**建议**：清空后重新执行预设分类 INSERT，或排除 `category_models` 表不删除。

**文件**：`lib\features\settings\settings_screen.dart`

---

### 3.4 `settings_screen.dart:55-100` — 导入导出不完整

- 导出：仅复制到剪贴板，不写入文件；不含标签、情绪、AI 摘要
- 导入：不处理标签和分类；知识条目 `categoryId` 为 null；无 JSON 格式校验

**文件**：`lib\features\settings\settings_screen.dart`

---

### 3.5 `diary_list_screen.dart:18-24` — 筛选依赖硬编码关键词

```dart
case '工作': return entries.where((e) => e.bodyMarkdown.contains('工作')
    || e.bodyMarkdown.contains('产品')).toList();
```

应基于已有的 `diary_tags` + `tags` 表进行筛选。

**文件**：`lib\features\diary\diary_list_screen.dart`

---

## 4. 🟢 轻微问题 (P2/P3)

### 4.1 多处 `Navigator.pushNamed` 与 GoRouter 混用

以下文件使用了 `Navigator.of(context).pushNamed` 而非 GoRouter 的 `context.pushNamed`：

- `home_screen.dart`（3 处）
- `diary_list_screen.dart`（1 处）
- `diary_editor_screen.dart`（1 处）
- `knowledge_browse_screen.dart`（2 处）
- `knowledge_detail_screen.dart`（2 处）
- `search_screen.dart`（1 处）

目前能工作是因为 GoRouter 内部拦截了 Navigator 调用，但属非标准用法。

---

### 4.2 `diary_editor_screen.dart:103-106` — 标签删除 N+1

```dart
// 对每个旧标签逐条 DELETE
for (final ot in oldTagIds) {
  await (db.delete(db.diaryTags)
    ..where((t) => t.diaryEntryId.equals(id) & t.tagId.equals(ot))).go();
}
```

应改为先按 `diaryEntryId` 批量删除，再逐一插入新标签。

**文件**：`lib\features\diary\diary_editor_screen.dart`

---

### 4.3 `knowledge_detail_screen.dart:157` — 残留注释

```dart
// 注释掉 _RelatedEntries
```

**文件**：`lib\features\knowledge\knowledge_detail_screen.dart`

---

## 5. 补充发现

| 文件 | 问题 |
|------|------|
| `AndroidManifest.xml:4` | `android:label="zhiji"`，建议改为 `"知记"` |
| `web/index.html` | title 和 description 仍为默认 Flutter 模板文本 |
| `web/manifest.json` | `name`/`short_name` 为 "zhiji"，`description` 为默认 |
| `gradle.properties` | `org.gradle.java.home` 硬编码本机路径，跨环境失效 |

---

## 6. 正面评价

- **分层架构**：`core/` + `features/` 职责清晰
- **数据库设计**：7 表 + FTS5 全文搜索，触发器自动同步索引，设计精巧
- **测试覆盖**：42 个测试覆盖 CRUD、边界、并发、FTS5、枚举、DioClient
- **主题系统**：MD3 ColorScheme + 完整 Typography/Spacing/Radius/Elevation Token
- **错误处理**：所有 screen 的 async 分支均有 `debugPrint` + 用户友好提示
- **代码生成**：drift DAO + 路由 + Riverpod 均走标准生成流程

---

## 7. 修复优先级建议

1. **立即修复**：P0-1（`initialValue` → `value`）、P0-2（`getOrCreate` 原子性）
2. **尽快修复**：P1-1（FTS5 触发器一致性）、P1-3（清空数据恢复分类）
3. **下个迭代**：P1-2、P1-4、P1-5、P2-1、P2-2

---

*报告由人工逐行审查生成，辅以 `flutter analyze` + `flutter test` 自动化验证。*
