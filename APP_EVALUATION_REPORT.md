# 知记 (Zhiji) — 综合评估报告

> 评估日期：2026-06-16 | 评估范围：全部 32 个 Dart 源文件 + 设计文档 + 测试
> 基于：`flutter analyze` / `flutter test`(42/42) 实际运行 + 逐文件代码审查

---

## 一、项目健康概览

| 维度 | 状态 | 说明 |
|------|------|------|
| `flutter analyze` | ⚠️ 1 error, 1 info | `speech_to_text` 包导入解析失败 |
| `flutter test` | ✅ 42/42 全部通过 | 覆盖 CRUD、并发、FTS5、边界值 |
| Debug APK | 158MB | 未做 R8 代码缩减和资源混淆 |
| 代码文件 | 32 个 Dart 源 | 架构清晰，`core/` + `features/` 分层合理 |

---

## 二、🔴 功能性 Bug

### 1. 知识编辑器分类下拉框不更新
- **文件**：`zhiji_app/lib/features/knowledge/knowledge_editor_screen.dart:168`
- **问题**：`DropdownButtonFormField<int>(initialValue: _categoryId, ...)`，`initialValue` 仅在首次构建时生效，编辑已有条目时 `setState` 后下拉框显示的不是当前已保存的分类。
- **修复**：`initialValue` → `value`

### 2. 标签计数竞态条件
- **文件**：`zhiji_app/lib/core/database/daos/common_daos.dart:21-27`
- **问题**：`getOrCreate` 是「INSERT OR IGNORE → 查询 → +1 → UPDATE」三步非原子操作，并发场景下 `usageCount` 会不准确。
- **修复**：使用 SQLite `ON CONFLICT(name) DO UPDATE SET usage_count = usage_count + 1` 一条语句原子完成。

### 3. 语音输入依赖缺失
- **文件**：`zhiji_app/lib/core/widgets/voice_input_button.dart:2`
- **问题**：`flutter analyze` 报 `uri_does_not_exist: package:speech_to_text/speech_to_text.dart`，该包在项目中未正确解析，**语音输入功能完全不可用**。
- **修复**：重新执行 `flutter pub get` 并确认包正确安装。

### 4. 搜索历史不持久化
- **文件**：`zhiji_app/lib/features/search/search_screen.dart:16`
- **问题**：`_history` 是内存中的 `List<String>`，App 退出后全部丢失。
- **修复**：将搜索历史写入 `SharedPreferences` 或 `settings_table`。

### 5. 数据清空后分类丢失
- **文件**：`zhiji_app/lib/features/settings/settings_screen.dart:226-243`
- **问题**：清空数据时删除了 `category_models` 表的 6 个预设分类，清空后知识库分类功能瘫痪。
- **修复**：清空后重新执行预设分类 INSERT，或排除 `category_models` 表。

### 6. 导入导出不完整
- **文件**：`zhiji_app/lib/features/settings/settings_screen.dart:55-100`
- **导出缺失**：不包含标签关联（`diary_tags` / `knowledge_tags`）、不保存为文件（仅复制到剪贴板）
- **导入缺失**：不恢复标签关联、不恢复分类 ID（`categoryId` 被设为 null）、无 JSON Schema 校验、不处理 `aiSummary`/`aiTags`
- **修复**：补全标签和分类的导入导出，增加文件保存功能，添加 JSON 格式校验。

### 7. 日记筛选用硬编码字符串
- **文件**：`zhiji_app/lib/features/diary/diary_list_screen.dart:18-24`
- **问题**：筛选用 `bodyMarkdown.contains('工作')` 等硬编码文本匹配，而非基于已有的 `diary_tags` 多对多关联表。
- **修复**：基于标签表进行筛选，支持自定义筛选维度。

---

## 三、🟡 用户体验问题

### 8. AI 分析是模拟的
- **文件**：`zhiji_app/lib/features/diary/diary_editor_screen.dart` 中 `_simulateAI()` 方法
- **问题**：点击"分析这篇日记"返回硬编码的固定文本和标签。用户设置里输入了 DeepSeek API Key 却完全没用上。
- **修复**：接入真实 DeepSeek `/chat/completions` 流式 API。

