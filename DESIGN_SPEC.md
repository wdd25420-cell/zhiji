# 设计规格 — 知记 Flutter 移植

> 基于：`C:\Users\Administrator\AppData\Roaming\Open Design\namespaces\release-stable-win\data\projects\55a9b35d-3459-41a4-87e8-fc905e72b094\`

---

## 一、设计 Token → Flutter ThemeData 映射

### 1.1 色彩系统

来源：[`css/tokens.css`](C:\Users\Administrator\AppData\Roaming\Open Design\namespaces\release-stable-win\data\projects\55a9b35d-3459-41a4-87e8-fc905e72b094\css\tokens.css)

| CSS Token (OKLch) | 用途 | Flutter ColorScheme 角色 | sRGB 近似值 |
|---|---|---|---|
| `--accent: oklch(56% 0.12 170)` | 主色 | `primary` | `#00897B` |
| `--primary-container: oklch(95% 0.04 170)` | 主色容器 | `primaryContainer` | `#B2DFDB` |
| `--on-primary: oklch(100% 0 0)` | 主色上文字 | `onPrimary` | `#FFFFFF` |
| `--on-primary-container: oklch(25% 0.06 170)` | 容器上文字 | `onPrimaryContainer` | `#00352D` |
| `--surface: oklch(100% 0 0)` | 页面背景 | `surface` | `#FFFFFF` |
| `--surface-dim: oklch(93% 0.004 240)` | 暗色表面 | `surfaceDim` | `#E8E8EC` |
| `--surface-container-low: oklch(97% 0.005 240)` | 低表面容器 | `surfaceContainerLow` | `#F3F3F7` |
| `--surface-container: oklch(95% 0.006 240)` | 普通表面容器 | `surfaceContainer` | `#EDEDF1` |
| `--surface-container-high: oklch(92% 0.007 240)` | 高表面容器 | `surfaceContainerHigh` | `#E1E1E5` |
| `--surface-container-highest: oklch(89% 0.008 240)` | 最高表面容器 | `surfaceContainerHighest` | `#D6D6DA` |
| `--secondary: oklch(60% 0.06 250)` | 辅色 | `secondary` | `#4A6FA5` |
| `--tertiary: oklch(58% 0.14 40)` | 第三色 | `tertiary` | `#BF6A02` |
| `--error: oklch(50% 0.20 20)` | 错误色 | `error` | `#BA1A1A` |
| `--bg: oklch(98% 0.004 240)` | 全局背景 | `surface` | `#FAFAFC` |
| `--fg: oklch(20% 0.02 240)` | 前景文字 | `onSurface` | `#1C1B1F` |
| `--muted: oklch(50% 0.018 240)` | 次要文字 | `onSurfaceVariant` | `#6B6B73` |
| `--border: oklch(90% 0.006 240)` | 边框 | `outlineVariant` | `#DEDEE4` |

**实现方法**：
```dart
// 从 seed color 生成完整色板
ColorScheme.fromSeed(
  seedColor: const Color(0xFF00897B),  // accent → primary seed
  brightness: Brightness.light,
)
```

### 1.2 排版层级

来源：[`css/tokens.css:48-67`](C:\Users\Administrator\AppData\Roaming\Open Design\namespaces\release-stable-win\data\projects\55a9b35d-3459-41a4-87e8-fc905e72b094\css\tokens.css:48)

