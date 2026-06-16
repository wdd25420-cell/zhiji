# 知记 APP — 上线前综合评估报告

> 评估日期：2026-06-17  
> 评估基准：[APP_LAUNCH_CHECKLIST.md](APP_LAUNCH_CHECKLIST.md)  
> 审计方法：逐文件代码审查 + 自动化工具扫描 + 全量 grep 验证

---

## 总评

| 维度 | 得分 | 趋势 |
|------|------|------|
| 一、代码质量与审查 | **78/100** | 🟡 |
| 二、测试体系 | **38/100** | 🔴 |
| 三、安全与隐私 | **62/100** | 🟡 |
| 四、性能与兼容性 | **35/100** | 🔴 |
| 五、用户体验打磨 | **72/100** | 🟡 |
| 六、合规与法律 | **15/100** | 🔴 |
| 七、应用商店准备 | **5/100** | 🔴 |
| 八、构建与签名 | **70/100** | 🟡 |
| 九、发布与监控 | **5/100** | 🔴 |

**综合得分：42/100**

---

## 阶段一：代码质量与审查 → 78/100 🟡

### 1.1 静态分析 ✅

```
flutter analyze → 0 error, 0 warning (9 info)
```

| 问题 | 严重度 | 位置 | 建议 |
|------|--------|------|------|
| `_Snapshot` 私有类型暴露在公开 API | info | `undo_manager.dart:53,61` | `_Snapshot` 改名为 `Snapshot` public，或屏蔽 lint |
| `localeId` deprecated | info | `voice_input_button.dart:71` | 迁移至 `SpeechListenOptions.localeId` |
| `DropdownButtonFormField.value` deprecated | info | `knowledge_editor_screen.dart:332` | 保持 `/// ignore: deprecated_member_use`，等 Flutter 3.34+ 稳定 |
| `use_build_context_synchronously` ×2 | info | `voice_input_button.dart:53`, `settings_screen.dart:359` | 已有 `mounted` 检查，lint 误报但可加 `context.mounted` 后缀 |

**结论**：静态分析合格。2 个新 info 来自 undo_manager 的私有类型泄露，建议修复。

### 1.2 代码审查清单逐项核查

| 维度 | 状态 | 详细发现 |
|------|------|---------|
| **异步安全** | ✅ 合格 | 关键 async 路径均有 `if (!mounted) return`：diary_editor(3处)、knowledge_editor(4处)、knowledge_detail(1处)、voice_input(1处) |
| **状态管理** | ✅ 合格 | ThemeModeNotifier 在 ProviderScope 中管理；各 Editor 用 ConsumerState |
| **数据库** | ⚠️ 部分 | DAO 层方法未包 try/catch，异常直接抛出给调用方。`getOrCreate` 无异常处理，若 name 为空会抛 StateError。`TagDao.linkDiary` 无异常包装——并发插入重复键时抛原始 SQL 异常 |
| **网络** | ✅ 合格 | Dio 已配超时(15s连接/30s读取)、AI API 有 30s 总超时、所有 AI 方法有 try/catch+null 兜底 |
| **UI 颜色** | ✅ 合格 | 全量使用 `Theme.of(context).colorScheme`，无硬编码颜色 |
| **导航** | ✅ 合格 | grep 搜索结果：0 处 `Navigator.pushNamed`，全部使用 `context.push()` |
| **资源释放** | ⚠️ 部分 | `TextEditingController` ✅ dispose；`AnimationController` 无使用；`ScrollController` chat_screen、diary_list 已 dispose；但 `_snapshotTimer` dispose 放在了 `_bodyCtrl.removeListener` 之前（diary_editor/knowledge_editor），顺序正确 |
| **多语言** | ⚠️ 不适用 | 全中文 App，未做 i18n 提取。若后续出海需重构 |

### 1.3 依赖审计

```
flutter pub outdated — 14 个 direct dependency 有更新可用
```