### 9. 知识编辑器没有 AI 分析
- **文件**：`zhiji_app/lib/features/knowledge/knowledge_editor_screen.dart`
- **问题**：日记编辑器有 AI 面板，但知识编辑器完全没有。知识条目更需要自动摘要和关键词提取。
- **修复**：在知识编辑器中添加与日记编辑器同等的 AI 分析面板。

### 10. 首页"人物"图标无功能
- **文件**：`zhiji_app/lib/features/home/home_screen.dart:34`
- **问题**：`IconButton(icon: Icon(Icons.person_outline), onPressed: () {})` — 空操作，用户点击无任何反馈。
- **修复**：移除或赋予实际功能（如跳转个人统计/设置）。

### 11. 无未保存退出确认
- **问题**：在编辑器中修改内容后，按返回键直接退出，不弹出"是否放弃修改"确认对话框，容易误操作丢失内容。
- **修复**：使用 `WillPopScope`（或 `PopScope`）拦截返回事件，检测是否有未保存修改。

### 12. 无深色模式手动切换
- **问题**：App 只跟随系统深色模式（`ThemeMode.system`），没有手动切换开关。很多用户习惯白天手动开深色模式。
- **修复**：设置页增加深色模式三态开关（跟随系统 / 浅色 / 深色），持久化到 `settings_table`。

### 13. "最近更新"标签与功能不符
- **文件**：`zhiji_app/lib/features/knowledge/knowledge_detail_screen.dart:50-54`
- **问题**：虽然 UI 标签已改为"最近更新"，但调用的 `listRecent(3)` 只能返回最近条目，而非基于标签/分类的真正关联推荐。
- **修复**：实现基于共同标签或同分类的关联推荐算法。

### 14. 无新手引导
- **问题**：打开 App 直接看到空首页，没有任何引导。用户需要自己探索才知道能做什么。
- **修复**：添加 3-4 步的新手引导页，介绍日记、知识库、AI 分析、搜索功能。

### 15. 编辑器无撤销/重做
- **问题**：编辑器内没有撤销/重做按钮，仅依赖系统键盘默认行为。
- **修复**：在编辑器工具栏增加撤销/重做图标按钮。

### 16. 知识详情页不显示分类
- **文件**：`zhiji_app/lib/features/knowledge/knowledge_detail_screen.dart`
- **问题**：只显示标题、日期、摘要和正文，没有显示该条目属于哪个分类。
- **修复**：结合 `category_models` 表查询并在详情页顶部显示分类名称和图标。

### 17. 无多选/批量操作
- **问题**：无法批量删除日记或知识条目，只能一条一条操作。
- **修复**：长按进入多选模式，支持批量删除和导出。

### 18. 搜索结果无数量提示
- **文件**：`zhiji_app/lib/features/search/search_screen.dart`
- **问题**：只展示结果列表，不显示"共找到 X 条结果"。
- **修复**：在搜索结果列表上方添加 `共找到 ${results.length} 条结果`。

### 19. 知识库列表无下拉刷新
- **文件**：`zhiji_app/lib/features/knowledge/knowledge_browse_screen.dart`
- **问题**：仅日记列表支持 `RefreshIndicator`，知识库浏览列表不支持。
- **修复**：为知识库列表添加 `RefreshIndicator`。

### 20. 无附件/图片支持
- **问题**：数据库预留了 `filePaths` 字段，但 UI 从未使用。不能附加图片、不能拍照插入、不能预览已附加的文件。
- **修复**：编辑器增加图片选择/拍照按钮，详情页展示附加文件。

---

## 四、🟢 代码质量问题

### 21. `Navigator.pushNamed` 与 GoRouter 混用
- **影响文件**：`home_screen.dart`（3 处）、`diary_list_screen.dart`（1 处）、`diary_editor_screen.dart`（1 处）、`knowledge_browse_screen.dart`（2 处）、`knowledge_detail_screen.dart`（2 处）、`search_screen.dart`（1 处）
- **问题**：多处使用 `Navigator.of(context).pushNamed` 而非 GoRouter 的 `context.push()`。虽然目前 GoRouter 能拦截运行，但不是标准用法，升级可能失效。
- **修复**：统一改用 `context.push()` / `context.pop()`。

