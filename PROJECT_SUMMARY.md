# 知记 (Zhiji) — 项目开发总览

> 从零到交付的完整记录 | 2026-06-17 | 版本 v3.1

---

## 一、项目概况

| 属性 | 值 |
|------|-----|
| 项目名称 | 知记 (Zhiji) |
| 项目定位 | AI 原生个人知识管理 Android 应用 |
| 技术栈 | Flutter 3.38.5 · Dart 3.10.4 · Riverpod 2.6.1 · drift 2.28.2 · GoRouter 14.8.0 · MD3 |
| 目标平台 | Android APK（Release 三包：20.7MB / 18.5MB / 22.0MB） |
| 开发环境 | Windows 11 24H2 · JBR JDK 21 · Android SDK 36 |
| 代码规模 | 40 个 Dart 源文件 · 7 个测试文件 · 67 个测试 |
| 依赖项 | 34 个包（含 speech_to_text, fl_chart, image_picker, open_filex, permission_handler 等） |

---

## 二、开发历程

### 阶段概览

```
时间线：2026-06-16 ~ 2026-06-17（约 28 小时实际开发）
```

| 阶段 | 内容 | 文件 | 测试 |
|------|------|------|------|
| **Phase 0** | 环境搭建：JDK, Flutter, Android SDK, 模拟器 | — | — |
| **Phase 1** | 项目脚手架：pubspec, 目录结构, 主题系统, 路由, AppShell, Dio | 12 | 1 |
| **Phase 2** | 数据层：7 表 + FTS5 + 6 触发器 + 3 DAO + 预设数据 | 5 | 12 |
| **Phase 3** | 核心屏幕：首页, 日记列表/编辑器, 知识浏览/编辑/详情, 搜索, 设置 | 14 | 30 |
| **Phase 4** | BLOCKING 修复：FTS5 同步, updateEntry, 标签回显, 删除功能 | — | 40 |
| **Phase 5** | 代码审查修复：两份审计报告共 40+ 条 | — | 42 |
| **Phase 6** | APK 构建（管理员终端解决 Win11 Gradle 环回 bug） | — | — |
| **Phase 7** | 质量提升：R8, 网络安全, StrictMode, 隐私入口, 反馈入口 | 5 | 42 |
| **Phase 8** | 新功能：语音输入, 文件导入, 日记日期分组, Navigator→context.push | 4 | 42 |
| **V2 阶段 0** | 依赖新增：fl_chart, permission_handler | 1 | — |
| **V2 阶段 1** | 深度修复：深色模式即时生效, 语音权限, 标签筛选 JOIN, 清空数据优化 | 7 | 45 |
| **V2 阶段 2** | 编辑体验：Markdown 工具栏, AI 续写/润色/总结 API + UI 按钮 | 4 | 45 |
| **V2 阶段 3** | 首页可视化：4 统计卡, 情绪趋势图, 写作热力图, 混合最近列表 | 4 | 49 |
| **V2 阶段 4** | AI 扩展：每日回顾弹窗, API 统一重构 | 2 | 49 |
| **V2 阶段 5** | 细节打磨：入场动画, 搜索高亮, 空状态引导, 关联推荐 | 5 | 49 |
| **V2 阶段 6** | 交付工程化：Release 签名, 应用图标, 环境说明 | 4 | 49 |
| **V3 阶段 0** | AI 智能问答 (RAG): chat_screen + askQuestion API | 1 | 49 |
| **V3 阶段 1** | 批量操作：多选模式 + 批量删除日记/知识 | 4 | 53 |
| **V3 阶段 2** | 附件系统：拍照/相册/文档, 缩略图预览, 类型图标, 系统打开 | 3 | 53 |
| **V3 阶段 3** | 撤销/重做：UndoManager 快照栈 + TypingSnapshotTimer + UndoRedoButtons | 2 | 53 |
| **V3 阶段 4** | 综合审查：9 阶段全流程审计, 16 个问题修复 | — | — |
| **V3 阶段 5** | 优化修复：dropdown deprecation, RAG/AI 截断, 权限引导, 转场动画, 隐私政策 | 4 | 67 |
| **V3 阶段 6** | 测试补充：11 Widget 测试 + 3 集成测试 | — | 67 |
| **V3 阶段 7** | 上线前修复：草稿保护 (外部 Activity 前保存/恢复), 知识编辑器 PopScope, _hasChanges 补全, 构建签名路径修复 | 3 | 67 |

---

## 三、架构设计

### 3.1 完整目录树