| 风险等级 | 包 | 当前 | 最新 | 影响 |
|----------|-----|------|------|------|
| 🔴 重大 | `file_picker` | 8.3.7 | 12.0.0-beta/11.0.2 | 大版本 API 可能变更 |
| 🔴 重大 | `go_router` | 14.8.1 | 17.3.0 | +3 大版本，API 需验证 |
| 🔴 重大 | `flutter_riverpod` | 2.6.1 | 3.3.2 | riverpod 3.x 有 breaking changes |
| 🟡 中断 | `drift` | 2.28.2 | 2.34.0 | 小版本安全 |
| 🟡 中断 | `fl_chart` | 0.69.2 | 1.2.0 | 首个 1.0，API 稳定性提高 |
| 🟡 中断 | `permission_handler` | 11.4.0 | 12.0.3 | 大版本 |
| 🔴 弃用 | `js` | — | — | 已被官方标记 discontinued |
| 🔴 弃用 | `build_resolvers` | — | — | 同上 |
| 🔴 弃用 | `build_runner_core` | — | — | 同上 |

**建议**：上架前至少将 `file_picker`、`go_router`、`flutter_riverpod` 升级到当前大版本的最新 stable。弃用包（3个）由 build_runner 传递依赖引入，不必立即清理，但需关注。

### 1.4 代码混淆验证 ✅

```
isMinifyEnabled = true    ✅
isShrinkResources = true  ✅
proguard-rules.pro        ✅ (Flutter + drift/SQLite + Dio/OkHttp keep 规则)
签名 keystore              ✅ (通过 key.properties 加载)
```

**缺陷**：`proguard-rules.pro` 缺少以下 keep 规则：
- `json_serializable` / `freezed` 生成的 `*.g.dart` 类（如有 fromJson/toJson 被反射调用）
- `riverpod` 的 provider 反射（当前未使用反射，暂无影响）

**结论**：混淆配置基本完备，构建后建议用 jadx 反编译验证。

---

## 阶段二：测试体系 → 38/100 🔴

### 2.1 当前测试覆盖

```
测试文件：5 个
测试总数：53 个（全部通过）
```

| 文件 | 测试数 | 覆盖层 |
|------|--------|--------|
| `database_test.dart` | 28 | DAO CRUD + FTS5 搜索 + 标签 + 设置 + 批量删除 |
| `database_edge_cases_test.dart` | 11 | 约束边界、并发冲突、FTS5 边界、Emotion枚 举、DioClient |
| `tag_filter_test.dart` | 3 | listByTag JOIN 查询 |
| `stats_test.dart` | 4 | countByEmotion、wordCountThisWeek、countByDay |
| `widget_test.dart` | 1 | App 启动 smoke test |

### 2.2 测试金字塔对比

```
要求                实际
─────              ─────
E2E (5%)          0 个        🔴 严重缺失
集成 (15%)        0 个        🔴 严重缺失
Widget (20%)      1 个        🔴 严重缺失
Unit (60%)        52 个       🟡 集中在 DAO 层
```

### 2.3 未覆盖的关键模块

| 模块 | 当前测试 | 风险 |
|------|---------|------|
| AI API Service | 0 | `_parseJson` 边界、网络超时、异常格式 |
| File Attachment Manager | 0 | 文件保存/删除/编解码 |
| Undo Manager | 0 | 快照栈 push/undo/redo/边界 |
| Chat Screen RAG 流程 | 0 | FTS5 search + API 联合 |
| Settings 导入导出 | 0 | JSON 解析+合并逻辑 |
| Navigator 路由 | 0 | 所有 `context.push` 跳转 |
| Theme Provider | 0 | 状态切换 |
| Search Screen | 0 | 高亮逻辑 `_buildHighlighted` |

### 2.4 手动测试

80+ 条回归用例已列在 checklist 中，但**从未执行过真机手动测试**（无可用模拟器/真机环境）。

**结论**：测试体系是最大的短板。DAO 层测试完善（52 个），但往上整个金字塔缺失。没有集成测试意味着无法保证"写日记→保存→首页出现"这条核心链路在真机上正确。

---

## 阶段三：安全与隐私 → 62/100 🟡

### 3.1 数据存储安全

