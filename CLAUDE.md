# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目

知记 (Zhiji) — AI 原生个人知识管理 Flutter 应用 (Android APK)。DeepSeek API 驱动摘要、标签和 RAG 问答。

## 当前状态

| 项目 | 状态 |
|------|------|
| `flutter analyze` | 0 error, 0 warning, 1 info (外部包 deprecated API) |
| `flutter test` | 67/67 passed |
| Dart 源文件 | 40 个 |
| 测试文件 | 7 个 |
| Release APK | 3 个分包 (arm64 20.7MB / armeabi 18.5MB / x86_64 22.0MB) |
| AI 接入 | DeepSeek `/chat/completions` 6 种方法 |
| R8/ProGuard | 已启用 + `proguard-rules.pro`（含序列化保护） |
| 网络安全 | `network_security_config.xml` — 仅 HTTPS |
| StrictMode | `MainActivity.kt` 中启用 (FLAG_DEBUGGABLE 门控) |
| allowBackup | false（已关闭，防止数据库泄露） |
| 编辑器草稿保护 | ✅ 外部 Activity 启动前自动保存/恢复 |

## 环境

| 组件 | 路径/值 |
|------|--------|
| JDK | `C:\Program Files\Android\Android Studio\jbr` (JBR JDK 21) |
| Flutter | `C:\flutter` (3.38.5) |
| Android SDK | `%LOCALAPPDATA%\Android\Sdk` |
| pub 镜像 | `PUB_HOSTED_URL=https://pub.flutter-io.cn` |

## 常用命令

```bash
cd C:\AI\claudecode\projects\zhiji\zhiji_app
export JAVA_HOME="C:/Program Files/Android/Android Studio/jbr"
export PATH="$JAVA_HOME/bin:/c/flutter/bin:$PATH"
export PUB_HOSTED_URL="https://pub.flutter-io.cn"
export FLUTTER_STORAGE_BASE_URL="https://storage.flutter-io.cn"

flutter analyze          # 代码检查（0 error, 0 warning）
flutter test             # 全部测试（67/67）
dart run build_runner build --delete-conflicting-outputs  # 代码生成
```

**Release APK 构建**：需管理员 PowerShell（见底部"已解决的环境问题"#1）。

## 架构

```
lib/
├── main.dart                          # ProviderScope + PlatformDispatcher.onError
├── core/
│   ├── theme/                         # MD3 ColorScheme.fromSeed(#00897B) 亮/暗
│   ├── router/app_router.dart         # GoRouter StatefulShellRoute 4 Tab + 8 全屏（统一 fade+slide 转场）
│   ├── providers/theme_provider.dart  # ThemeMode StateNotifier
│   ├── database/                      # drift SQLite: 7 表 + FTS5 + 6 触发器 + 3 DAO
│   ├── widgets/                       # AppShell, EmptyState, TagChip, VoiceInputButton, MarkdownToolbar, AttachmentList, UndoManager
│   ├── models/emotion.dart            # 8 种情绪枚举
│   ├── network/
│   │   ├── dio_client.dart            # Dio 单例 (仅 kDebugMode 日志, 15s/30s 超时)
│   │   └── ai_api_service.dart        # DeepSeek API 6 种方法 + _truncate 截断保护
│   └── utils/
│       ├── file_importer.dart          # 文件导入 (TXT/MD/CSV/JSON)
│       └── file_attachment_manager.dart # 附件管理：AttachedFile + 拍照/相册/文档 + 权限引导
├── features/
│   ├── home/                          # 仪表盘：4 统计卡 + BarChart 情绪趋势 + 写作热力图 + AI 每周回顾 + AI 问答入口
│   ├── diary/                         # 日期分组列表 + 编辑器(PopScope/情绪/语音/附件/AI/撤销重做/批量删除/草稿保护)
│   ├── knowledge/                     # 分类浏览 + 编辑器(PopScope/AI/附件/撤销重做/草稿保护) + 详情(Markdown/关联推荐/附件展示)
│   ├── chat/                          # AI 智能问答 (RAG): FTS5→Top5 截断→DeepSeek→聊天气泡
│   ├── search/                        # FTS5 全文搜索 + 持久化历史 + RichText 高亮 + 结果计数
│   └── settings/                      # API Key/深色模式/导入导出(含标签+分类+AI)/隐私政策(7章节)/清空数据
```

**架构约定**：
- 导航全部使用 `context.push()`，禁止 `Navigator.pushNamed`；全屏路由用 `CustomTransitionPage`
- async 后必须 `if (!context.mounted) return` 再 `setState`
- 颜色通过 `Theme.of(context).colorScheme`，禁止硬编码
- FTS5 索引由 SQLite 触发器自动同步
- 所有 AI prompt 内容用 `_truncate()` 截断防止超 token
- 编辑器启动外部 Activity（相机/相册/文件选择器）前自动 `_saveDraft()`，返回后恢复