```
lib/ (40 files)
├── main.dart 
├── core/
│   ├── theme/                         # app_theme, color_tokens, dimensions
│   ├── router/app_router.dart         # GoRouter + CustomTransitionPage (fade+slide)
│   ├── providers/theme_provider.dart  # ThemeMode StateNotifier
│   ├── database/                      # app_database (7表+FTS5+6触发器) + daos (diary/knowledge/common)
│   ├── widgets/                       # AppShell, EmptyState, TagChip, VoiceInputButton, MarkdownToolbar, AttachmentList, UndoManager, LoadingIndicator
│   ├── models/emotion.dart            # 8 种情绪枚举
│   ├── network/                       # dio_client (单例) + ai_api_service (7 种 AI 方法)
│   └── utils/                         # file_importer, file_attachment_manager
├── features/
│   ├── home/                          # home_screen + widgets/emotion_trend_chart
│   ├── diary/                         # diary_list_screen, diary_editor_screen + widgets/
│   ├── knowledge/                     # browse_screen, editor_screen, detail_screen + widgets/
│   ├── chat/chat_screen.dart          # RAG 对话屏
│   ├── search/search_screen.dart      # FTS5 搜索+高亮
│   └── settings/settings_screen.dart  # 全设置功能
```

### 3.2 架构约定

| 约定 | 说明 |
|------|------|
| 导航 | 全部 `context.push()`（GoRouter），全屏路由 `CustomTransitionPage` fade+slide |
| 数据流 | Screen → DAO → drift → SQLite，无 Repository 层 |
| mounted | 所有 async 后 `if (!context.mounted) return` |
| 颜色 | 全部通过 `Theme.of(context).colorScheme`，禁止硬编码 |
| FTS5 | SQLite 触发器自动同步，rowid 奇偶编码（日记 id×2+1，知识 id×2） |
| AI 安全 | 所有 prompt 通过 `_truncate()` 截断；RAG 上下文截断 1500 字符/条 |
| 草稿保护 | 编辑器启动外部 Activity 前 `_saveDraft()` to settings_table，initState 恢复 |
| PopScope | 两个编辑器均拦截未保存退出，检查 title/body/tags/attachments/emotion/aiSummary |

---

## 四、数据模型

### 4.1 表结构

| 表名 | 关键字段 | 说明 |
|------|---------|------|
| `diary_entries` | id, title, bodyMarkdown, emotion, createdAt, updatedAt, aiSummary, aiTags, filePaths | 日记 |
| `knowledge_entries` | id, title, contentMarkdown, categoryId(FK→category_models SET NULL), sourceUrl, aiSummary, filePaths | 知识 |
| `tags` | id, name(UNIQUE), usageCount | 标签（原子 ON CONFLICT DO UPDATE） |
| `category_models` | id, name(UNIQUE), icon, sortOrder | 6 个预设分类 |
| `diary_tags` | diaryEntryId(FK CASCADE), tagId(FK CASCADE) | 多对多 |
| `knowledge_tags` | knowledgeEntryId(FK CASCADE), tagId(FK CASCADE) | 多对多 |
| `settings_table` | key(PK), value | 键值对（含 diary_draft, knowledge_draft, search_history, theme_mode） |
| `search_index` | FTS5 虚拟表 | 全文索引（6 触发器自动同步） |

### 4.2 DAO 方法清单

| DAO | 方法 |
|-----|------|
| DiaryDao | insertEntry, updateEntry, deleteEntry, deleteEntries(批量), getById, watchAll, countAll, search, listByTag, countByEmotion, currentStreak, wordCountThisWeek, countByDay |
| KnowledgeDao | insertEntry, updateEntry, deleteEntry, deleteEntries(批量), getById, watchAll, watchByCategory, countAll, countByCategory, listRecent, listCategories, listRelatedByTags |
| TagDao | getByName, listAll, getOrCreate, linkDiary, linkKnowledge, getForDiary, getForKnowledge |
| SettingsDao | getValue, setValue, remove, setApiKey, getApiKey, deleteApiKey |

---

## 五、路由表

| 路径 | 屏幕 | Tab 内 | 转场 |
|------|------|--------|------|
| `/` | HomeScreen | ✅ 首页 | Tab 切换 |
| `/diary` | DiaryListScreen | ✅ 日记 | Tab 切换 |
| `/knowledge` | KnowledgeBrowseScreen | ✅ 知识库 | Tab 切换 |
| `/settings` | SettingsScreen | ✅ 设置 | Tab 切换 |
| `/diary/new` | DiaryEditorScreen (新建) | ❌ | fade+slide 250ms |
| `/diary/:id` | DiaryEditorScreen (编辑) | ❌ | fade+slide 250ms |
| `/knowledge/new` | KnowledgeEditorScreen (新建) | ❌ | fade+slide 250ms |
| `/knowledge/:id` | KnowledgeDetailScreen | ❌ | fade+slide 250ms |
| `/knowledge/:id/edit` | KnowledgeEditorScreen (编辑) | ❌ | fade+slide 250ms |
| `/search` | SearchScreen | ❌ | fade+slide 250ms |
| `/chat` | ChatScreen (AI 问答) | ❌ | fade+slide 250ms |

