# 知记 (Zhiji) 开发文档

> v4.0 | 2026-06-21 | Flutter 3.38.5 + Dart 3.10.4 | 45 源文件 + 19 测试文件

---

## 一、项目概述

知记是一款 **Agent 驱动的个人知识管理** Android 应用。打开即对话，通过 DeepSeek API 驱动的 ReAct Agent 自主调用 7 个工具（本地知识库搜索、日记写入、附件读取、联网搜索等）。支持写日记、存知识、全文搜索、附件管理。所有数据存储在本地设备。

**技术栈**：Flutter 3.38.5 · Riverpod 2.6.1 · drift 2.28.2 (SQLite/FTS5) · GoRouter 14.8.0 · Material Design 3 · Dio 5.7.0

---

## 二、开发环境

### 2.1 必需组件

| 组件 | 路径 |
|------|------|
| JDK | `C:\Program Files\Android\Android Studio\jbr` (JBR JDK 21) |
| Flutter | `C:\flutter` (3.38.5) |
| Android SDK | `%LOCALAPPDATA%\Android\Sdk` |
| BlueStacks (测试) | `C:\Program Files\BlueStacks_nxt_cn\HD-Player.exe` |

### 2.2 环境变量

```bash
export JAVA_HOME="C:/Program Files/Android/Android Studio/jbr"
export PATH="$JAVA_HOME/bin:/c/flutter/bin:$PATH"
export PUB_HOSTED_URL="https://pub.flutter-io.cn"
export FLUTTER_STORAGE_BASE_URL="https://storage.flutter-io.cn"
```

### 2.3 已知环境限制

| 问题 | 解决方案 |
|------|---------|
| Gradle 环回连接 (Win11 24H2) | 管理员终端 + `netsh int ipv4 set global loopbacklargemtu=disable` |
| Selector.open() JDK bug | 必须用 JBR JDK 21，不能用 Zulu 17 |
| Android Emulator | 需 WHPX (`dism enable HypervisorPlatform`) 后重启；备选 BlueStacks |
| Web 构建 | dart:ffi 不可用，本项目仅 Android |

---

## 三、快速开始

```bash
cd C:\AI\claudecode\projects\zhiji\zhiji_app

# 代码检查
flutter analyze

# 运行测试
flutter test

# 代码生成（修改数据库 schema 后必须执行）
dart run build_runner build --delete-conflicting-outputs

# 构建 Release APK
flutter build apk --release
```

---

## 四、项目架构 (v4 Agent 首屏)

