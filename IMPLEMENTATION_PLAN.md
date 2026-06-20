# 实施计划 — 知记 Flutter APK

## 技术选型

| 项 | 选择 | 理由 |
|---|---|---|
| 状态管理 | Riverpod 3.x | 编译安全、内建异步、无 BuildContext 依赖 |
| 数据层 | drift (SQLite ORM) | 关系型数据、类型安全查询、Stream 响应式 |
| 路由 | go_router | 官方推荐、StatefulShellRoute 底部 Tab |
| HTTP | dio | 拦截器链、SSE 流式解析 |
| 图谱 | CustomPainter | 对应原型的 Canvas 2D 方案 |
| 安全存储 | flutter_secure_storage | API Key 加密 |

## 依赖清单

```yaml
dependencies:
  flutter_riverpod: ^3.0.0
  go_router: ^14.8.0
  drift: ^2.21.0
  sqlite3_flutter_libs: ^0.5.0
  path_provider: ^2.1.0
  path: ^1.9.0
  flutter_secure_storage: ^9.2.0
  dio: ^5.7.0
  freezed_annotation: ^2.4.0
  json_annotation: ^4.9.0
  flutter_markdown: ^0.7.0
  file_picker: ^8.0.0
  share_plus: ^10.0.0
  intl: ^0.19.0
  connectivity_plus: ^6.0.0

dev_dependencies:
  build_runner: ^2.4.0
  drift_dev: ^2.21.0
  freezed: ^2.5.0
  json_serializable: ^6.8.0
  riverpod_generator: ^3.0.0
  flutter_lints: ^4.0.0
  mocktail: ^1.0.0
```

---

## 分阶段执行

### Phase 1：项目脚手架

**目标**：可运行白标 App，底部导航切换流畅，所有路由可导航

| # | 任务 | 产出 | 验证 |
|---|---|---|---|
| 1.1 | `flutter create zhiji_app` | Flutter 项目 | `flutter run` 在 Chrome/模拟器启动 |
| 1.2 | 写入 `pubspec.yaml` 依赖 | 完整依赖 | `flutter pub get` 成功 |
| 1.3 | 创建全部目录结构 | `lib/core/` `lib/features/` 等 | 目录存在 |
| 1.4 | 实现 `core/theme/` — color_tokens, dimensions, app_theme | Light 主题 | 视觉效果与原型的 OKLch 色板一致 |
| 1.5 | 编写 `core/router/app_router.dart` — GoRouter + StatefulShellRoute | 完整路由表 | 所有路径可导航到占位页面 |
| 1.6 | 编写 `core/widgets/app_shell.dart` — Scaffold + NavigationBar 4 Tab | 底部导航骨架 | 4 Tab 切换正确，状态保持 |
| 1.7 | 编写 `main.dart` 入口 | ProviderScope + MaterialApp.router | App 启动正常 |
| 1.8 | 编写 Dio 客户端骨架 | `core/network/dio_client.dart` | `flutter analyze` 无 error |

---

### Phase 2：数据层

**目标**：完整数据库 schema、DAO、Repository，单元测试通过

| # | 任务 | 产出 | 验证 |
|---|---|---|---|
| 2.1 | 定义 Drift 表结构（全部 7 表 + FTS5）| `lib/core/database/app_database.dart` | `build_runner build` 代码生成成功 |
| 2.2 | 实现 DiaryDao（CRUD + 按日期分组查询）| `lib/core/database/daos/diary_dao.dart` | 单元测试 CRUD |
| 2.3 | 实现 KnowledgeDao（CRUD + 按分类查询）| `lib/core/database/daos/knowledge_dao.dart` | 单元测试 CRUD |
| 2.4 | 实现 TagDao / CategoryDao / SettingsDao | 对应 DAO 文件 | 单元测试 |
| 2.5 | 预设 6 个分类数据 `INSERT` | 数据库启动时自动初始化 | `categories` 表有 6 行 |
| 2.6 | 实现 FTS5 搜索索引（insert/update/delete 触发器）| 搜索索引同步 | 新增日记后搜索能命中 |
| 2.7 | 编写 Repository 层（ViewModel → Repo → DAO）| `lib/features/*/domain/*_repository.dart` | 集成测试 |

---

### Phase 3：核心屏幕

**目标**：日记和知识 CRUD 闭环可用，首页数据联动

| # | 任务 | 产出 | 验证 |
|---|---|---|---|
| 3.1 | `DiaryListScreen` — 日期分组列表 + 筛选 Chip + 空状态 | 日记列表页 | 手动测试：写日记 → 列表可见 |
| 3.2 | `DiaryEditorScreen` — 情绪选择 + 标题 + 正文 + 标签 + AI 面板 | 日记编辑页 | 手动测试：新建/编辑/保存 |
| 3.3 | `KnowledgeBrowseScreen` — 分类网格 + 列表 + 视图切换 | 知识库浏览 | 手动测试：分类筛选、视图切换 |
| 3.4 | `KnowledgeEditorScreen` — 表单 + 文件上传 + 标签 | 知识编辑页 | 手动测试：新建/编辑/保存 |
| 3.5 | `KnowledgeDetailScreen` — Markdown 渲染 + AI 摘要 + 附件 + 关联推荐 | 知识详情页 | 手动测试：查看详情 |
| 3.6 | `HomeScreen` — 统计卡片（实时计数）+ AI 建议 + 最近条目 | 首页仪表盘 | 手动测试：数据联动 |
| 3.7 | 共享组件：`EmptyState` `LoadingIndicator` `TagChip` | 工具组件 | 各屏幕复用 |

---

### Phase 4：高级功能

**目标**：搜索可用的 AI 功能，知识图谱可交互