---

## 六、功能清单

| 功能 | 状态 | 关键实现 |
|------|------|---------|
| 日记 CRUD | ✅ | 情绪选择(8种) + 标签 + AI 分析 + 附件 |
| 日记未保存退出确认 | ✅ | PopScope 检查 title/body/tags/attachments/emotion/aiSummary |
| 日记编辑草稿保护 | ✅ | 外部 Activity 前自动 _saveDraft, initState _restoreDraft |
| 日记日期分组 | ✅ | 今天/昨天/本周/年月 |
| 日记标签筛选（JOIN） | ✅ | `listByTag` SQL JOIN `diary_tags` |
| 日记批量删除 | ✅ | 长按进选择模式 + 全选 + 确认弹窗 |
| 知识 CRUD | ✅ | 分类选择 + 标签 + AI 分析 + 附件 |
| 知识未保存退出确认 | ✅ | PopScope (同日记) |
| 知识编辑草稿保护 | ✅ | 外部 Activity 前自动保存/恢复 |
| 知识详情 | ✅ | Markdown 渲染 + 分类徽章 + 标签 + 附件展示 |
| 知识关联推荐 | ✅ | `listRelatedByTags` 共同标签查询 |
| 知识批量删除 | ✅ | 长按进选择模式 + 全选 |
| FTS5 全文搜索 | ✅ | 6 SQLite 触发器自动同步 |
| 搜索历史持久化 | ✅ | `settings_table` JSON 存储 |
| 搜索结果高亮 | ✅ | RichText 红色加粗匹配词 |
| 搜索结果计数 | ✅ | "共找到 X 条" |
| 首页仪表盘 | ✅ | 4 统计卡 + BarChart 趋势 + 热力图 |
| AI 每周回顾 | ✅ | DeepSeek AI 周报弹窗 |
| AI 智能问答 (RAG) | ✅ | FTS5 检索 Top5 → 每条截断1500字 → 聊天气泡 |
| Markdown 工具栏 | ✅ | 加粗/斜体/标题/列表/引用/代码 |
| AI 分析（日记+知识） | ✅ | DeepSeek API 摘要+标签 |
| AI 三件套按钮 | ✅ | 续写/润色/总结 PopupMenu |
| AI prompt 长度截断 | ✅ | `_truncate()` 4000/8000 字上限 |
| 语音输入（中文） | ✅ | `speech_to_text` + 权限引导 |
| 文件导入（TXT/MD/CSV/JSON） | ✅ | `file_picker` → `FileImporter` |
| 附件系统（拍照/相册/文档） | ✅ | 缩略图预览 + 类型图标 + 系统打开 |
| 权限拒绝引导 | ✅ | 相机/相册/麦克风引导弹窗 → openAppSettings |
| 深色模式三态切换 | ✅ | ThemeModeNotifier 即时生效 |
| 撤销/重做 | ✅ | UndoManager 快照栈 (50步) + 定时/操作前快照 |
| 页面转场动画 | ✅ | CustomTransitionPage fade+slide |
| 数据导出（含标签/分类/AI/附件） | ✅ | `share_plus` 文件分享 |
| 数据导入（含分类名匹配） | ✅ | `categoryName` 回退到 `categoryId` |
| 清空数据保留设置 | ✅ | `settingsTable` + FTS5 不删 |
| API Key 管理 | ✅ | FlutterSecureStorage + 保存即生效 |
| 隐私政策 | ✅ | 7 章节完整内容 BottomSheet |
| 全局错误兜底 | ✅ | PlatformDispatcher.onError |
| 应用图标 | ✅ | `flutter_launcher_icons` 青绿底 |
| Release 签名 | ✅ | keystore.jks |
| R8/ProGuard | ✅ | `isMinifyEnabled=true` + 序列化保护 |
| 网络安全 | ✅ | `network_security_config.xml` (仅 HTTPS) |
| allowBackup | ✅ | false（防止数据库泄露） |

---

## 七、审查与测试

### 7.1 审查历史

