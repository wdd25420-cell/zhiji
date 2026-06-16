# 知记 APP — 重新审计报告

> 审计日期：2026-06-17
> 审计方法：7 步系统化审查，逐文件扫描 + 自动化工具 + 全量 grep 验证
> 审查范围：39 个 Dart 源文件、5 个测试文件、Android 全量配置文件

---

## 审计过程记录

| 步骤 | 内容 | 方法 | 耗时 |
|------|------|------|------|
| 第1步 | 静态分析全量扫描 | `flutter analyze` + `flutter pub outdated` + `flutter test` | 2min |
| 第2步 | 代码质量逐文件扫描 | grep debugPrint/color/URL/key + mounted 核查 | 1min |
| 第3步 | 架构约定合规核查 | grep Navigator/setState/dispose/catch | 1min |
| 第4步 | Android 原生层审查 | build.gradle.kts + proguard + manifest + network_config + MainActivity | 1min |
| 第5步 | 测试体系审查 | 5 个测试文件逐 group/test 统计 | 1min |
| 第6步 | UX/UI 逐屏幕审查 | grep tooltip/AlertDialog/RefreshIndicator/EmptyState/Loading/SnackBar | 1min |
| 第7步 | 核心功能链路走查 | RAG/附件/批量删除/撤销重做/搜索/导入导出 逐链代码追踪 | 5min |

---

## 发现问题汇总

### 🔴 P0 — 阻塞构建/编译（2 项）

#### P0-1: `voice_input_button.dart:70` — 2 个编译错误（由前一轮误修改引入）

**位置**: [`lib/core/widgets/voice_input_button.dart:70`](projects/zhiji/zhiji_app/lib/core/widgets/voice_input_button.dart:70)
**现象**:
```
error - The named parameter 'options' isn't defined
error - The name 'SpeechListenOptions' isn't a class
```
**根因**: `speech_to_text: ^7.0.0` 的 `listen()` 方法使用 `localeId` 直接命名参数，不支持 `options` + `SpeechListenOptions`。这是上一轮修复时错误地将 `localeId: 'zh_CN'` 改成了 `options: const SpeechListenOptions(localeId: 'zh_CN')`。
**原始代码**（正确）:
```dart
// ignore: deprecated_member_use
await _speech.listen(
  onResult: ...,
  localeId: 'zh_CN',
);
```
**修复**: 还原为原始写法，保留 `// ignore: deprecated_member_use`。
**影响**: 阻止 `flutter analyze` 清零、阻止 `widget_test.dart` 编译、测试从 53/53 降到 52/53。

#### P0-2: `AndroidManifest.xml:9` — `allowBackup="true"` 数据库泄露风险

**位置**: [`android/app/src/main/AndroidManifest.xml:9`](projects/zhiji/zhiji_app/android/app/src/main/AndroidManifest.xml:9)
**现象**: 应用允许系统级备份（`adb backup` + Android 6.0+ 自动备份到 Google Drive），SQLite 数据库以明文存储。
**风险**: 用户数据（日记内容、知识内容、标签、设置）可通过备份提取。
**修复**:
```xml
android:allowBackup="false"
```
或在 `<application>` 内添加:
```xml
android:fullBackupContent="@xml/backup_rules"
```
配合 `res/xml/backup_rules.xml` 排除数据库文件。
**注意**: `FlutterSecureStorage` 默认不允许备份，API Key 不受影响。

---

### 🟡 P1 — 强烈建议修复（8 项）

#### P1-1: `emotion_trend_chart.dart:53,139` — 2 处 unnecessary_underscores

**位置**: [`lib/features/home/widgets/emotion_trend_chart.dart:53`](projects/zhiji/zhiji_app/lib/features/home/widgets/emotion_trend_chart.dart:53) + `:139`
**现象**: `(_, __)` 中双下划线冗余。
**修复**: 改为 `(_, _2)` 或单个命名参数。

#### P1-2: `knowledge_editor_screen.dart:332` — deprecated `value` 参数

**位置**: `lib/features/knowledge/knowledge_editor_screen.dart:332`
**现象**: `DropdownButtonFormField` 使用已 deprecated 的 `value` 参数。
**修复**: 保留 `// ignore: deprecated_member_use`，等待 Flutter 3.34+ 的 `initialValue` API 稳定。

#### P1-3: 2 处 `use_build_context_synchronously` lint info