| 项目 | 实现 | 评分 |
|------|------|------|
| API Key 存储 | `FlutterSecureStorage` → Android Keystore | ✅ |
| SecureStorage 初始化 | `const FlutterSecureStorage()`（默认 options） | ✅ |
| API Key 即时注入 | `setApiKey()` → `AppDio.setApiKey()` → Dio headers | ✅ |
| SQLite 加密 | `sqlite3_flutter_libs`（明文存储） | ⚠️ |
| `allowBackup` | **`android:allowBackup="true"`** | 🔴 |

**核心风险**：`allowBackup="true"` + 明文 SQLite 意味着：
- 用户通过 `adb backup` 可提取完整数据库
- Android 6.0+ 自动备份到 Google Drive（如果用户开启）
- API Key 存在 `FlutterSecureStorage` 中不受影响（因 SecureStorage 不允许备份）

### 3.2 网络安全

| 项目 | 实现 | 评分 |
|------|------|------|
| HTTPS 强制 | ✅ `network_security_config.xml` — `cleartextTrafficPermitted="false"` | ✅ |
| SSL Pinning | ❌ 未实现 | 🟡 可选 |
| Dio 日志泄露 | LogInterceptor 仅在 `kDebugMode` 启用，不记录 header/body | ✅ |
| API 端点 | 仅 `api.deepseek.com` | ✅ |

### 3.3 敏感数据日志泄露排查

```
debugPrint 出现 14 处：
```

| 类型 | 数量 | 风险 |
|------|------|------|
| 通用错误提示（如 "加载失败: $e"） | 10 | 🟡 仅打印异常消息，不泄露用户数据 |
| AI 请求失败日志 | 2 | 🟡 `debugPrint('AI request failed: $e')` — `$e` 可能含 API Key |
| Dio 日志 | 1 | ✅ `kDebugMode` 保护，release 自动移除 |
| FATAL 日志 | 1 | 🟢 `PlatformDispatcher.onError` 异常捕获 |

**风险点**：`ai_api_service.dart:39,42` 中的 `debugPrint('AI request failed: $e')` 在 release 模式下仍会执行（`debugPrint` 在 release 中是 no-op，但仅在 Flutter 3.0+）。核实：`debugPrint` 在 release 模式下是 **no-op**（Flutter 框架保证），所以 ✅ 安全。

### 3.4 权限审计

```
INTERNET              ✅ 仅 API 调用
RECORD_AUDIO          ✅ 语音输入
CAMERA                ✅ 拍照附件
READ_EXTERNAL_STORAGE 未在 manifest 声明 — file_picker 不需要
WRITE_EXTERNAL_STORAGE 未在 manifest 声明 — share_plus 不需要
```

权限最小化 ✅，无多余权限。

---

## 阶段四：性能与兼容性 → 35/100 🔴

### 4.1 性能测量

**未进行过任何性能测量**。下列指标均为理论评估：

| 指标 | 目标 | 当前状态 |
|------|------|---------|
| 冷启动 | <1.5s | ❓ 未测量 |
| 帧率 | 60fps | ❓ 未测量 |
| 内存 | <200MB | ❓ 未测量 |
| APK 大小 | <30MB/ABI | ❓ 无 release 构建 |
| DB 操作 | <5ms | ❓ 未测量 |

### 4.2 代码层性能风险点

| 风险 | 位置 | 严重度 |
|------|------|--------|
| `String.join('\n---\n')` + `_post()` 无长度限制 | `chat_screen.dart` RAG 上下文拼接 | 🟡 |
| `AI 分析` prompt 无 `content` 长度截断 | `ai_api_service.dart` | 🟡 |
| `countByDay(28)` 每次进入首页执行 | `home_screen.dart:359` | 🟡 |
| `currentStreak()` Dart 端循环计算 | `diary_dao.dart:64-90` | 🟢 规模小 |
| `AnimatedSwitcher` + `ListView.builder` | `diary_list_screen.dart:299` | 🟢 已优化 |
| 主页 `ListView` 包含 7+ 个子组件一次性 build | `home_screen.dart:55-137` | 🟡 |