| 审查方 | 文件 | 发现问题 | 修复结果 |
|--------|------|---------|---------|
| Codex AI 审查 | `CODE_REVIEW.md` | 33 条（P0:5, P1:8, P2:3, 补充:4） | 全部修复 |
| Claude 子代理审查 | 逐文件审计 | P0:2, P1:5 | 全部修复 |
| 用户评估报告 | `APP_EVALUATION_REPORT.md` | 26 条（功能 Bug 7, UX 14, 代码质量 6） | 19/26 已修复 |
| V2 计划审查 | `ZHANJI_V2_PLAN.md` | 6 阶段 20+ 任务 | 全部执行 |
| 上线前全流程审计 | `APP_REAUDIT_REPORT.md` | P0:2, P1:8, P2:6 | 全部修复 |
| 构建前审查 | 本次会话 | 知识编辑器缺 PopScope, _hasChanges 不完整 | 全部修复 |

### 7.2 测试覆盖

| 测试文件 | 测试数 | 覆盖内容 |
|----------|--------|---------|
| `database_test.dart` | 28 | CRUD, FTS5 搜索, 标签, 设置, 分类预设, 批量删除 |
| `database_edge_cases_test.dart` | 11 | 约束边界, 并发冲突, DaisyDao/KowledgeDao/Emotion/DioClient |
| `tag_filter_test.dart` | 3 | `listByTag` JOIN 查询 |
| `stats_test.dart` | 4 | `countByEmotion`, `wordCountThisWeek`, `countByDay` |
| `widget_test.dart` | 1 | App 启动 smoke test |
| `widget_ui_test.dart` | 11 | Widget 渲染, EmptyState/LoadingIndicator 组件, UndoManager 逻辑 |
| `integration_test.dart` | 3 | 日记→标签→FTS5 全链路, 知识→分类→关联推荐, 统计查询 |
| **合计** | **67** | 全部通过 |

---

## 八、环境与构建

### 8.1 构建环境

| 组件 | 路径 |
|------|------|
| JDK | `C:\Program Files\Android\Android Studio\jbr` (JBR JDK 21) |
| Flutter | `C:\flutter` (3.38.5) |
| Android SDK | `%LOCALAPPDATA%\Android\Sdk` |
| 模拟器 | BlueStacks (adb connect 127.0.0.1:5555) |

### 8.2 构建命令

```powershell
# 管理员 PowerShell:
cd C:\AI\claudecode\projects\zhiji\zhiji_app
$env:JAVA_HOME="C:\Program Files\Android\Android Studio\jbr"
$env:PATH="$env:JAVA_HOME\bin;C:\flutter\bin;$env:PATH"
$env:PUB_HOSTED_URL="https://pub.flutter-io.cn"
$env:FLUTTER_STORAGE_BASE_URL="https://storage.flutter-io.cn"

# Debug APK（快速测试）
flutter build apk --debug

# Release APK（正式分发，分包）
flutter build apk --release --split-per-abi
```

### 8.3 常用开发命令

```bash
flutter analyze          # 代码检查（0 error, 0 warning）
flutter test             # 运行测试（67/67）
dart run build_runner build --delete-conflicting-outputs  # 代码生成
```

---

## 九、文档体系

| 文件 | 用途 |
|------|------|
| `CLAUDE.md` | Claude Code 自动加载：架构、命令、环境 |
| `DEV_DOC.md` | 开发文档：完整架构图、表结构、路由表、API 配置 |
| `DESIGN_SPEC.md` | 设计规格：OKLch 色彩映射、组件映射、SQL schema |
| `IMPLEMENTATION_PLAN.md` | 原始 6 阶段实施计划 |
| `CODE_REVIEW.md` | Codex AI 代码审查报告 |
| `APP_EVALUATION_REPORT.md` | 用户综合评估报告 |
| `ZHANJI_V2_PLAN.md` | V2 产品化实施手册 |
| `APP_LAUNCH_CHECKLIST.md` | Android 上线前 9 阶段完整流程 |
| `APP_AUDIT_REPORT.md` | 第一轮上线前评估报告 |
| `APP_REAUDIT_REPORT.md` | 第二轮逐项审计报告 |
| `PROJECT_SUMMARY.md` | 本文档 — 项目开发总览 |

---

## 十、交付物

| 文件 | 大小 | 说明 |
|------|------|------|
| `app-arm64-v8a-release.apk` | 20.7 MB | ARM64 设备（90% 手机） |
| `app-armeabi-v7a-release.apk` | 18.5 MB | 老旧 32 位设备 |
| `app-x86_64-release.apk` | 22.0 MB | BlueStacks / 模拟器 |
| `keystore/zhiji.jks` | — | 签名密钥 |

---

*文档版本 v3.1 · 2026-06-17 · 基于对 40 个 Dart 源文件、7 个测试文件的完整梳理*