| CSS 变量 | 字号 (clamp) | 字重 | Flutter TextTheme 角色 |
|---|---|---|---|
| `--fs-display-sm` | 1.5~2.25rem | 700 | `displaySmall` |
| `--fs-headline-lg` | 1.25~2rem | — | `headlineLarge` |
| `--fs-headline-md` | 1.125~1.75rem | — | `headlineMedium` |
| `--fs-headline-sm` | 1~1.5rem | — | `headlineSmall` |
| `--fs-title-lg` | 1.125~1.375rem | 600 | `titleLarge` |
| `--fs-title-md` | 1rem | — | `titleMedium` |
| `--fs-title-sm` | 0.875rem | — | `titleSmall` |
| `--fs-body-lg` | 1rem | — | `bodyLarge` |
| `--fs-body-md` | 0.9375rem | — | `bodyMedium` |
| `--fs-body-sm` | 0.8125rem | — | `bodySmall` |
| `--fs-label-lg` | 0.875rem | 500 | `labelLarge` |
| `--fs-label-md` | 0.75rem | — | `labelMedium` |
| `--fs-label-sm` | 0.6875rem | — | `labelSmall` |

**字体族**：
- Display 标题：`'Söhne', 'Avenir Next', system-ui` → 对应 `textTheme.displaySmall?.copyWith(fontFamily: ...)`
- Body 正文：`system-ui, 'SF Pro Text', 'Roboto'` → 默认
- Mono 等宽：`'JetBrains Mono', ui-monospace` → 代码块

### 1.3 间距 Token（4dp grid）

来源：[`css/tokens.css:70-79`](C:\Users\Administrator\AppData\Roaming\Open Design\namespaces\release-stable-win\data\projects\55a9b35d-3459-41a4-87e8-fc905e72b094\css\tokens.css:70)

| Token | 值 | Token | 值 | Token | 值 |
|---|---|---|---|---|---|
| `sp-1` | 4 | `sp-5` | 20 | `sp-10` | 40 |
| `sp-2` | 8 | `sp-6` | 24 | `sp-12` | 48 |
| `sp-3` | 12 | `sp-8` | 32 | | |
| `sp-4` | 16 | | | | |

### 1.4 圆角层级（MD3 shape）

来源：[`css/tokens.css:81-88`](C:\Users\Administrator\AppData\Roaming\Open Design\namespaces\release-stable-win\data\projects\55a9b35d-3459-41a4-87e8-fc905e72b094\css\tokens.css:81)

| Token | 值 | 用途 |
|---|---|---|
| `r-none` | 0 | — |
| `r-xs` | 4 | 标签 |
| `r-sm` | 8 | 按钮、输入框 |
| `r-md` | 12 | 小卡片 |
| `r-lg` | 16 | 卡片 |
| `r-xl` | 24 | 大卡片/弹窗 |
| `r-full` | 9999 | 药丸形状 |

### 1.5 阴影层级（MD3 elevation）

来源：[`css/tokens.css:90-95`](C:\Users\Administrator\AppData\Roaming\Open Design\namespaces\release-stable-win\data\projects\55a9b35d-3459-41a4-87e8-fc905e72b094\css\tokens.css:90)

| Token | 用途 |
|---|---|
| `elev-0` | 无阴影 |
| `elev-1` | 卡片默认、导航栏 |
| `elev-2` | 悬浮态卡片、FAB |
| `elev-3` | 对话框 |
| `elev-4` | 设备外框、最大层级 |

---

## 二、组件映射

来源：[`css/components.css`](C:\Users\Administrator\AppData\Roaming\Open Design\namespaces\release-stable-win\data\projects\55a9b35d-3459-41a4-87e8-fc905e72b094\css\components.css)