### 22. 标签删除 N+1 查询
- **文件**：`zhiji_app/lib/features/diary/diary_editor_screen.dart:103-106`
- **问题**：对每个旧标签逐条 `DELETE`，而不是按 `diaryEntryId` 批量删除后逐一插入新标签。
- **修复**：先 `DELETE FROM diary_tags WHERE diary_entry_id = ?`，再逐条 INSERT。

### 23. APK 体积过大（158MB）
- **问题**：Debug APK 158MB，Release 版本预计也在 30MB+。
- **优化方向**：启用 `--split-per-abi`，启用更激进的代码缩减（R8 fullMode），移除未使用的资源。

### 24. 依赖版本偏老
- **问题**：50 个包有更新版本（`flutter_riverpod` 2→3、`freezed` 2→3、`go_router` 14→17 等），存在技术债务。
- **建议**：逐步升级关键依赖，优先 `flutter_riverpod` 和 `go_router`。

### 25. web 配置文件仍是 Flutter 默认模板
- **文件**：`zhiji_app/web/index.html`、`zhiji_app/web/manifest.json`
- **问题**：title 为 "zhiji"，description 为默认模板文本。
- **修复**：更新为"知记 — AI 原生个人知识管理应用"。

### 26. 知识编辑器工具栏缺少字数统计
- **问题**：日记编辑器工具栏有「XX 字」统计，知识编辑器没有。
- **修复**：统一添加。

---

## 五、📱 与市面精美 App 的差距对比

### 对标 Flomo（浮墨笔记）

| 维度 | 知记当前 | Flomo | 差距 |
|------|---------|-------|------|
| 输入体验 | 点+号→选类型→编辑→保存（4 步） | 打开即写，无分类选择（1 步） | 步骤多，不够轻量 |
| 时间线 | 日期分组列表 | 瀑布流 + 时间轴 | 缺少时间线可视化 |
| AI 能力 | 模拟/假的 | 真正的 AI 回顾/关联 | 核心功能缺失 |
| 多平台 | Android 单平台 | iOS / Android / Web / 微信 | 平台覆盖不足 |
| 每日回顾 | 无 | 自动推送历史"每日回顾" | 无回顾机制 |
| 写作热力图 | 无 | 有（写作日历） | 缺少激励设计 |
| 分享 | 无 | 生成卡片分享 | 无社交传播 |
| 标签系统 | 基础多对多 | 层级标签 + 热门标签 | 管用但不够灵活 |

### 对标 Notion

| 维度 | 知记当前 | Notion | 差距 |
|------|---------|--------|------|
| 编辑器 | 纯文本 Markdown（无工具栏） | 富块编辑器（`/` 命令、拖拽） | 编辑体验差距极大 |
| 数据库视图 | 无 | 表格 / 看板 / 日历 / 画廊 / 时间线 | 只有列表视图 |
| 模板 | 无 | 丰富模板库 | 无 |
| 协作 | 无 | 多人实时协作 | 定位不同，可接受 |
| AI | 模拟 | Notion AI（写作/翻译/总结/搜索） | 核心差距 |
| 网页剪藏 | 无 | Web Clipper 浏览器插件 | 无 |
| 快捷键 | 无 | 大量键盘快捷键 | 仅移动端可接受 |
| 关联数据库 | 无 | Relation / Rollup 字段 | 无 |

### 对标 Day One（日记类）

| 维度 | 知记当前 | Day One | 差距 |
|------|---------|---------|------|
| 情绪追踪 | 8 种 emoji（单选） | 丰富情绪 + 图表分析 | 缺统计/趋势图 |
| 位置标记 | 无 | 自动定位 + 地图视图 | 缺场景感 |
| 天气 | 无 | 自动记录天气 | 缺氛围感 |
| 多媒体 | 无 | 照片 / 视频 / 音频 | 缺多媒体能力 |
| 时间线视图 | 列表 | 时间线 + 地图 + 日历 | 视图单一 |
| 写作提示 | 无 | 每日写作提示/问题 | 缺引导 |
| 密码锁 | 无 | TouchID / FaceID | 隐私不足 |
| 导出格式 | JSON（剪贴板） | PDF / TXT / JSON / 书籍打印 | 导出格式单一 |

### 综合差距总结