**位置**:
- `voice_input_button.dart:53` — `_toggleListening()` 中 await 后调用 `ScaffoldMessenger.of(context)`
- `settings_screen.dart:359` — import/clear 操作后的 SnackBar

**评估**: 两处都有 `mounted` 检查，是 lint 误报。但严格来说应在 `if (!context.mounted) return` 后使用 `context`（而非 `mounted` 字段）。
**修复**: 将 `if (!mounted) return` 改为 `if (!context.mounted) return`（Flutter 3.7+）。

#### P1-4: 依赖过期 — 14 个 direct 依赖 + 3 个弃用包

**关键过期项**:
| 包 | 当前 | 最新 | 风险 |
|-----|------|------|------|
| `file_picker` | 8.3.7 | 11.0.2 | 3 大版本，API 可能不兼容 |
| `go_router` | 14.8.1 | 17.3.0 | 3 大版本 |
| `flutter_riverpod` | 2.6.1 | 3.3.2 | Riverpod 3.x breaking changes |
| `fl_chart` | 0.69.2 | 1.2.0 | 首个稳定版，API 变化 |
| `permission_handler` | 11.4.0 | 12.0.3 | 大版本 |
| `share_plus` | 10.1.4 | 13.1.0 | 3 大版本 |

**弃用包**（传递依赖，暂不阻塞）: `js`, `build_resolvers`, `build_runner_core`

**建议**: `flutter pub upgrade --major-versions` + 全量回归测试。

#### P1-5: `proguard-rules.pro` — 缺少 freezed/json_serializable keep 规则

**位置**: `android/app/proguard-rules.pro`
**缺漏**: 未保护 `freezed` 生成的 `fromJson`/`toJson` 方法和 `json_serializable` 的 `*.g.dart` 文件。
**风险**: R8 可能移除序列化相关方法。
**修复**: 添加:
```proguard
# Freezed / json_serializable
-keep class * extends com.google.gson.TypeAdapter
-keepattributes RuntimeVisibleAnnotations
-keep class * implements java.io.Serializable
```

#### P1-6: `key.properties` — 无 git 保护

**位置**: `android/key.properties`
**现象**: 项目不在 git 仓库中，keystore 密码文件无 gitignore 保护。
**修复**: 项目初始化 git 后确保 `.gitignore` 包含:
```
android/key.properties
*.jks
```

#### P1-7: 无集成测试 — 核心用户旅程未验证

以下链路 0 条集成测试覆盖：
- 写日记 → 保存 → 首页出现
- FTS5 搜索 → 点击结果 → 查看详情
- 知识条目编辑 → AI 分析 → 保存
- 导入 JSON → 数据合并 → 列表刷新
- AI 问答 → FTS5 检索 → DeepSeek 回答

#### P1-8: 无 Widget 测试 — 屏幕状态未覆盖

8 个屏幕中仅 `widget_test.dart` (smoke test) 覆盖，且当前因 P0-1 编译失败。
缺少：空状态渲染测试、加载状态测试、错误状态测试、交互测试。

---

### 🟢 P2 — 锦上添花（6 项）

#### P2-1: RAG 上下文无长度限制

**位置**: `chat_screen.dart:42-47`
**现象**: `results.take(5).map(...)` 将 Top 5 搜索结果完整拼接为 context，如果每条内容上万字，会超出 DeepSeek API 的 token 限制。
**修复**: 给每条 `body` 加截断：`body.length > 1000 ? '${body.substring(0, 1000)}...' : body`

#### P2-2: AI prompt 无内容长度截断

**位置**: `ai_api_service.dart` — `analyzeDiary`/`analyzeKnowledge`
**现象**: `$title\n$content` 直接传入 prompt，超长日记可能超过模型上下文窗口。
**修复**: 在 `_post()` 之前截断 `content` 到 4000 字符。

#### P2-3: 页面转场动画单一

**现象**: 仅 `diary_list_screen.dart:299` 一处 `AnimatedSwitcher`。GoRouter 全屏路由使用默认 Material 转场，无自定义 fade/slide 效果。
**修复**: 给 GoRouter 的 `pageBuilder` 加 `CustomTransitionPage`。

#### P2-4: 权限拒绝引导不完整