| # | HTML/CSS 组件 | Flutter Widget | 说明 |
|---|---|---|---|
| 1 | `.app-shell` / `.app-frame` | `Scaffold` + `SafeArea` | 应用壳，模拟 412×915 手机屏幕 |
| 2 | `.status-bar` | `MediaQuery.padding.top` | 状态栏区域，Flutter 原生处理 |
| 3 | `.top-bar` | `AppBar` (MD3) | 顶部导航栏 |
| 4 | `.top-bar-back` | `AppBar.leading` → BackButton | 返回按钮 |
| 5 | `.top-bar-title` | `AppBar.title` | 标题文字 |
| 6 | `.top-bar-action` | `AppBar.actions` | 右侧操作按钮 |
| 7 | `.top-bar-avatar` | `CircleAvatar` | 用户头像 |
| 8 | `.bottom-nav` | `NavigationBar` (MD3) | 底部导航，4 个 Tab |
| 9 | `.nav-item` | `NavigationDestination` | 单个 Tab 项 |
| 10 | `.content` | `ListView` / `SingleChildScrollView` | 可滚动内容区 |
| 11 | `.stat-card` | `Card` + `Column` | 统计数字卡片 ×4 |
| 12 | `.stats-row` | `Row` + `Expanded` ×4 | 统计卡片横排 |
| 13 | `.entry-card` | `Card` + `ListTile` | 日记/知识条目卡片 |
| 14 | `.entry-card-badge` | `Container` + `Text` (小圆角徽章) | 类型标记（日记/知识） |
| 15 | `.chip` | `ActionChip` / `InputChip` | 标签 |
| 16 | `.filter-chip` | `FilterChip` | 筛选标签（可选中） |
| 17 | `.filter-row` | `SingleChildScrollView` + `FilterChip` group | 横向滚动筛选行 |
| 18 | `.ai-chip` | `ActionChip` + accent 色 | AI 标签（特殊样式） |
| 19 | `.fab` | `FloatingActionButton` | 浮动操作按钮 |
| 20 | `.fab-menu` | `SpeedDial` (flutter_speed_dial) | FAB 展开菜单 |
| 21 | `.fab-backdrop` | `ModalBarrier` / 半透明遮罩 | FAB 菜单遮罩 |
| 22 | `.search-bar` | `SearchBar` (MD3) | 搜索栏（不立即搜索） |
| 23 | `.search-box` | `SearchAnchor` (MD3) | 搜索框（点击展开） |
| 24 | `.snackbar` | `SnackBar` + `SnackBarAction` | Toast 提示 |
| 25 | `.dialog-overlay` | `showDialog` + `AlertDialog` | 确认对话框 |
| 26 | `.dialog` | `AlertDialog` | 对话框内容 |
| 27 | `.btn-filled` | `FilledButton` | 主按钮（确认） |
| 28 | `.btn-text` | `TextButton` | 文字按钮（取消） |
| 29 | `.btn-danger` | `FilledButton` + error 色 | 危险操作按钮 |
| 30 | `.form-group` | `Column` + spacing | 表单组 |
| 31 | `.form-input` | `TextField` | 文本输入 |
| 32 | `.form-textarea` | `TextField(maxLines: null)` | 多行文本输入 |
| 33 | `.form-select` | `DropdownButtonFormField` | 下拉选择 |
| 34 | `.title-input` | `TextField` + large style | 标题输入（大字） |
| 35 | `.editor-area` | `Container` + `TextField` + `Toolbar` | 编辑器容器 |
| 36 | `.editor-textarea` | `TextField(maxLines: null, expands: true)` | 编辑器正文 |
| 37 | `.toolbar` / `.tool-btn` | `Row` + `IconButton` 组 | 富文本工具栏 |
| 38 | `.tool-divider` | `VerticalDivider` | 工具栏分隔线 |
| 39 | `.upload-zone` | `GestureDetector` + `Card` (dashed border) | 文件拖放上传区 |
| 40 | `.file-item` | `ListTile` + `Icon` + `Text` + `IconButton` | 文件列表项 |
| 41 | `.tag-editor` | `TextField` + `Wrap` of `InputChip` | 标签输入区域 |
| 42 | `.tag-input-field` | `TextField` + `onSubmitted` | 标签输入框 |
| 43 | `.switch` / `.slider` | `Switch` / `SwitchListTile` | 开关 |
| 44 | `.mood-picker` | `ToggleButtons` / `SegmentedButton` | 情绪选择器（emoji 组） |
| 45 | `.mood-btn` | `IconButton` / `SegmentedButton` segment | 单个情绪按钮 |
| 46 | `.ai-panel` | `Card` (primaryContainer) | AI 分析面板 |
| 47 | `.ai-tip` | `Card` + `Row` | AI 建议卡片 |
| 48 | `.ai-spinner` | `CircularProgressIndicator` | AI 加载动画 |
| 49 | `.ai-result` | `Column` of `Text` + `Wrap` of `ActionChip` | AI 分析结果 |
| 50 | `.ai-toggle` | `SwitchListTile` | AI 功能开关 |
| 51 | `.empty-state` | `Column` + `Icon` + `Text` | 空状态占位 |
| 52 | `.graph-canvas` | `CustomPaint` + `CustomPainter` | 知识图谱 Canvas |
| 53 | `.graph-legend` | `Row` of `Container` dots | 图谱图例 |
| 54 | `.view-toggle` | `SegmentedButton` (2 段) | 列表/图谱视图切换 |
| 55 | `.cat-card` / `.cat-grid` | `GridView` 2 列 | 分类卡片网格 |
| 56 | `.section-header` / `.section-title` | `ListTile` + `TextButton` | 分区标题 + 查看更多 |
| 57 | `.article-header` | `Column` of `Text` | 文章标题区 |
| 58 | `.article-body` | `flutter_markdown` | Markdown 内容渲染 |
| 59 | `.ai-summary-card` | `Card` (primaryContainer) | AI 摘要卡片 |
| 60 | `.ai-keyword` | `ActionChip` (small, accent 背景) | 关键词云 |
| 61 | `.attachment-card` | `ListTile` + `IconButton` | 附件卡片 |
| 62 | `.related-item` | `ListTile` + prefix + suffix | 关联推荐项 |
| 63 | `.result-item` | `Card` + `Text` (highlighted) | 搜索结果项 |
| 64 | `.search-history` | `Column` + `Wrap` of `ActionChip` | 搜索历史 |
| 65 | `.suggestion-item` | `ListTile` | 搜索建议 |
| 66 | `.settings-group` | `Column` + `ListTile` group | 设置分组 |
| 67 | `.settings-card` | `Card` | 设置卡片 |
| 68 | `.settings-item` | `ListTile` | 设置项 |
| 69 | `.stagger-list` | `AnimatedList` / delay-based animation | 交错入场列表 |
| 70 | `.ripple` | `InkWell` / `InkResponse` | Material 波纹 |