| # | 任务 | 产出 | 验证 |
|---|---|---|---|
| 4.1 | `SearchScreen` — FTS5 搜索 + 类型筛选 + 结果高亮 | 搜索页 | FTS5 查询返回正确 |
| 4.2 | `SearchHistory` — 搜索历史记录 + 持久化 | 搜索历史 | 关闭 app 重启后历史仍在 |
| 4.3 | `AIApiService` — DeepSeek `/chat/completions` 流式调用 | API 封装 | curl 模拟 → 返回正确 |
| 4.4 | 日记 AI 分析 — 摘要 + 标签建议 | DiaryEditor 内 AI 面板 | 分析结果写入数据库 |
| 4.5 | 知识 AI 摘要 — 摘要 + 关键词 | KnowledgeEditor / Detail | 摘要结果展示 |
| 4.6 | `GraphScreen` — CustomPainter 知识图谱（力导向图）| 图谱页 | 节点拖拽 + 缩放 |
| 4.7 | 全局 Toast — `SnackBar` 封装 | `core/utils/toast_utils.dart` | 保存/删除等操作后弹出 |

---

### Phase 5：设置与数据管理

**目标**：设置功能完整可用

| # | 任务 | 产出 | 验证 |
|---|---|---|---|
| 5.1 | `SettingsScreen` — API Key + 深色模式 + AI 开关 + 版本信息 | 设置页 | UI 完整，Switch 可操作 |
| 5.2 | API Key 加密存储 → `flutter_secure_storage` | 安全存储 | Key 不存明文 DB |
| 5.3 | JSON 导出 — 所有数据 → JSON 文件 | `core/utils/export_import_utils.dart` | 导出文件可分享 |
| 5.4 | JSON 导入 — 解析 + 去重 + 合并 | 同上 | 导入后数据正确 |
| 5.5 | 数据清空 — 确认对话框 + 级联删除 | 设置页红按钮 | 清空后回到空状态 |

---

### Phase 6：测试、优化、打包

**目标**：Release APK 在真机正常运行

| # | 任务 | 产出 | 验证 |
|---|---|---|---|
| 6.1 | 编写 Repository 单元测试 | test/ 目录 | `flutter test` 通过 |
| 6.2 | 编写核心 Widget 测试 | `DiaryCard` `KnowledgeCard` 渲染测试 | `flutter test` 通过 |
| 6.3 | 编写 1 个 E2E 集成测试 | 写日记 → 搜索 → 查看 | 脚本通过 |
| 6.4 | `flutter analyze` → 0 warning, 0 error | 代码检查 | CI 级干净 |
| 6.5 | Release APK 构建 — `flutter build apk --release` | `build/app/outputs/zhiji.apk` | APK < 30MB |
| 6.6 | AAB 构建 — `flutter build appbundle --release` | `build/app/outputs/zhiji.aab` | Google Play 可上传 |
| 6.7 | 真机验证 — 安装 → 启动 → 核心流程 | 真机截图 | 无崩溃、流畅 |

---

## 质量检查清单

每个 Phase 完成后执行：

- [ ] `flutter analyze` 无 error / warning
- [ ] 修改过的文件无死代码
- [ ] 所有新增代码匹配原设计 Token（用 ColorScheme 而非硬编码）
- [ ] 手动走通核心用户流程
- [ ] 代码改动量合理（不应出现千行级的无关重构）


---

# 附录：v4 Agent 首屏实施（2026-06-17 ~ 2026-06-21）

> 以下为 v4 实际实施内容，基于上述原始计划的架构升级

## v4 核心变更

| 项 | 原计划 | v4 实际 |
|----|--------|---------|
| 首屏 | HomeScreen 仪表盘 | ChatScreen Agent 对话 |
| 导航 | 4-Tab 底部栏 | FAB → BottomSheet 功能抽屉 |
| AI | RAG 问答 + 编辑器 AI | ReAct Agent 自主调用 7 工具 |
| 路由 | StatefulShellRoute 4 分支 | StatefulShellRoute 1 分支 (仅 Agent) |
| APK | 三包 20.7/18.5/22.0MB | 单包 58.8MB |

## v4 新增实施步骤

| # | 任务 | 产出 | 验证 |
|---|------|------|------|
| V4.1 | 创建 Agent 核心：agent_service (ReAct 循环 5 轮 + 3 层超时), agent_provider (Riverpod), agent_memory (10 主题追踪), tool.dart (基类 + ToolRegistry) | `lib/core/agent/` | 手动对话测试 |
| V4.2 | 实现 7 个 Agent 工具：search_knowledge, save_to_knowledge, write_diary, get_diary_stats, list_categories, read_attachment, web_search | `lib/core/agent/tools/` | 各工具单元测试 |
| V4.3 | 升级路由：app_router 改为单分支 StatefulShellRoute, AppShell 改为 FAB→BottomSheet | `lib/core/router/` + `lib/core/widgets/app_shell.dart` | 首屏对话 + 底部抽屉入口 |
| V4.4 | chat_screen 升级：ReAct 循环调用, 会话历史持久化 (agent_messages 表), 附件上下文传递 | `lib/features/chat/chat_screen.dart` | 多轮对话 + 重启恢复 |
| V4.5 | 数据库升级：新增 agent_messages 表 (schema v2), retryOnLock 并发写入保护 | `lib/core/database/` | migration 测试 |
| V4.6 | Agent 测试套件：agent_service_test, agent_messages_test, agent_memory_test, tool_error_test, web_search_test 等 | `test/` | `flutter test` 19 文件 |
| V4.7 | 修复多轮对话角色映射 bug：_buildHistory 中 `ai` → `assistant` | `features/chat/chat_screen.dart:96` | 连续对话不报错 |