```
lib/
├── main.dart
├── core/
│   ├── agent/
│   │   ├── agent_service.dart       # ReAct 循环（5 轮迭代 + 3 层超时）
│   │   ├── agent_provider.dart      # AgentService Provider + 7 工具注册 + 记忆注入
│   │   ├── agent_memory.dart        # 用户对话记忆（最近 10 个主题追踪）
│   │   └── tools/
│   │       ├── tool.dart            # AgentTool 基类 + ToolCall/ToolResult + ToolRegistry
│   │       ├── all_tools.dart       # 7 个工具实现
│   │       └── web_search.dart      # Bing Web Search API 封装
│   ├── theme/
│   │   ├── app_theme.dart           # MD3 ThemeData (ColorScheme.fromSeed(#00897B))
│   │   ├── color_tokens.dart        # Seed color
│   │   └── dimensions.dart          # 间距/圆角/阴影 Token
│   ├── router/
│   │   └── app_router.dart          # GoRouter — StatefulShellRoute (仅 Agent 分支) + 全屏路由
│   ├── providers/
│   │   └── theme_provider.dart      # ThemeMode StateNotifier
│   ├── database/
│   │   ├── app_database.dart        # @DriftDatabase: 8 表 (含 agent_messages) + FTS5 + 6 触发器
│   │   ├── retry_on_lock.dart       # SQLite 锁重试（Agent 并发写入保护）
│   │   └── daos/
│   │       ├── diary_dao.dart       # 日记 CRUD + 统计 + 批量删除
│   │       ├── knowledge_dao.dart   # 知识 CRUD + 关联推荐 + 批量删除
│   │       └── common_daos.dart     # TagDao (原子getOrCreate), SettingsDao (SecureStorage)
│   ├── widgets/
│   │   ├── app_shell.dart           # FAB → BottomSheet 功能抽屉（v4 无底部 Tab）
│   │   ├── empty_state.dart         # 空状态引导
│   │   ├── loading_indicator.dart   # 加载态
│   │   ├── tag_chip.dart            # TagChip + TagInputField
│   │   ├── voice_input_button.dart  # 语音输入 (async安全 + 权限引导)
│   │   ├── markdown_toolbar.dart    # Markdown 格式工具栏
│   │   ├── attachment_list.dart     # 附件列表 (缩略图/类型图标/打开/删除)
│   │   └── undo_manager.dart        # UndoManager + UndoRedoButtons + TypingSnapshotTimer
│   ├── models/
│   │   └── emotion.dart             # 8 种情绪枚举 (emoji+中文标签)
│   ├── network/
│   │   ├── dio_client.dart          # Dio 单例 (kDebugMode 日志, 15s/30s 超时)
│   │   └── ai_api_service.dart      # DeepSeek chatCompletion + 4 种编辑器 AI 方法
│   └── utils/
│       ├── file_importer.dart       # 文件导入 (TXT/MD/CSV/JSON)
│       ├── file_attachment_manager.dart # AttachedFile + 拍照/相册/文档 + 权限引导Dialog
│       └── editor_ai_actions.dart   # 编辑器 AI 三件套（续写/润色/总结）
├── features/
│   ├── chat/chat_screen.dart        # Agent 对话屏幕 — 首屏，ReAct 调用 + 会话持久化
│   ├── home/home_screen.dart        # 首页仪表盘
│   │   └── widgets/emotion_trend_chart.dart  # fl_chart BarChart
│   ├── diary/
│   │   ├── diary_list_screen.dart   # 日期分组 + 标签筛选 + 批量删除 + 入场动画
│   │   ├── diary_editor_screen.dart # 编辑器 (PopScope + 情绪 + 语音 + 附件 + AI三件套 + 撤销重做 + 草稿保护)
│   │   └── widgets/                 # diary_card.dart, emotion_selector.dart
│   ├── knowledge/
│   │   ├── knowledge_browse_screen.dart  # 分类浏览 + 搜索入口 + 批量删除
│   │   ├── knowledge_editor_screen.dart  # 编辑器 (PopScope + 分类 + AI三件套 + 附件 + 撤销重做 + 草稿保护)
│   │   ├── knowledge_detail_screen.dart  # 详情 (Markdown + 分类徽章 + 标签 + 关联推荐 + 附件展示)
│   │   └── widgets/                 # knowledge_card.dart, category_filter_chips.dart
│   ├── search/search_screen.dart    # FTS5 搜索 + 持久化历史 + RichText 高亮 + 结果计数
│   └── settings/settings_screen.dart # API Key/深色模式/导入导出/隐私政策/清空数据
```

### 4.1 导航模型 (v4)

v4 版从 4-Tab 底部导航栏改为 **Agent 首屏 + 功能抽屉**：

```
StatefulShellRoute.indexedStack
  └── Shell: AppShell
       ├── 首屏: ChatScreen (Agent 对话，"/")
       └── FAB → BottomSheet 抽屉
            ├── 写日记 → /diary/new (全屏 fade+slide)
            ├── 知识库 → /knowledge (全屏 fade+slide)
            ├── 首页仪表盘 → /home (全屏 fade+slide)
            └── 设置 → /settings (全屏 fade+slide)
```

### 4.2 架构约定

| 约定 | 说明 |
|------|------|
| 导航 | `context.go()` / `context.push()` (GoRouter)，禁止 `Navigator.pushNamed`；全屏路由统一 fade+slide |
| 数据流 | Screen → DAO → drift → SQLite，无 Repository 层 |
| mounted | async 后必须 `if (!context.mounted) return` |
| 颜色 | 全部通过 `ColorScheme`，禁止硬编码 |
| FTS5 | SQLite 触发器自动同步，应用层不手动写 |
| AI 安全 | 所有 prompt 通过 `_truncate()` 截断 |
| 附件 | 复制到 app 内部存储，filePaths JSON 序列化 |
| 草稿保护 | 启动外部 Activity 前 `_saveDraft()`→settings_table，initState/返回后恢复 |
| PopScope | 两个编辑器均有返回拦截，检查 title/body/tags/attachments/emotion/aiSummary |

---

## 五、Agent 系统

### 5.1 ReAct 循环

```
用户输入
  ↓
构建 messages：[system_prompt, ...history, user]
  ↓
┌─→ AIService.chatCompletion(messages, tools) ──→ 获取响应
│   ↓
│  有 tool_calls？
│   ├── 是 → 逐个执行工具（45s 超时/个）
│   │        将 tool result 追加到 messages
│   │        循环计数器 + 重复检测（同工具 >3 次终止）
│   │        继续下一轮迭代（最多 5 轮）
│   │
│   └── 否 → 返回 content 文本
│
│  总超时 120s
│  5 轮后用尽 → 追加"请总结"消息再调一次
└──────────────────┘
```