---

## 三、共享 JS 功能 → Dart 工具函数

来源：[`js/app.js`](C:\Users\Administrator\AppData\Roaming\Open Design\namespaces\release-stable-win\data\projects\55a9b35d-3459-41a4-87e8-fc905e72b094\js\app.js)

| JS 函数 | 功能 | Dart 实现方式 |
|---|---|---|
| `showToast(msg, duration)` | Snackbar 提示 | `ScaffoldMessenger.showSnackBar` |
| `showConfirm(title, msg, onConfirm)` | 确认对话框 | `showDialog` + `AlertDialog` |
| `toggleFabMenu()` | FAB 菜单切换 | FAB + 菜单状态 `StateProvider` |
| `initTagInput(container)` | 标签输入（回车添加、去重）| `TextField.onSubmitted` + `Set<String>` |
| `initFileDrop(zone, onFiles)` | 文件拖放 | `file_picker` package |
| `simulateAIProcess(container, onDone)` | AI 进度动画 | `CircularProgressIndicator` + 文字更新 |
| `highlightText(el, query)` | 搜索高亮 | `RichText` + `TextSpan` 分割匹配文本 |
| `renderKnowledgeGraph(canvas, nodes, edges)` | 图谱渲染 | `CustomPainter` (Canvas.drawCircle, drawLine) |

---

## 四、数据模型

### 4.1 Drift 表定义