**现象**: `voice_input_button.dart:44-50` 对麦克风权限拒绝有 Dialog 引导。但拍照 (`CAMERA`) 和相册 (`image_picker` 内部使用 `READ_EXTERNAL_STORAGE`) 在拒绝后仅静默失败，无引导弹窗。
**修复**: `file_attachment_manager.dart` 的 `takePhoto()` 和 `pickImages()` 在返回空时检查权限状态并引导。

#### P2-5: 无合规隐私政策内容

**位置**: `settings_screen.dart` 隐私政策入口
**现象**: 设置页有入口，但内容为占位。
**修复**: 编写隐私政策页面，说明：数据全本地存储、DeepSeek API 用于 AI 功能、用户可随时清空数据或卸载。

#### P2-6: 无新手引导 / Onboarding

**现象**: 首次打开直接进入首页，无任何功能引导。
**建议**: 3-4 屏引导页，介绍核心功能。

---

## 各阶段评分

```
阶段                   得分    关键问题
──────────────────────────────────────────
一、代码质量           72/100  P0-1(编译错误)、P1-1~4
二、测试体系           30/100  P0-1(编译错误)、P1-7(集成)、P1-8(Widget)
三、安全与隐私         55/100  P0-2(allowBackup)、P1-6(key无git保护)
四、性能与兼容性       40/100  P2-1(RAG无截断)、P2-2(AI无截断)、无性能测量
五、用户体验           68/100  P2-3(转场)、P2-4(权限引导)、P2-6(Onboarding)
六、合规与法律         10/100  P2-5(隐私政策空)
七、商店准备            5/100  全缺
八、构建与签名         65/100  P1-5(proguard缺规则)、P1-6(key.properties)
九、发布与监控          5/100  全缺
──────────────────────────────────────────
综合得分: 39/100
```

---

## 修复执行顺序

```
第1轮 (30min):
  P0-1: 回滚 voice_input_button → 恢复编译 + 测试通过
  P0-2: allowBackup 改为 false

第2轮 (2h):
  P1-1: emotion_trend_chart underscores
  P1-3: use_build_context_synchronously ×2
  P1-5: proguard 补充规则
  
第3轮 (4h):
  P1-7: 5 个集成测试
  P1-8: 8 个屏幕 Widget 测试

第4轮 (2h):
  P1-4: 依赖升级 + 回归测试
  P2-1: RAG 截断
  P2-2: AI prompt 截断

第5轮 (按需):
  P1-6: git 初始化
  P2-3: 转场动画
  P2-4: 权限引导
  P2-5: 隐私政策
  P2-6: Onboarding
```

---

## 已验证合格项（确认无需修复）

| 项目 | 证据 |
|------|------|
| 硬编码颜色 0 处 | `grep Colors\.` → No matches |
| 硬编码 API Key 0 处 | `grep sk-[a-zA-Z0-9]` → No matches |
| Navigator.pushNamed 0 处 | 全项目 grep → 全部使用 `context.push()` 或 dialog 内的 `Navigator.pop(ctx)` |
| HTTPS 强制 | `network_security_config.xml` — `cleartextTrafficPermitted="false"` |
| Dio 日志不泄露 | `kDebugMode` 保护 + `requestHeader: false` + `responseHeader: false` |
| debugPrint 不泄露敏感信息 | 14 处全部仅打印异常消息，无用户数据 |
| 破坏性操作全有确认弹窗 | 8 处 AlertDialog：删除日记/知识/批量删除/退出编辑/清空数据 |
| SnackBar 操作反馈 | 33 处覆盖所有操作结果 |
| Loading 指示器 | 16 处 CircularProgressIndicator/LinearProgressIndicator |
| EmptyState | 3 处（日记列表、知识浏览、首页最近） |
| RefreshIndicator | 3 处（首页、日记列表、知识浏览） |
| Dispose 完整性 | 7 个文件正确释放 TextEditingController/ScrollController/Timer |
| StrictMode | `MainActivity.kt` — `FLAG_DEBUGGABLE` 门控 |
| R8 混淆 | `isMinifyEnabled=true` + `isShrinkResources=true` |
| 签名配置 | `build.gradle.kts` + `key.properties` |
| `mounted` 检查 | 5 处关键 async 路径 |
| 权限最小化 | 仅 INTERNET + RECORD_AUDIO + CAMERA，无多余权限 |

---

*报告由全量代码扫描生成。39 个源文件、5 个测试文件、Android 全量配置逐项核查。*