## 数据层

| 表 | 说明 |
|---|---|
| `diary_entries` | title, bodyMarkdown, emotion, aiSummary, aiTags, filePaths |
| `knowledge_entries` | title, contentMarkdown, categoryId FK, sourceUrl, aiSummary, filePaths |
| `tags` | name UNIQUE, usageCount (ON CONFLICT DO UPDATE 原子递增) |
| `category_models` | 6 预设分类 (onCreate 插入) |
| `diary_tags` / `knowledge_tags` | 多对多，FK CASCADE |
| `settings_table` | 键值对（含 diary_draft, knowledge_draft, search_history, theme_mode） |
| `search_index` | FTS5 虚拟表，6 个 SQLite 触发器自动同步 |

**FTS5 rowid**：日记 `id*2+1`，知识 `id*2`（奇偶分离）。

## 路由

- Tab: `/` Home、`/diary`、`/knowledge`、`/settings`
- 全屏: `/diary/new`, `/diary/:id`, `/knowledge/new`, `/knowledge/:id`, `/knowledge/:id/edit`, `/search`, `/chat`

## 功能清单

| 功能 | 位置 |
|------|------|
| 日记 CRUD + 情绪选择 (8种) | `diary_editor_screen.dart`, `emotion.dart` |
| 日记日期分组 (今天/昨天/本周/月) | `diary_list_screen.dart` |
| 日记标签动态筛选 + AI 分析 | `diary_list_screen.dart`, `ai_api_service.dart` |
| 日记编辑器 PopScope 未保存拦截 | `diary_editor_screen.dart` |
| 日记批量删除 (长按进选择模式) | `diary_list_screen.dart` |
| 知识 CRUD + 分类 + AI 分析 | `knowledge_editor/browse/detail_screen.dart` |
| 知识编辑器 PopScope 未保存拦截 | `knowledge_editor_screen.dart` |
| 知识关联推荐 (共同标签) | `knowledge_detail_screen.dart` |
| 知识批量删除 | `knowledge_browse_screen.dart` |
| DeepSeek AI 分析 + 三件套 (续写/润色/总结) | `ai_api_service.dart` |
| AI 智能问答 (RAG): FTS5 → Top5 截断 → DeepSeek | `chat_screen.dart` |
| FTS5 全文搜索 + 持久化历史 + RichText 高亮 | `search_screen.dart` |
| 语音输入 (中文, 权限引导) | `voice_input_button.dart` |
| 文件导入 (TXT/MD/CSV/JSON) | `file_importer.dart` |
| 附件支持 (拍照/相册/PDF/Word/Excel 等) | `file_attachment_manager.dart`, `attachment_list.dart` |
| 编辑器草稿保护 (外部启动前保存/恢复) | `diary_editor_screen.dart`, `knowledge_editor_screen.dart` |
| 撤销/重做 (文本快照栈, 50 步) | `undo_manager.dart` |
| Markdown 工具栏 (加粗/斜体/标题/列表/引用/代码) | `markdown_toolbar.dart` |
| 首页仪表盘 (4 统计卡 + 情绪趋势图 + 写作热力图) | `home_screen.dart`, `emotion_trend_chart.dart` |
| AI 每周回顾弹窗 | `home_screen.dart` |
| 数据导入导出 (含标签+分类+AI) | `settings_screen.dart` |
| 深色模式三态即时切换 | `settings_screen.dart`, `theme_provider.dart` |
| 隐私政策 (7 章节完整内容) | `settings_screen.dart` |
| API Key 加密存储 + 即时注入 Dio | `common_daos.dart` (FlutterSecureStorage → AppDio) |
| 页面切换 fade+slide 转场动画 | `app_router.dart` (CustomTransitionPage) |
| 全局错误兜底 + 空状态引导 | `main.dart`, `empty_state.dart` |
| Release 签名 + R8 混淆 + 仅 HTTPS + allowBackup=false | `build.gradle.kts`, `proguard-rules.pro`, `network_security_config.xml`, `AndroidManifest.xml` |

## 已解决的环境问题

1. **Gradle 环回连接 bug (Win11 24H2)**：管理员终端执行 `netsh int ipv4 set global loopbacklargemtu=disable`，然后在同一终端中构建。

2. **Selector.open() 失败 (Win11 24H2 JDK bug)**：JBR JDK 21 在管理员终端 + loopbacklargemtu=disable 后可用。

3. **Web 构建不可用**：dart:ffi (sqlite3) 在 Web 不可用，本项目仅 Android。

4. **drift Column 冲突**：同时用 drift 和 Flutter widget 的文件需 `import 'package:drift/drift.dart' hide Column;`

5. **模拟器**：Android Emulator 需 WHPX + 重启，备选 BlueStacks（自带虚拟化）。

6. **`_JAVA_OPTIONS` 污染**：gradlew.bat 已配置清除，但管理员终端构建最可靠。