### 4.3 兼容性

| 维度 | 状态 |
|------|------|
| Android 5.0 (API 21) 最低支持 | ✅ `flutter.minSdkVersion` |
| targetSdk 36 | ✅ |
| 64 位 ARM | ✅ flutter 默认构建 arm64-v8a |
| 平板/横屏 | ❌ 未适配 |
| 中低端设备 | ❌ 未测试 |

### 4.4 ANR/崩溃防护

| 项 | 状态 |
|-----|------|
| 主线程 I/O | ✅ 所有文件/DB 操作异步 |
| 主线程网络 | ✅ Dio 异步 |
| 全局异常兜底 | ✅ `PlatformDispatcher.onError` |
| StrictMode | ✅ `MainActivity.kt` 启用 |
| 崩溃监控 | ❌ 无 |

---

## 阶段五：用户体验打磨 → 72/100 🟡

### 5.1 交互检查

| 检查项 | 状态 | 说明 |
|--------|------|------|
| 按钮点击反馈 | ✅ | InkWell ripple 已使用 |
| 下拉刷新 | ✅ | 首页/日记列表/知识列表 (3处) |
| 页面过渡动画 | ⚠️ | 仅 `AnimatedSwitcher` (日记列表1处)；其他页面使用 GoRouter 默认转场（无自定义动画） |
| Loading 指示器 | ✅ | 16 处 CircularProgressIndicator/LinearProgressIndicator |
| 空状态引导 | ✅ | EmptyState 组件（3处使用） |
| 长列表滚动到顶 | ❌ | 无 FAB/button |
| SnackBar 反馈 | ✅ | 33 处 SnackBar 覆盖所有操作结果 |

### 5.2 错误处理覆盖率

| 场景 | 处理方式 | 评分 |
|------|---------|------|
| 网络错误 | `debugPrint` + null 返回 | 🟡 静默失败，用户无感知 |
| 数据库错误 | try/catch + SnackBar | ✅ |
| AI API 错误 | try/catch + SnackBar | ✅ |
| 文件导入失败 | try/catch + SnackBar | ✅ |
| 权限拒绝 | Dialog 引导（voice_input） | 🟡 仅语音有，拍照/相册无权限引导 |
| 保存标题为空 | 输入校验 + SnackBar | ✅ |

**缺陷**：网络错误（DioException）仅有 `debugPrint`，用户不知道是怎么失败的。建议统一网络错误处理器，在设置页展示网络状态。

### 5.3 无障碍

| 项目 | 状态 |
|------|------|
| tooltip | ✅ 大量按钮有 tooltip |
| semanticLabel | ❌ 无 |
| 颜色对比度 | ✅ MD3 自动满足 |
| 字体缩放 | ✅ `Theme.of(context).textTheme` |

### 5.4 内容与文案

| 项目 | 状态 |
|------|------|
| placeholder 残留 | ✅ 无 "Lorem ipsum" / "TODO" |
| 硬编码英文 | ✅ 全中文 |
| 错误提示友好 | ✅ 无堆栈暴露给用户 |
| 破坏性操作确认 | ✅ AlertDialog（删除、退出编辑、清空数据） |

---

## 阶段六：合规与法律 → 15/100 🔴

| 项目 | 现状 | 优先级 |
|------|------|--------|
| 隐私政策页面 | 设置页有入口，但内容可能是占位 | 🔴 P0 |
| 隐私政策内容 | **缺失**：未说明数据收集范围、DeepSeek API 使用、本地存储、删除方式 | 🔴 P0 |
| 用户协议 | 非强制（无社交/付费功能） | 🟢 |
| 开源许可展示 | ❌ 未使用 `showLicensePage()` | 🟡 P1 |
| 目标 API 级别 | 36 ✅ > 33 | ✅ |
| 国内市场合规 | 无软著、无 ICP 备案 | 🟡 P1 |

---

## 阶段七：应用商店准备 → 5/100 🔴