| 差距类别 | 具体表现 | 优先级 |
|----------|---------|--------|
| **AI 真实度** | 模拟数据，未接入任何 API，与 "AI 原生" 定位严重不符 | 🔴 最高 |
| **编辑体验** | 纯文本无工具栏，输入步骤多，不比备忘录好用 | 🔴 最高 |
| **数据可视化** | 无情绪统计/趋势/热力图，纯列表展示 | 🟡 高 |
| **多媒体** | 不支持和弦图片/语音/视频 | 🟡 高 |
| **细节打磨** | 无动画、无引导、无锁定、多处空按钮 | 🟡 高 |
| **多平台** | 仅 Android | 🔵 中 |
| **社交/分享** | 无分享卡片、无导出美化 | 🔵 中 |
| **模板/自动化** | 无模板、无自动回顾 | 🔵 中 |

---

## 六、🎯 改进优先级路线图

### 第一阶段：修 Bug（1 周）

1. 修复知识编辑器 `initialValue` → `value`
2. `getOrCreate` 标签计数原子化
3. 修复 `speech_to_text` 依赖解析
4. 搜索历史持久化
5. 数据清空后恢复预设分类
6. `Navigator.pushNamed` 统一改为 `context.push()`
7. 标签删除去 N+1

### 第二阶段：补核心体验（2 周）

8. 接入真实 DeepSeek API（日记 AI 分析 + 知识 AI 摘要）
9. 知识编辑器添加 AI 分析面板
10. 编辑器未保存退出确认
11. 深色模式手动切换
12. 首页移除/替换无功能按钮
13. 导入导出补全（标签 + 分类 + 文件保存）
14. 知识详情页显示分类名

### 第三阶段：UX 打磨（2 周）

15. 新手引导流程（3-4 步）
16. 情绪统计图表（周/月趋势）
17. 写作热力图/日历
18. 批量操作（多选删除/导出）
19. Markdown 工具栏（加粗/标题/列表快捷插入）
20. 知识库列表下拉刷新
21. 搜索结果数量提示

### 第四阶段：竞争力提升（持续）

22. 图片/附件支持
23. 知识图谱可视化
24. 每日回顾推送
25. 密码/生物识别锁
26. 分享卡片生成

### 长远规划

27. Web + iOS 多平台
28. 网页剪藏工具
29. 模板系统
30. 云端同步
31. 基于标签/分类的关联推荐算法

---

## 七、正面评价

以下方面做得不错，值得保持：

- **分层架构清晰**：`core/`（主题/路由/数据库/组件）+ `features/`（屏幕）职责分明
- **数据库设计精巧**：7 表 + FTS5 全文搜索 + 6 个 SQLite 触发器自动同步，奇偶 rowid 编码避免冲突
- **测试覆盖扎实**：42 个测试覆盖 CRUD、边界值、并发、FTS5、枚举、DioClient，全部通过
- **主题系统规范**：MD3 `ColorScheme.fromSeed` + 完整 Typography / Spacing / Radius / Elevation Token 体系
- **错误处理到位**：所有 screen 的 async 分支均有 `debugPrint` + 用户友好提示，有全局 `PlatformDispatcher.onError` 兜底
- **平台适配**：使用 `flutter_secure_storage` 加密存储 API Key，`StrictMode` 已在 `MainActivity.kt` 中启用
- **代码生成标准化**：drift DAO + 路由 + Riverpod 均走标准 `build_runner` 生成流程，无手写重复代码

---

## 八、环境问题备注

以下为 App 代码之外的环境/构建问题：

1. **Win11 24H2 Gradle 环回连接 bug**：需管理员终端 + `netsh int ipv4/ipv6 set global loopbacklargemtu=disable`
2. **`_JAVA_OPTIONS` 环境变量污染**：Claude Code 进程级注入的 `_JAVA_OPTIONS` 会导致 Gradle daemon 读取错误的 `SelectorProvider`
3. **Web 构建不可用**：`dart:ffi`（sqlite3）在 Web 平台不可用
4. **`org.gradle.java.home` 硬编码**：`gradle.properties` 中硬编码了本机 JDK 路径，跨环境失效
5. **AndroidManifest.xml**：`android:label="zhiji"` 建议改为 `"知记"`

---

*报告基于对全部 32 个 Dart 源文件的逐文件审查，辅以 `flutter analyze` + `flutter test`(42/42) 自动化验证生成。*