### 5.2 7 个 Agent 工具

| # | 工具名 | 功能 | 参数 | 依赖 |
|---|--------|------|------|------|
| 1 | `search_knowledge` | 搜索知识库和日记 | query | FTS5 全文索引 |
| 2 | `save_to_knowledge` | 写入知识库 | title, content, category_id? | KnowledgeDao |
| 3 | `write_diary` | 帮用户写日记 | title, content, emotion? | DiaryDao |
| 4 | `get_diary_stats` | 日记统计 | 无 | DiaryDao (countAll/streak/wordCount/byEmotion) |
| 5 | `list_categories` | 列出分类 | 无 | KnowledgeDao |
| 6 | `read_attachment` | 读取文本附件 | attachment_id | FileAttachmentManager |
| 7 | `web_search` | 联网搜索 | query, count? | Bing Web Search API |

工具注册在 `agent_provider.dart`，`ToolRegistry` 负责解析 tool call JSON、分发执行。

### 5.3 Agent 记忆

`AgentMemory`：
- 追踪最近 10 个对话主题
- `addRecentTopic(question)` — 每次提问后调用
- `toSystemPromptFragment()` — 返回注入 system prompt 的上下文文本

### 5.4 会话持久化

`agent_messages` 表：
| 列 | 类型 | 说明 |
|----|------|------|
| id | INTEGER PK | 自增 |
| session_id | TEXT | 会话标识 |
| role | TEXT | user / assistant / tool |
| content | TEXT | 消息正文 |
| tool_name | TEXT? | 工具名（tool 消息专用）|

- 启动时加载最近 50 条消息，取最后一条的 session_id 恢复会话
- 每轮对话后自动持久化
- 并发写入使用 `retryOnLock`

---

## 六、数据模型

### 6.1 表结构

| 表 | 关键字段 | 说明 |
|---|---|---|
| `diary_entries` | id, title, bodyMarkdown, emotion, createdAt, updatedAt, aiSummary, aiTags, filePaths | 日记 |
| `knowledge_entries` | id, title, contentMarkdown, categoryId(FK CASCADE SET NULL), sourceUrl, filePaths | 知识 |
| `tags` | id, name(UNIQUE), usageCount | 标签 |
| `category_models` | id, name(UNIQUE), icon, sortOrder | 分类 |
| `diary_tags` | diaryEntryId(FK), tagId(FK) | 多对多 |
| `knowledge_tags` | knowledgeEntryId(FK), tagId(FK) | 多对多 |
| `agent_messages` | id, sessionId, role, content, toolName, createdAt | Agent 会话历史 |
| `settings_table` | key(PK), value | 键值对 |
| `search_index` | FTS5 虚拟表 | 全文索引 |

### 6.2 FTS5

- **rowid 编码**：日记 `id*2+1`，知识 `id*2`（奇偶分离永不冲突）
- **6 个触发器**：INSERT/UPDATE/DELETE × 2 类型

### 6.3 Settings 键

| key | 用途 |
|-----|------|
| `deepseek_api_key` | DeepSeek API Key（SecureStorage 加密）|
| `bing_api_key` | Bing Search API Key |
| `diary_draft` | 日记编辑器草稿 JSON |
| `knowledge_draft` | 知识编辑器草稿 JSON |
| `search_history` | 搜索历史 JSON 数组 |
| `theme_mode` | "system" / "light" / "dark" |

---

## 七、路由表 (v4)

| 路径 | 屏幕 | Shell 内 | 转场 |
|------|------|----------|------|
| `/` | ChatScreen (Agent 对话) | ✅ 首屏 | — |
| `/home` | HomeScreen | ❌ | fade+slide 250ms |
| `/diary` | DiaryListScreen | ❌ | fade+slide 250ms |
| `/diary/new` | DiaryEditorScreen (新建) | ❌ | fade+slide 250ms |
| `/diary/:id` | DiaryEditorScreen (编辑) | ❌ | fade+slide 250ms |
| `/knowledge` | KnowledgeBrowseScreen | ❌ | fade+slide 250ms |
| `/knowledge/new` | KnowledgeEditorScreen (新建) | ❌ | fade+slide 250ms |
| `/knowledge/:id` | KnowledgeDetailScreen | ❌ | fade+slide 250ms |
| `/knowledge/:id/edit` | KnowledgeEditorScreen (编辑) | ❌ | fade+slide 250ms |
| `/search` | SearchScreen | ❌ | fade+slide 250ms |
| `/settings` | SettingsScreen | ❌ | fade+slide 250ms |
| `/chat` | ChatScreen (独立) | ❌ | fade+slide 250ms |