```sql
-- 日记条目
CREATE TABLE diary_entries (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  title           TEXT    NOT NULL,
  body_markdown   TEXT    NOT NULL DEFAULT '',
  emotion         TEXT,                    -- happy|calm|sad|excited|tired|grateful|anxious
  created_at      INTEGER NOT NULL,        -- epoch ms
  updated_at      INTEGER NOT NULL,
  ai_summary      TEXT,                    -- AI 生成的摘要
  ai_tags         TEXT,                    -- JSON Array: AI 建议标签名
  file_paths      TEXT                     -- JSON Array: 附件路径
);

-- 知识条目
CREATE TABLE knowledge_entries (
  id                INTEGER PRIMARY KEY AUTOINCREMENT,
  title             TEXT    NOT NULL,
  content_markdown  TEXT    NOT NULL DEFAULT '',
  category_id       INTEGER,
  source_url        TEXT,
  created_at        INTEGER NOT NULL,
  updated_at        INTEGER NOT NULL,
  ai_summary        TEXT,
  ai_tags           TEXT,
  file_paths        TEXT,
  FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE SET NULL
);

-- 标签
CREATE TABLE tags (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  name        TEXT    NOT NULL UNIQUE,
  usage_count INTEGER NOT NULL DEFAULT 0
);

-- 分类
CREATE TABLE categories (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  name       TEXT    NOT NULL UNIQUE,
  icon       TEXT    NOT NULL DEFAULT 'folder',
  sort_order INTEGER NOT NULL DEFAULT 0
);

-- 日记-标签 多对多
CREATE TABLE diary_tags (
  diary_entry_id INTEGER NOT NULL,
  tag_id         INTEGER NOT NULL,
  PRIMARY KEY (diary_entry_id, tag_id),
  FOREIGN KEY (diary_entry_id) REFERENCES diary_entries(id) ON DELETE CASCADE,
  FOREIGN KEY (tag_id) REFERENCES tags(id) ON DELETE CASCADE
);

-- 知识-标签 多对多
CREATE TABLE knowledge_tags (
  knowledge_entry_id INTEGER NOT NULL,
  tag_id             INTEGER NOT NULL,
  PRIMARY KEY (knowledge_entry_id, tag_id),
  FOREIGN KEY (knowledge_entry_id) REFERENCES knowledge_entries(id) ON DELETE CASCADE,
  FOREIGN KEY (tag_id) REFERENCES tags(id) ON DELETE CASCADE
);

-- 设置
CREATE TABLE settings (
  key   TEXT PRIMARY KEY,
  value TEXT NOT NULL
);

-- 全文搜索索引
CREATE VIRTUAL TABLE search_index USING fts5(
  title,
  body,
  source_type,
  source_id
);
```

### 4.2 情绪枚举

```dart
enum Emotion {
  happy('😊', '开心', 'oklch(60% 0.16 80)'),
  calm('😌', '平静', 'oklch(60% 0.06 250)'),
  sad('😢', '难过', 'oklch(50% 0.12 250)'),
  excited('🤩', '兴奋', 'oklch(58% 0.14 40)'),
  tired('😮‍💨', '疲惫', 'oklch(45% 0.04 240)'),
  grateful('🙏', '感恩', 'oklch(55% 0.16 160)'),
  anxious('😰', '焦虑', 'oklch(50% 0.14 40)'),
  reflective('🤔', '反思', 'oklch(50% 0.04 280)');

  const Emotion(this.emoji, this.label, this.color);
  final String emoji;
  final String label;
  final String color; // OKLch
}
```

### 4.3 预置分类

```dart
const presetCategories = [
  ('💻', '技术开发'),
  ('📦', '产品设计'),
  ('🤖', 'AI & 机器学习'),
  ('🎨', '设计 & 体验'),
  ('📚', '阅读笔记'),
  ('🔧', '工具 & 效率'),
];
```

---

## 五、路由表

