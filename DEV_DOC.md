# 知记 (Zhiji) 开发文档

> v3.1 | 2026-06-17 | Flutter 3.38.5 + Dart 3.10.4 | 40 源文件 + 7 测试文件 (67 tests)

---

## 一、项目概述

知记是一款 AI 驱动的个人知识管理 Android 应用。支持写日记、存知识、全文搜索、AI 智能问答、附件管理，DeepSeek API 驱动摘要、标签和 RAG 对话。

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

# 构建 APK（需管理员终端）
flutter build apk --debug
```

---

## 四、项目架构

```
lib/
├── main.dart           
├── core/
│   ├── theme/
│   │   ├── app_theme.dart             # MD3 ThemeData (ColorScheme.fromSeed(#00897B))
│   │   ├── color_tokens.dart          # Seed color
│   │   └── dimensions.dart            # 间距/圆角/阴影 Token
│   ├── router/
│   │   └── app_router.dart            # GoRouter + CustomTransitionPage fade+slide
│   ├── providers/
│   │   └── theme_provider.dart        # ThemeMode StateNotifier
│   ├── database/
│   │   ├── app_database.dart          # @DriftDatabase: 7 表 + FTS5 + 6 触发器
│   │   └── daos/
│   │       ├── diary_dao.dart         # 日记 CRUD + 统计 + 批量删除
│   │       ├── knowledge_dao.dart     # 知识 CRUD + 关联推荐 + 批量删除
│   │       └── common_daos.dart       # TagDao (原子getOrCreate), SettingsDao (SecureStorage)
│   ├── widgets/
│   │   ├── app_shell.dart             # Scaffold + NavigationBar
│   │   ├── empty_state.dart           # 空状态引导
│   │   ├── loading_indicator.dart     # 加载态
│   │   ├── tag_chip.dart              # TagChip + TagInputField
│   │   ├── voice_input_button.dart    # 语音输入 (async安全 + 权限引导)
│   │   ├── markdown_toolbar.dart      # Markdown 格式工具栏
│   │   ├── attachment_list.dart       # 附件列表 (缩略图/类型图标/打开/删除)
│   │   └── undo_manager.dart          # UndoManager + UndoRedoButtons + TypingSnapshotTimer
│   ├── models/
│   │   └── emotion.dart               # 8 种情绪枚举 (emoji+中文标签)
│   ├── network/
│   │   ├── dio_client.dart            # Dio 单例 (kDebugMode 日志, 15s/30s 超时)
│   │   └── ai_api_service.dart        # DeepSeek API 7 方法 + _truncate + _parseJson
│   └── utils/
│       ├── file_importer.dart         # 文件导入 (TXT/MD/CSV/JSON)
│       └── file_attachment_manager.dart # AttachedFile + 拍照/相册/文档 + 权限引导Dialog
├── features/
│   ├── home/
│   │   ├── home_screen.dart           # 仪表盘 + AI问答入口 + 每周回顾弹窗 + FAB
│   │   └── widgets/
│   │       └── emotion_trend_chart.dart  # fl_chart BarChart
│   ├── diary/
│   │   ├── diary_list_screen.dart     # 日期分组 + 标签筛选 + 批量删除 + 入场动画
│   │   ├── diary_editor_screen.dart   # 编辑器 (PopScope + 情绪 + 语音 + 附件 + AI三件套 + 撤销重做 + 草稿保护)
│   │   └── widgets/
│   │       ├── diary_card.dart        # 日记卡片 (emoji + 附件标记 + 多选Checkbox + 长按)
│   │       └── emotion_selector.dart  # 8 情绪选择器
│   ├── knowledge/
│   │   ├── knowledge_browse_screen.dart  # 分类浏览 + 搜索入口 + 批量删除
│   │   ├── knowledge_editor_screen.dart  # 编辑器 (PopScope + 分类 + AI三件套 + 附件 + 撤销重做 + 草稿保护)
│   │   ├── knowledge_detail_screen.dart  # 详情 (Markdown + 分类徽章 + 标签 + 关联推荐 + 附件展示)
│   │   └── widgets/
│   │       ├── knowledge_card.dart        # 知识卡片 (AI摘要 + 附件标记 + 多选Checkbox + 长按)
│   │       └── category_filter_chips.dart # 分类筛选 Chips
│   ├── chat/
│   │   └── chat_screen.dart           # AI 问答 (RAG): FTS5→Top5截断→DeepSeek, 聊天气泡 + 快捷提问
│   ├── search/
│   │   └── search_screen.dart         # FTS5 搜索 + 持久化历史 + RichText 高亮 + 结果计数
│   └── settings/
│       └── settings_screen.dart       # API Key/深色模式/导入导出/隐私政策(7章节)/清空数据
```

### 4.1 架构约定

| 约定 | 说明 |
|------|------|
| 导航 | `context.push()` (GoRouter)，禁止 `Navigator.pushNamed`；全屏路由统一 fade+slide |
| 数据流 | Screen → DAO → drift → SQLite，无 Repository 层 |
| mounted | async 后必须 `if (!context.mounted) return` |
| 颜色 | 全部通过 `ColorScheme`，禁止硬编码 |
| FTS5 | SQLite 触发器自动同步，应用层不手动写 |
| AI 安全 | 所有 prompt 通过 `_truncate()` 截断；RAG 上下文 1500 字/条 |
| 附件 | 复制到 app 内部存储，filePaths JSON 序列化 |
| 草稿保护 | 启动外部 Activity 前 `_saveDraft()`→settings_table，initState/返回后恢复 |
| PopScope | 两个编辑器均有返回拦截，检查 title/body/tags/attachments/emotion/aiSummary |

---

## 五、数据模型

### 5.1 表结构

| 表 | 关键字段 | 说明 |
|---|---|---|
| `diary_entries` | id, title, bodyMarkdown, emotion, createdAt, updatedAt, aiSummary, aiTags, filePaths | 日记 |
| `knowledge_entries` | id, title, contentMarkdown, categoryId(FK CASCADE SET NULL), sourceUrl, filePaths | 知识 |
| `tags` | id, name(UNIQUE), usageCount | 标签 |
| `category_models` | id, name(UNIQUE), icon, sortOrder | 分类 |
| `diary_tags` | diaryEntryId(FK), tagId(FK) | 多对多 |
| `knowledge_tags` | knowledgeEntryId(FK), tagId(FK) | 多对多 |
| `settings_table` | key(PK), value | 键值对（含 diary_draft, knowledge_draft, search_history, theme_mode） |
| `search_index` | FTS5 虚拟表 | 全文索引 |

### 5.2 FTS5

- **rowid 编码**：日记 `id*2+1`，知识 `id*2`（奇偶分离永不冲突）
- **6 个触发器**：INSERT/UPDATE/DELETE × 2 类型
- **RAG 使用**：`db.search()` → Top 5 → 每条截断 1500 字 → join 为 context

### 5.3 草稿键 (settings_table)

| key | 用途 | 内容 |
|-----|------|------|
| `diary_draft` | 日记编辑器草稿 | JSON: title, body, emotion, tags, aiSummary, aiTags, attachments |
| `knowledge_draft` | 知识编辑器草稿 | JSON: title, body, categoryId, tags, aiSummary, aiTags, attachments |
| `search_history` | 搜索历史 | JSON 数组: [query, ...] up to 20 |
| `theme_mode` | 主题设置 | "system" / "light" / "dark" |

---

## 六、路由表

| 路径 | 屏幕 | Tab 内 | 转场 |
|------|------|--------|------|
| `/` | HomeScreen | ✅ | Tab 切换 |
| `/diary` | DiaryListScreen | ✅ | Tab 切换 |
| `/knowledge` | KnowledgeBrowseScreen | ✅ | Tab 切换 |
| `/settings` | SettingsScreen | ✅ | Tab 切换 |
| `/diary/new` | DiaryEditorScreen (新建) | ❌ | fade+slide 250ms |
| `/diary/:id` | DiaryEditorScreen (编辑) | ❌ | fade+slide 250ms |
| `/knowledge/new` | KnowledgeEditorScreen (新建) | ❌ | fade+slide 250ms |
| `/knowledge/:id` | KnowledgeDetailScreen | ❌ | fade+slide 250ms |
| `/knowledge/:id/edit` | KnowledgeEditorScreen (编辑) | ❌ | fade+slide 250ms |
| `/search` | SearchScreen | ❌ | fade+slide 250ms |
| `/chat` | ChatScreen (AI 问答) | ❌ | fade+slide 250ms |

---

## 七、功能清单

| 功能 | 文件 |
|------|------|
| 日记 CRUD + 情绪选择 (8种) | `diary_editor_screen.dart`, `emotion.dart` |
| 日记未保存退出确认 (PopScope) | `diary_editor_screen.dart` |
| 日记编辑草稿保护 (外部Activity前保存/恢复) | `diary_editor_screen.dart` |
| 日记日期分组 (今天/昨天/本周/月) | `diary_list_screen.dart` |
| 日记标签动态筛选 | `diary_list_screen.dart` |
| 日记批量删除 (长按→多选→全选→确认) | `diary_list_screen.dart` |
| 知识 CRUD + 分类选择 | `knowledge_editor/browse/detail_screen.dart` |
| 知识未保存退出确认 (PopScope) | `knowledge_editor_screen.dart` |
| 知识编辑草稿保护 (外部Activity前保存/恢复) | `knowledge_editor_screen.dart` |
| 知识详情 (Markdown + 分类徽章 + 标签 + 附件) | `knowledge_detail_screen.dart` |
| 知识关联推荐 (共同标签) | `knowledge_detail_screen.dart` |
| 知识批量删除 | `knowledge_browse_screen.dart` |
| 撤销/重做 (快照栈50步 + 定时快照 + 操作前快照) | `undo_manager.dart` |
| Markdown 工具栏 (加粗/斜体/标题/列表/引用/代码) | `markdown_toolbar.dart` |
| DeepSeek AI 分析 (摘要+标签, 4000字截断) | `ai_api_service.dart` |
| AI 续写/润色/总结 三件套 | `ai_api_service.dart` + 编辑器 PopupMenu |
| AI 智能问答 (RAG): FTS5→Top5→1500字截断→DeepSeek | `chat_screen.dart` |
| AI 每周回顾    | `home_screen.dart` |
| FTS5 全文搜索 + 历史持久化 + RichText 高亮 + 计数 | `search_screen.dart` |
| 语音输入 (中文, 权限引导) | `voice_input_button.dart` |
| 文件导入 (TXT/MD/CSV/JSON) | `file_importer.dart` |
| 附件系统 (拍照/相册/PDF/Word/Excel/PPT/ZIP等) | `file_attachment_manager.dart` + `attachment_list.dart` |
| 权限拒绝引导 (相机/相册/麦克风 → openAppSettings) | `file_attachment_manager.dart`, `voice_input_button.dart` |
| API Key 管理 (SecureStorage + 即时Dio注入) | `settings_screen.dart` + `common_daos.dart` |
| 数据导入导出 (含标签+分类+AI, JSON校验) | `settings_screen.dart` |
| 深色模式三态即时切换 | `settings_screen.dart` + `theme_provider.dart` |
| 隐私政策 (7章节完整内容 BottomSheet) | `settings_screen.dart` |
| 首页仪表盘 (4统计卡 + BarChart趋势 + 28天热力图) | `home_screen.dart` + `emotion_trend_chart.dart` |
| 页面转场动画 (CustomTransitionPage fade+slide) | `app_router.dart` |
| 全局错误兜底 + 空状态引导 | `main.dart`, `empty_state.dart` |

---

## 八、Android 构建配置

| 配置项 | 值 |
|--------|-----|
| compileSdk | 36 |
| targetSdk | 36 |
| minSdk | 24 |
| 包名 | com.zhiji.zhiji |
| 应用名 | 知记 |
| 权限 | INTERNET, RECORD_AUDIO, CAMERA |
| R8 混淆 | Release 启用 (isMinifyEnabled=true, isShrinkResources=true) |
| ProGuard 规则 | `proguard-rules.pro` (Flutter+drift+Dio+序列化保护) |
| 网络安全 | `network_security_config.xml` (仅 HTTPS, cleartextTrafficPermitted=false) |
| StrictMode | `MainActivity.kt` (FLAG_DEBUGGABLE 门控) |
| allowBackup | false |

---

## 九、测试

```bash
flutter test                    # 全部 67 个
flutter test test/database_test.dart       # 单文件
flutter test test/widget_ui_test.dart      # Widget 测试
flutter test test/integration_test.dart    # 集成测试
```

覆盖：CRUD (28)、边界/约束 (11)、FTS5 (7)、统计 (4)、标签筛选 (3)、Widget (12)、集成 (3)、其他 (6)

---

## 十、DeepSeek API 配置

1. 打开应用 → 设置 → 输入 API Key (`sk-...`) → 保存
2. 使用 AI 分析：进入日记/知识编辑器 → 点击"分析"按钮
3. 使用 AI 三件套：选中文字 → 点击 AI 图标 → 续写/润色/总结
4. 使用 AI 问答：首页 → AI 问答入口 → 输入问题 → 发送
5. API 调用 `api.deepseek.com/v1/chat/completions`，HTTPS 加密
6. API Key 通过 `FlutterSecureStorage` → Android Keystore 加密存储

---

## 十一、构建 APK

```powershell
# 管理员 PowerShell:
cd C:\AI\claudecode\projects\zhiji\zhiji_app
$env:JAVA_HOME="C:\Program Files\Android\Android Studio\jbr"
$env:PATH="$env:JAVA_HOME\bin;C:\flutter\bin;$env:PATH"
$env:PUB_HOSTED_URL="https://pub.flutter-io.cn"
$env:FLUTTER_STORAGE_BASE_URL="https://storage.flutter-io.cn"
flutter build apk --debug

# Release APK（分包）
flutter build apk --release --split-per-abi
```

产物路径：`build\app\outputs\flutter-apk\`

| 文件 | 大小 | 适用 |
|------|------|------|
| `app-arm64-v8a-release.apk` | 20.7 MB | 主流 64 位手机 |
| `app-armeabi-v7a-release.apk` | 18.5 MB | 老旧 32 位手机 |
| `app-x86_64-release.apk` | 22.0 MB | 模拟器 |