**全部缺失**。具体缺口：
- ❌ 应用截图（6张）
- ❌ 应用描述/简短描述
- ❌ 应用分类
- ❌ 隐私政策 URL
- ❌ 功能视频
- ✅ 应用图标（已通过 flutter_launcher_icons 生成）

---

## 阶段八：构建与签名 → 70/100 🟡

| 项目 | 状态 |
|------|------|
| Release 签名配置 | ✅ `build.gradle.kts` 读取 `key.properties` |
| `isMinifyEnabled = true` | ✅ |
| `isShrinkResources = true` | ✅ |
| proguard-rules.pro | ✅ 基础 keep 规则 |
| **Release APK 构建** | ❌ 未执行（需管理员 PowerShell） |
| APK 签名验证 | ❌ 未执行 |
| jadx 反编译验证 | ❌ 未执行 |
| adb install 验证 | ❌ 未执行 |

**阻塞项**：构建需要在管理员 PowerShell 中执行，当前环境 Gradle loopback bug。

---

## 阶段九：发布与监控 → 5/100 🔴

| 项目 | 状态 |
|------|------|
| 崩溃监控 | ❌ 无 |
| 内部测试 | ❌ 未执行 |
| 反馈邮件 | ❌ 设置页有入口但无实际内容 |
| 灰度策略 | ❌ 未定义 |

---

## 优先级修复路线图

### 🔴 P0：阻塞上架（必须立即修复）

| # | 问题 | 修复方式 | 工时 |
|---|------|---------|------|
| 1 | 隐私政策内容为空 | 编写隐私政策页面内容（说明本地存储、DeepSeek API、数据删除） | 30min |
| 2 | `allowBackup="true"` 安全风险 | 改为 `false` 或添加 `android:fullBackupContent` 排除数据库 | 5min |
| 3 | 无集成测试 | 编写 5 个核心流程集成测试 | 2h |
| 4 | 无 Widget 测试 | 覆盖 8 个屏幕的关键状态（空/加载/错误） | 2h |
| 5 | Release APK 未构建 | 在管理员 PowerShell 中执行 `flutter build apk --release --split-per-abi` | 10min |
| 6 | undo_manager 私有类型暴露 | 重命名或 lint ignore | 3min |

### 🟡 P1：上线前强烈建议

| # | 问题 | 修复方式 | 工时 |
|---|------|---------|------|
| 7 | DAO 方法无异常包装 | 关键 DAO 方法加 try/catch 或统一异常层 | 1h |
| 8 | 网络错误静默失败 | 统一网络异常处理 → SnackBar | 30min |
| 9 | 无页面自定义转场动画 | 给 GoRouter 加 fade+slide 转场 | 30min |
| 10 | 依赖过期（14个） | `flutter pub upgrade --major-versions` + 回归测试 | 1h |
| 11 | 应用商店截图 | 在模拟器/真机上截图 6 张 | 30min |
| 12 | 应用商店元数据 | 编写描述/短描述/关键词 | 30min |
| 13 | 开源许可展示 | 添加 `showLicensePage` 入口 | 10min |
| 14 | 拍照/相册权限拒绝引导 | 补充权限 denied 时的 Dialog | 20min |

### 🟢 P2：锦上添花

| # | 问题 | 工时 |
|---|------|------|
| 15 | 新手引导 Onboarding | 3h |
| 16 | 崩溃监控接入 (Bugly) | 1h |
| 17 | 平板/横屏适配 | 2h |
| 18 | 应用评分引导 | 1h |
| 19 | 功能演示视频 | 2h |
| 20 | semanticLabel 无障碍 | 1h |

---

## 修复优先级排序

```
现在立即 → P0-2(allowBackup) → P0-6(undo_manager) → P0-1(隐私政策)
         → P0-5(Release APK构建) → P0-3(集成测试) → P0-4(Widget测试)
         → P1(依赖更新+网络错误+转场动画+截图+元数据)
         → P2(Onboarding+监控+平板)
```

---

*报告由代码逐行审计生成，覆盖 36 个 Dart 源文件、5 个测试文件、Android 配置文件。*