```
路径                      屏幕               Tab  参数
──────────────────────────────────────────────────────
/                         HomeScreen          ✅   —
/diary                    DiaryListScreen     ✅   —
/diary/new                DiaryEditorScreen   ❌   —
/diary/:id                DiaryEditorScreen   ❌   id: int
/knowledge                KnowledgeBrowseScr  ✅   ?category= (可选)
/knowledge/new            KnowledgeEditorScr  ❌   —
/knowledge/:id            KnowledgeDetailScr  ❌   id: int
/knowledge/:id/edit       KnowledgeEditorScr  ❌   id: int
/search                   SearchScreen        ❌   ?q= (可选)
/settings                 SettingsScreen      ✅   —
```

---

## 六、屏幕来源清单

每个 Flutter 屏幕对应哪个 HTML 原型 + 设计说明：

| Flutter Screen | HTML 源文件 | 关键组件 | 核心功能 |
|---|---|---|---|
| `HomeScreen` | [`screens/app-home.html`](C:\Users\Administrator\AppData\Roaming\Open Design\namespaces\release-stable-win\data\projects\55a9b35d-3459-41a4-87e8-fc905e72b094\screens\app-home.html) | stats-row, entry-card, ai-tip, search-bar, bottom-nav, fab-menu | 统计卡片、最近条目、AI 建议 |
| `DiaryListScreen` | [`screens/diary-list.html`](C:\Users\Administrator\AppData\Roaming\Open Design\namespaces\release-stable-win\data\projects\55a9b35d-3459-41a4-87e8-fc905e72b094\screens\diary-list.html) | filter-row, date-group, entry-card, bottom-nav | 日期分组、分类筛选、FAB |
| `DiaryEditorScreen` | [`screens/diary-editor.html`](C:\Users\Administrator\AppData\Roaming\Open Design\namespaces\release-stable-win\data\projects\55a9b35d-3459-41a4-87e8-fc905e72b094\screens\diary-editor.html) | mood-picker, title-input, editor-area, toolbar, upload-zone, ai-panel, tag-editor | 情绪选择、富文本、文件上传、AI 分析 |
| `KnowledgeBrowseScreen` | [`screens/knowledge-list.html`](C:\Users\Administrator\AppData\Roaming\Open Design\namespaces\release-stable-win\data\projects\55a9b35d-3459-41a4-87e8-fc905e72b094\screens\knowledge-list.html) | cat-grid, search-bar, view-toggle, graph-section, entry-card, bottom-nav | 分类网格、列表/图谱切换、FAB |
| `KnowledgeDetailScreen` | [`screens/knowledge-detail.html`](C:\Users\Administrator\AppData\Roaming\Open Design\namespaces\release-stable-win\data\projects\55a9b35d-3459-41a4-87e8-fc905e72b094\screens\knowledge-detail.html) | article-header, ai-summary-card, ai-keyword, article-body, attachment-card, tags-row, related-section | 来源标注、AI 摘要、Markdown 正文、关联推荐 |
| `KnowledgeEditorScreen` | [`screens/knowledge-editor.html`](C:\Users\Administrator\AppData\Roaming\Open Design\namespaces\release-stable-win\data\projects\55a9b35d-3459-41a4-87e8-fc905e72b094\screens\knowledge-editor.html) | form-group, form-input, form-select, form-textarea, upload-zone, ai-toggle, tag-editor | 标题/来源/分类/正文表单、文件上传、标签编辑 |
| `SearchScreen` | [`screens/search.html`](C:\Users\Administrator\AppData\Roaming\Open Design\namespaces\release-stable-win\data\projects\55a9b35d-3459-41a4-87e8-fc905e72b094\screens\search.html) | search-box, filter-row, result-item, search-history | 实时搜索、类型筛选、高亮、搜索历史 |
| `SettingsScreen` | [`screens/settings.html`](C:\Users\Administrator\AppData\Roaming\Open Design\namespaces\release-stable-win\data\projects\55a9b35d-3459-41a4-87e8-fc905e72b094\screens\settings.html) | settings-group, settings-card, settings-item, switch, btn-danger | API Key、缓存管理、数据导入导出 |