---

## 八、功能清单

| 功能 | 文件 |
|------|------|
| Agent ReAct 对话 (5 轮迭代 + 工具自主调用) | `agent_service.dart` |
| Agent 7 工具集 (搜索/写入/统计/附件/联网) | `tools/*.dart` |
| Agent 记忆 (10 主题追踪) | `agent_memory.dart` |
| Agent 会话持久化 (agent_messages 表) | `chat_screen.dart` |
| Agent 附件传递 (AttachedFile → ReadAttachmentTool) | `agent_service.dart` |
| 日记 CRUD + 情绪选择 (8种) | `diary_editor_screen.dart` |
| 日记未保存退出确认 (PopScope) | `diary_editor_screen.dart` |
| 日记编辑草稿保护 | `diary_editor_screen.dart` |
| 日记日期分组 + 标签筛选 + 批量删除 | `diary_list_screen.dart` |
| 知识 CRUD + 分类选择 | `knowledge_editor/browse/detail_screen.dart` |
| 知识详情 (Markdown + 分类徽章 + 标签 + 附件 + 关联推荐) | `knowledge_detail_screen.dart` |
| 撤销/重做 (快照栈50步) | `undo_manager.dart` |
| Markdown 工具栏 | `markdown_toolbar.dart` |
| DeepSeek AI 分析 (摘要+标签) | `ai_api_service.dart` |
| AI 续写/润色/总结 | `ai_api_service.dart` + `editor_ai_actions.dart` |
| FTS5 全文搜索 + 历史持久化 + RichText 高亮 | `search_screen.dart` |
| 语音输入 (中文) | `voice_input_button.dart` |
| 文件导入 (TXT/MD/CSV/JSON) | `file_importer.dart` |
| 附件系统 (拍照/相册/文档) | `file_attachment_manager.dart` + `attachment_list.dart` |
| API Key 管理 (SecureStorage) | `settings_screen.dart` + `common_daos.dart` |
| 数据导入导出 (含标签+分类+AI, JSON校验) | `settings_screen.dart` |
| 深色模式三态即时切换 | `settings_screen.dart` + `theme_provider.dart` |
| 隐私政策 (7章节 BottomSheet) | `settings_screen.dart` |
| 首页仪表盘 (4统计卡 + BarChart趋势) | `home_screen.dart` |
| FAB 功能抽屉 (BottomSheet) | `app_shell.dart` |

---

## 九、DeepSeek API 配置

1. 打开应用 → 设置 → 输入 DeepSeek API Key (`sk-...`) → 保存
2. 使用 Agent：首屏直接对话，Agent 自动决定调用哪些工具
3. 使用编辑器 AI：进入日记/知识编辑器 → 选中文字 → AI 图标 → 续写/润色/总结
4. API 地址：`api.deepseek.com/v1/chat/completions`，HTTPS 加密
5. API Key 通过 `FlutterSecureStorage` → Android Keystore 加密存储

---

## 十、构建 APK

```powershell
cd C:\AI\claudecode\projects\zhiji\zhiji_app
$env:JAVA_HOME="C:\Program Files\Android\Android Studio\jbr"
$env:PATH="$env:JAVA_HOME\bin;C:\flutter\bin;$env:PATH"
$env:PUB_HOSTED_URL="https://pub.flutter-io.cn"
$env:FLUTTER_STORAGE_BASE_URL="https://storage.flutter-io.cn"

flutter build apk --release
```

产物路径：`build\app\outputs\flutter-apk\app-release.apk` (~58.8MB)

## 十一、测试

```bash
flutter test                    # 全部 19 个测试文件
flutter test test/database_test.dart
flutter test test/agent_service_test.dart
flutter test test/agent_messages_test.dart
flutter test test/web_search_test.dart
```

覆盖：CRUD、边界/约束、FTS5、统计、标签筛选、Widget、Agent 工具、Agent 记忆、Agent 端到端、联网搜索、集成测试

## 十二、已知问题与最近修复

| 日期 | 问题 | 修复 |
|------|------|------|
| 2026-06-21 | 多轮对话第二条起报"AI 服务暂时不可用" | `_buildHistory()` 角色映射 `ai`→`assistant` |
| 历史 | `agent_messages` 表缺失导致 DB 启动失败 | schema version 2 自动创建表 |
