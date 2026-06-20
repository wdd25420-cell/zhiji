# 知记 UX 全面升级 — 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将知记 App 从"工程师审美"升级到"精品 App 质感"，覆盖 UX_REVIEW.md 中 P0+P1+P2 全部 14 项改进。

**Architecture:** 3 阶段执行——阶段0基础跃升(4步)、阶段1体验提升(3步)、阶段2精品打磨(7步)。Hook 机制通过 PreToolUse 拦截强制顺序执行。

**Tech Stack:** Flutter 3.38.5, Dart, go_router, flutter_riverpod, drift SQLite, fl_chart, DeepSeek API

## 全局约束

- 每步完成后 `flutter analyze` 必须 0 error 0 warning
- 每步完成后 `flutter test` 必须全绿
- 任何步骤失败 → 必须先修复再继续，严格禁止跳步
- 状态文件 `.claude/ux_upgrade_state.json` 追踪每步状态
- Dart 源文件严格只改与当前步骤相关的代码
- 匹配现有代码风格：中文注释、2 空格缩进、`const` 优先

---

## 前置任务：Hook 强制机制

### Task 0: 创建 Hook 文件与状态追踪系统

**Files:**
- Create: `.claude/ux_upgrade_state.json`
- Modify: `.claude/settings.local.json`

**Interfaces:**
- Produces: `ux_upgrade_state.json` — 所有后续 Task 依赖此文件验证步骤顺序
- Produces: `settings.local.json` hook 配置

- [ ] **Step 1: 创建初始状态文件**

写入 `.claude/ux_upgrade_state.json`：

```json
{
  "current_step": 1,
  "total_steps": 14,
  "steps": {
    "1": {"status": "pending", "name": "首屏冷启动友好化 + 导航修复", "started_at": null, "completed_at": null},
    "2": {"status": "pending", "name": "全局中文字体 + 色彩微调", "started_at": null, "completed_at": null},
    "3": {"status": "pending", "name": "导航 go→push 修复收尾", "started_at": null, "completed_at": null},
    "4": {"status": "pending", "name": "AI 视觉语言统一", "started_at": null, "completed_at": null},
    "5": {"status": "pending", "name": "骨架屏替换转圈", "started_at": null, "completed_at": null},
    "6": {"status": "pending", "name": "Agent 流式输出", "started_at": null, "completed_at": null},
    "7": {"status": "pending", "name": "深色模式三段开关", "started_at": null, "completed_at": null},
    "8": {"status": "pending", "name": "列表入场动画 + 微交互", "started_at": null, "completed_at": null},
    "9": {"status": "pending", "name": "对话气泡重做", "started_at": null, "completed_at": null},
    "10": {"status": "pending", "name": "统计卡片不对称布局", "started_at": null, "completed_at": null},
    "11": {"status": "pending", "name": "编辑器视觉层次", "started_at": null, "completed_at": null},
    "12": {"status": "pending", "name": "写作热力图升级", "started_at": null, "completed_at": null},
    "13": {"status": "pending", "name": "情绪趋势图升级", "started_at": null, "completed_at": null},
    "14": {"status": "pending", "name": "应用锁", "started_at": null, "completed_at": null}
  }
}
```

- [ ] **Step 2: 读取当前 settings.local.json 以合并 hook**

Run: `cat .claude/settings.local.json 2>/dev/null || echo "{}"`

- [ ] **Step 3: 写入 settings.local.json hook 配置**

将以下 hook 合并到 settings.local.json 的 `hooks` 部分（如文件已有其他配置则保留并合并）：

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "tool_name === 'Write' || tool_name === 'Edit' || (tool_name === 'Bash' && tool_input.command && tool_input.command.includes('flutter build'))",
        "hooks": [
          {
            "type": "command",
            "command": "node -e \"const fs=require('fs');try{const s=JSON.parse(fs.readFileSync('.claude/ux_upgrade_state.json','utf8'));const cs=s.current_step;const steps=Object.entries(s.steps);const done=steps.filter(([k,v])=>parseInt(k)<cs&&v.status!=='completed');if(done.length>0){console.log('BLOCKED: 前置步骤未完成:'+done.map(([k,v])=>'步骤'+k+'('+v.name+') 仍为 '+v.status).join(', '));process.exit(1);}console.log('OK: 当前步骤 '+cs);}catch(e){console.log('WARN: 状态文件读取失败，放行: '+e.message);}\""
          }
        ]
      }
    ]
  }
}
```

- [ ] **Step 4: 验证 Hook 机制**

手动将 `current_step` 临时设为 2，尝试写操作，确认被拦截。恢复为 1。

- [ ] **Step 5: Commit**

```bash
git add .claude/ux_upgrade_state.json .claude/settings.local.json
git commit -m "chore: UX 升级 hook 强制机制 + 状态追踪"
```

---

## 阶段 0：基础跃升 (P0)

### Task 1: 首屏冷启动友好化 + 导航修复

**Skill 链：** `ecc:flutter-review` → `ecc:flutter-build`

**Files:**
- Modify: `zhiji_app/lib/features/chat/chat_screen.dart`
- Modify: `zhiji_app/lib/core/widgets/app_shell.dart`

**Interfaces:**
- Consumes: `ux_upgrade_state.json`（步骤检查）
- Produces: 冷启动无 API Key 时不报错 / `app_shell.dart` 导航用 `context.push()`

- [ ] **Step 1: `app_shell.dart` — `context.go()` 全部改为 `context.push()`**

修改 `_showDrawer` 方法中 4 处调用：
- Line 45: `context.go("/diary/new")` → `context.push("/diary/new")`
- Line 52: `context.go("/knowledge")` → `context.push("/knowledge")`
- Line 59: `context.go("/home")` → `context.push("/home")`
- Line 67: `context.go("/settings")` → `context.push("/settings")`

- [ ] **Step 2: `chat_screen.dart` — 添加 API Key 检测**

在 `_send` 方法中 `final question = text.trim();` 后添加 API Key 检测逻辑，无 Key 时返回友好引导消息而非报错：

```dart
final db = await ref.read(databaseProvider.future);
final settingsDao = SettingsDao(db);
final key = await settingsDao.getApiKey();
if (key == null || key.isEmpty) {
  if (mounted) {
    setState(() {
      _messages.add(_ChatMessage(
        role: "ai",
        content: "👋 欢迎使用知记！\n\n"
            "我注意到你还没有设置 API Key。请在设置中配置 DeepSeek API Key 以启用 AI 功能。\n\n"
            "在没有 AI 的情况下，你仍然可以：\n"
            "• 📝 写日记 — 从功能菜单进入\n"
            "• 📚 管理知识库 — 添加和整理你的知识\n"
            "• 🔍 搜索 — 全文搜索你的所有内容\n"
            "• 📊 查看仪表盘 — 写作统计和趋势\n\n"
            "前往 **设置 → DeepSeek API Key** 完成配置。",
      ));
    });
    _scrollDown();
  }
  return;
}
```

注意：需要导入 `../../core/database/daos/common_daos.dart`（SettingsDao）。

- [ ] **Step 3: 欢迎页添加"前往设置"入口**

在 `_buildWelcome` 方法的 `Wrap` 子组件列表末尾添加：

```dart
ActionChip(
  avatar: const Icon(Icons.settings, size: 14),
  label: const Text("前往设置"),
  onPressed: () => context.push('/settings'),
),
```

- [ ] **Step 4: 编译验证**

Run: `cd zhiji_app && flutter analyze`
Expected: 0 error, 0 warning

- [ ] **Step 5: 运行测试**

Run: `cd zhiji_app && flutter test`
Expected: 全部通过

- [ ] **Step 6: 更新状态文件 + Commit**

更新 `.claude/ux_upgrade_state.json`：step 1 status → "completed"，started_at / completed_at 写入时间戳，current_step → 2。

```bash
git add zhiji_app/lib/features/chat/chat_screen.dart zhiji_app/lib/core/widgets/app_shell.dart .claude/ux_upgrade_state.json
git commit -m "feat(ux): 步骤1 — 首屏冷启动友好化 + 导航 go→push 修复"
```

---

### Task 2: 全局中文字体 + 色彩微调

**Skill 链：** `apply-design-md` → `ecc:flutter-build`

**Files:**
- Modify: `zhiji_app/lib/core/theme/app_theme.dart`
- Modify: `zhiji_app/lib/core/theme/color_tokens.dart`
- Modify: `zhiji_app/pubspec.yaml`

**Interfaces:**
- Consumes: 步骤1 完成的代码状态
- Produces: `app_theme.dart` 的 `fontFamily`、`height: 1.7`、深色模式专用色

- [ ] **Step 1: `pubspec.yaml` 添加 google_fonts 依赖**

在 dependencies 下添加：
```yaml
  google_fonts: ^6.2.1
```

Run: `cd zhiji_app && flutter pub get`

- [ ] **Step 2: `app_theme.dart` 添加 fontFamily**

在 `ThemeData` 构造函数中添加：
```dart
fontFamily: 'SourceHanSansCN',
```

修改 `bodyLarge` 的 `height` 从 `1.5` 改为 `1.7`：

```dart
bodyLarge: TextStyle(
  fontSize: 16,
  fontWeight: FontWeight.w400,
  color: colorScheme.onSurface,
  height: 1.7,
),
```

- [ ] **Step 3: `color_tokens.dart` 添加深色模式专用色 + 微调**

```dart
class AppColors {
  AppColors._();
  static const Color seed = Color(0xFF00897B);

  // 深色模式专用色
  static const Color darkBackground = Color(0xFF121212);
  static const Color darkCard = Color(0xFF1E1E1E);
}
```

在 `app_theme.dart` 的 dark getter 中应用：
```dart
static ThemeData get dark {
  final base = _buildTheme(Brightness.dark);
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.darkBackground,
    cardTheme: base.cardTheme.copyWith(
      color: AppColors.darkCard,
    ),
  );
}
```

- [ ] **Step 4: 编译 + 测试**

Run: `cd zhiji_app && flutter analyze && flutter test`

- [ ] **Step 5: 更新状态文件 + Commit**

```bash
git add zhiji_app/pubspec.yaml zhiji_app/lib/core/theme/app_theme.dart zhiji_app/lib/core/theme/color_tokens.dart .claude/ux_upgrade_state.json
git commit -m "feat(ux): 步骤2 — 全局中文字体 SourceHanSansCN + 深色模式专用色"
```

---

### Task 3: 导航 go→push 修复收尾

**Skill 链：** `ecc:flutter-review` → `ecc:flutter-test`

**Files:**
- 审查: `zhiji_app/lib/` 下所有 `.dart` 文件

- [ ] **Step 1: 审查全局 `context.go()` 调用**

Run: `cd zhiji_app && grep -rn "context\.go(" lib/`
Expected: 确认除 app_router 内部逻辑外，所有导航调用均为 `push`。

- [ ] **Step 2: 编译 + 测试**

Run: `cd zhiji_app && flutter analyze && flutter test`

- [ ] **Step 3: 更新状态文件 + Commit**

```bash
git commit --allow-empty -m "chore(ux): 步骤3 — 确认导航 go→push 全部修复"
```

---

### Task 4: AI 视觉语言统一

**Skill 链：** `ecc:gan-design` → `ecc:flutter-build`

**Files:**
- Create: `zhiji_app/lib/core/widgets/ai_icon.dart`
- Modify: `zhiji_app/lib/features/chat/chat_screen.dart`
- Modify: `zhiji_app/lib/features/home/home_screen.dart`

**Interfaces:**
- Produces: `AiIcon` widget — 统一紫蓝渐变 AI 图标（参数：size, withBackground）
- Consumes: 步骤2 完成的 `app_theme.dart`

- [ ] **Step 1: 创建 `ai_icon.dart` 统一 AI 图标**

```dart
// core/widgets/ai_icon.dart
import 'package:flutter/material.dart';

/// 统一的 AI 功能图标 — 紫蓝渐变 (#7C3AED → #3B82F6)
class AiIcon extends StatelessWidget {
  const AiIcon({super.key, this.size = 24, this.withBackground = true});

  final double size;
  final bool withBackground;

  static const _gradient = LinearGradient(
    colors: [Color(0xFF7C3AED), Color(0xFF3B82F6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  @override
  Widget build(BuildContext context) {
    if (!withBackground) {
      return ShaderMask(
        shaderCallback: (bounds) => _gradient.createShader(bounds),
        child: Icon(Icons.auto_awesome, size: size, color: Colors.white),
      );
    }
    return Container(
      width: size + 8,
      height: size + 8,
      decoration: BoxDecoration(
        gradient: _gradient,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(Icons.auto_awesome, size: size, color: Colors.white),
    );
  }
}
```

- [ ] **Step 2: 替换 `chat_screen.dart` 中的 🤖 emoji**

- `_buildWelcome` 第279行：Container 内 `🤖` emoji → `const AiIcon(size: 36)`
- `_buildBubble` 第321行：AI 头像 `🤖` emoji → `const AiIcon(size: 16, withBackground: false)`

- [ ] **Step 3: 替换 `home_screen.dart` 中的 🤖 和 AI 文字方块**

- 第95行 `DeepSeek 洞察` 卡片：`'AI'` 文字方块 → `const AiIcon(size: 18)`
- 第131行 `AI 问答` 卡片：`'🤖'` → `const AiIcon(size: 18)`
- 第274行 `本周回顾` 弹窗：`'🤖'` → `const AiIcon(size: 24)`

- [ ] **Step 4: 编译 + 测试 + Commit**

```bash
git add zhiji_app/lib/core/widgets/ai_icon.dart zhiji_app/lib/features/chat/chat_screen.dart zhiji_app/lib/features/home/home_screen.dart .claude/ux_upgrade_state.json
git commit -m "feat(ux): 步骤4 — 统一 AI 紫蓝渐变图标，替换 🤖/AI 文字方块"
```

---

## 阶段 1：体验提升 (P1)

### Task 5: 骨架屏替换转圈

**Skill 链：** `ecc:flutter-review` → `ecc:flutter-test`

**Files:**
- Create: `zhiji_app/lib/core/widgets/shimmer_placeholder.dart`
- Modify: `zhiji_app/lib/features/home/home_screen.dart`
- Modify: `zhiji_app/lib/features/home/widgets/emotion_trend_chart.dart`
- Modify: `zhiji_app/lib/features/search/search_screen.dart`
- Modify: `zhiji_app/lib/features/diary/diary_list_screen.dart`
- Modify: `zhiji_app/lib/features/knowledge/knowledge_browse_screen.dart`
- Modify: `zhiji_app/lib/features/diary/diary_editor_screen.dart`
- Modify: `zhiji_app/lib/features/knowledge/knowledge_editor_screen.dart`

**Interfaces:**
- Produces: `ShimmerPlaceholder` widget — 参数：width, height, borderRadius
- Consumes: 步骤4 完成的代码状态

- [ ] **Step 1: 创建 ShimmerPlaceholder 组件**

```dart
// core/widgets/shimmer_placeholder.dart
import 'package:flutter/material.dart';

/// 骨架屏占位组件 — 替代所有 CircularProgressIndicator
class ShimmerPlaceholder extends StatefulWidget {
  const ShimmerPlaceholder({
    super.key,
    this.width,
    this.height = 100,
    this.borderRadius = 12,
  });

  final double? width;
  final double height;
  final double borderRadius;

  @override
  State<ShimmerPlaceholder> createState() => _ShimmerPlaceholderState();
}

class _ShimmerPlaceholderState extends State<ShimmerPlaceholder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final t = _ctrl.value;
        final opacity = 0.3 + 0.3 * (t <= 0.5 ? t * 2 : (1 - t) * 2);
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: cs.onSurface.withValues(alpha: opacity),
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
        );
      },
    );
  }
}
```

- [ ] **Step 2: 替换 `home_screen.dart` 中的转圈**

4处 `CircularProgressIndicator()` 替换：
- 第37行 `loading` → `const ShimmerPlaceholder(height: 200)`
- 第282行 `_WeeklyReviewSheet` → `const ShimmerPlaceholder(height: 160)`
- `_StatCard` 的 `FutureBuilder` snapshot 无数据时 → `const ShimmerPlaceholder(height: 80)`

- [ ] **Step 3: 替换 `emotion_trend_chart.dart` 中的转圈**

- 第52行 EmotionTrendChart loading → `const ShimmerPlaceholder(height: 160)`
- 第138行 WritingHeatmap loading → `const ShimmerPlaceholder(height: 100)`

- [ ] **Step 4: 替换其他文件的转圈**

- `search_screen.dart` 搜索结果加载中
- `diary_list_screen.dart` 列表加载中
- `knowledge_browse_screen.dart` 列表加载中
- `diary_editor_screen.dart` / `knowledge_editor_screen.dart` AI 分析中

- [ ] **Step 5: 编译 + 测试 + Commit**

```bash
git add zhiji_app/lib/core/widgets/shimmer_placeholder.dart zhiji_app/lib/features/ .claude/ux_upgrade_state.json
git commit -m "feat(ux): 步骤5 — 骨架屏替换全部 CircularProgressIndicator"
```

---

### Task 6: Agent 流式输出 + 步骤提示

**Skill 链：** `ecc:flutter-build` → `verify`

**Files:**
- Modify: `zhiji_app/lib/core/network/ai_api_service.dart`
- Modify: `zhiji_app/lib/core/agent/agent_service.dart`
- Modify: `zhiji_app/lib/features/chat/chat_screen.dart`

**Interfaces:**
- Consumes: 步骤5 完成的代码状态
- Produces: `AgentService.runStream()` 返回 `Stream<AgentStep>`
- Produces: `AIService.chatCompletionStream()` 返回 `Stream<String>`

- [ ] **Step 1: `ai_api_service.dart` 添加 SSE 流式方法**

```dart
/// 流式聊天补全，返回每段 delta content
static Stream<String> chatCompletionStream({
  required List<Map<String, dynamic>> messages,
}) async* {
  final client = DioClient.instance;
  final body = {
    "model": "deepseek-chat",
    "messages": messages,
    "stream": true,
  };

  final response = await client.post(
    "/chat/completions",
    data: body,
    options: Options(responseType: ResponseType.stream),
  );

  final stream = response.data.stream as Stream<List<int>>;
  final buffer = StringBuffer();

  await for (final chunk in stream) {
    final text = utf8.decode(chunk);
    for (final line in text.split("\n")) {
      if (line.startsWith("data: ")) {
        final data = line.substring(6);
        if (data == "[DONE]") return;
        try {
          final json = jsonDecode(data);
          final delta = json["choices"]?[0]?["delta"]?["content"];
          if (delta != null) yield delta as String;
        } catch (_) {}
      }
    }
  }
}
```

需要添加 `import 'dart:convert';` 到文件顶部。

- [ ] **Step 2: `agent_service.dart` 添加 AgentStep 类型 + runStream**

定义：
```dart
enum AgentStepType { thinking, searching, webSearching, analyzing, writing, responding, done, error }

class AgentStep {
  final AgentStepType type;
  final String? contentDelta;
  final String? toolName;
  const AgentStep({required this.type, this.contentDelta, this.toolName});
}
```

添加 `runStream` 方法——与 `run` 类似但：
- 工具调用前 yield `AgentStep(type: AgentStepType.searching, toolName: tc.name)`
- 最后用 `chatCompletionStream` 替代 `chatCompletion`，yield `AgentStep(type: AgentStepType.responding, contentDelta: delta)`

- [ ] **Step 3: `chat_screen.dart` 对接流式，添加步骤提示**

添加成员变量 `String _toolStatus = "";` 和 `final _aiBuffer = StringBuffer();`

修改 `_send` 方法使用 `runStream`：
```dart
String toolStatus = "思考中…";
final aiBuffer = StringBuffer();

await for (final step in stream) {
  if (!mounted) break;
  switch (step.type) {
    case AgentStepType.thinking:
      toolStatus = "思考中…"; break;
    case AgentStepType.searching:
      toolStatus = "正在搜索知识库…"; break;
    case AgentStepType.webSearching:
      toolStatus = "正在联网搜索…"; break;
    case AgentStepType.analyzing:
      toolStatus = "正在分析…"; break;
    case AgentStepType.writing:
      toolStatus = "正在写入…"; break;
    case AgentStepType.responding:
      if (aiBuffer.isEmpty && mounted) {
        setState(() { _loading = false; _messages.add(_ChatMessage(role: "ai", content: "")); });
      }
      aiBuffer.write(step.contentDelta ?? "");
      if (mounted) setState(() => _messages.last.content = aiBuffer.toString());
      break;
    case AgentStepType.done:
      _saveMessage("assistant", aiBuffer.toString());
      break;
    case AgentStepType.error:
      // 错误时显示友好提示
      break;
  }
  _toolStatus = toolStatus;
  if (mounted && step.type != AgentStepType.responding) setState(() {});
}
```

修改 `_buildBubble` 的 loading 状态——"思考中…"替换为：
```dart
child: Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    const _BreathingDots(),
    const SizedBox(height: 8),
    Text(_toolStatus, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
  ],
),
```

- [ ] **Step 4: 添加 `_BreathingDots` 动画组件**

在 `chat_screen.dart` 文件底部添加私有组件：
```dart
class _BreathingDots extends StatefulWidget {
  const _BreathingDots();
  @override
  State<_BreathingDots> createState() => _BreathingDotsState();
}

class _BreathingDotsState extends State<_BreathingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        final t = (_ctrl.value + i * 0.33) % 1.0;
        final opacity = 0.3 + 0.4 * (t <= 0.5 ? t * 2 : 2 - t * 2);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Container(
            width: 6, height: 6,
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: opacity.clamp(0.3, 0.9)),
              shape: BoxShape.circle,
            ),
          ),
        );
      }),
    );
  }
}
```

- [ ] **Step 5: 编译 + 测试 + Commit**

```bash
git add zhiji_app/lib/core/network/ai_api_service.dart zhiji_app/lib/core/agent/agent_service.dart zhiji_app/lib/features/chat/chat_screen.dart .claude/ux_upgrade_state.json
git commit -m "feat(ux): 步骤6 — Agent SSE 流式输出 + 步骤提示 + 呼吸点动画"
```

---

### Task 7: 深色模式三段开关

**Skill 链：** `ecc:flutter-review` → `ecc:flutter-build`

**Files:**
- Modify: `zhiji_app/lib/features/settings/settings_screen.dart`

- [ ] **Step 1: 替换深色模式循环点击为 SegmentedButton**

修改 `settings_screen.dart` 第250-264行，将原有 `ListTile` 的 `subtitle` 改为含 `SegmentedButton`：

```dart
ListTile(
  title: const Text('深色模式'),
  leading: const Icon(Icons.dark_mode_outlined),
  subtitle: Padding(
    padding: const EdgeInsets.only(top: 8),
    child: SegmentedButton<ThemeMode>(
      segments: const [
        ButtonSegment(value: ThemeMode.system, label: Text('跟随系统')),
        ButtonSegment(value: ThemeMode.light, label: Text('浅色')),
        ButtonSegment(value: ThemeMode.dark, label: Text('深色')),
      ],
      selected: {ref.watch(themeModeProvider)},
      onSelectionChanged: (modes) {
        ref.read(themeModeProvider.notifier).set(modes.first);
      },
      style: const ButtonStyle(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    ),
  ),
),
```

删除原有的 `onTap` 处理（第259-263行），不再需要手动循环。

- [ ] **Step 2: 编译 + 测试 + Commit**

```bash
git add zhiji_app/lib/features/settings/settings_screen.dart .claude/ux_upgrade_state.json
git commit -m "feat(ux): 步骤7 — 深色模式 SegmentedButton 替换循环点击"
```

---

## 阶段 2：精品打磨 (P2)

### Task 8: 列表入场动画 + 微交互

**Skill 链：** `ecc:gan-design` → `verify`

**Files:**
- Modify: `zhiji_app/lib/core/widgets/app_shell.dart`
- Create: `zhiji_app/lib/core/widgets/save_success_animation.dart`
- Modify: `zhiji_app/lib/features/home/home_screen.dart`
- Modify: `zhiji_app/lib/features/diary/diary_list_screen.dart`
- Modify: `zhiji_app/lib/features/knowledge/knowledge_browse_screen.dart`
- Modify: `zhiji_app/lib/features/diary/diary_editor_screen.dart`
- Modify: `zhiji_app/lib/features/knowledge/knowledge_editor_screen.dart`

- [ ] **Step 1: FAB 旋转动画**

将 `app_shell.dart` 的 FAB 从 `FloatingActionButton` 改为自定义 `AnimatedRotation`：

```dart
// 在 _showDrawer 调用中添加状态变量控制旋转角度
floatingActionButton: AnimatedRotation(
  turns: _fabRotated ? 0.125 : 0, // 45度
  duration: const Duration(milliseconds: 300),
  child: FloatingActionButton(
    onPressed: () {
      setState(() => _fabRotated = !_fabRotated);
      _showDrawer(context).then((_) => setState(() => _fabRotated = false));
    },
    child: const Icon(Icons.grid_view),
  ),
),
```

注意：需要将 `AppShell` 改为 `StatefulWidget` 或使用 `TickerProviderStateMixin`。

- [ ] **Step 2: 创建保存成功对勾动画**

```dart
// core/widgets/save_success_animation.dart
class SaveSuccessAnimation extends StatefulWidget {
  const SaveSuccessAnimation({super.key});
  @override
  State<SaveSuccessAnimation> createState() => _SaveSuccessAnimationState();
}

class _SaveSuccessAnimationState extends State<SaveSuccessAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _circleProgress;
  late final Animation<double> _checkProgress;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _circleProgress = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.4, curve: Curves.easeOut)),
    );
    _checkProgress = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.3, 0.7, curve: Curves.easeOut)),
    );
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return SizedBox(
          width: 48, height: 48,
          child: CustomPaint(
            painter: _CheckPainter(
              circleProgress: _circleProgress.value,
              checkProgress: _checkProgress.value,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        );
      },
    );
  }
}
```

- [ ] **Step 3: 列表交错入场动画**

`diary_list_screen.dart` 和 `knowledge_browse_screen.dart`：
```dart
// 使用 ListView.builder，每个 item 包裹在 _StaggeredSlideItem 中
class _StaggeredSlideItem extends StatefulWidget {
  final int index;
  final Widget child;
  // ... 
  // initState 中用 Timer(Duration(milliseconds: index * 50)) 触发动画
}
```

- [ ] **Step 4: 编辑器保存用对勾动画替换 SnackBar**

在 `diary_editor_screen.dart` 和 `knowledge_editor_screen.dart` 中，将保存成功的 `SnackBar` 替换为 `showDialog` 调用 `SaveSuccessAnimation`。

- [ ] **Step 5: 编译 + 测试 + Commit**

---

### Task 9: 对话气泡重做

**Skill 链：** `ecc:flutter-review` → `ecc:gan-design`

**Files:**
- Modify: `zhiji_app/lib/features/chat/chat_screen.dart`

- [ ] **Step 1: AI 气泡加左侧 4px 主色竖条 + 微阴影**

修改 `_buildBubble` 方法的 decoration，AI 气泡：

```dart
decoration: BoxDecoration(
  color: cs.surfaceContainerHighest,
  borderRadius: BorderRadius.only(
    topLeft: const Radius.circular(AppRadius.lg),
    topRight: const Radius.circular(AppRadius.lg),
    bottomRight: const Radius.circular(AppRadius.lg),
  ),
  boxShadow: [
    BoxShadow(
      color: cs.shadow.withValues(alpha: 0.05),
      blurRadius: 4,
      offset: const Offset(0, 2),
    ),
  ],
  border: Border(
    left: BorderSide(color: cs.primary, width: 4),
  ),
),
```

- [ ] **Step 2: 用户气泡用 primary 实色 + 白色文字**

```dart
// 用户气泡
color: cs.primary, // 改自 primaryContainer
// child 文字颜色改为 cs.onPrimary
// 代码中 child 已通过 SelectableText 的 style 传入，需确保是白色
```

- [ ] **Step 3: 长按复制**

气泡包裹在 `GestureDetector` 中：

```dart
GestureDetector(
  onLongPress: () {
    Clipboard.setData(ClipboardData(text: msg.content));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已复制'), duration: Duration(seconds: 1)),
    );
  },
  child: Container(/* 现有气泡 */),
),
```

需要添加 `import 'package:flutter/services.dart';` 到文件顶部。

- [ ] **Step 4: 编译 + 测试 + Commit**

---

### Task 10: 统计卡片不对称布局

**Skill 链：** `ecc:gan-design` → `ecc:flutter-test`

**Files:**
- Modify: `zhiji_app/lib/features/home/home_screen.dart`

- [ ] **Step 1: `_StatRow` 改为 1大+3小 不对称布局**

```dart
// 替换现有的 2×2 网格
Column(
  children: [
    // 大主卡：连续记录天数 + 渐变背景
    _StreakCard(db: db, cs: cs),
    const SizedBox(height: AppSpacing.sm),
    // 3 小卡横排
    Row(children: [
      Expanded(child: _MiniStatCard(icon: Icons.book_outlined, label: '日记', future: db.diaryDao.countAll(), cs: cs)),
      const SizedBox(width: AppSpacing.sm),
      Expanded(child: _MiniStatCard(icon: Icons.folder_outlined, label: '知识', future: db.knowledgeDao.countAll(), cs: cs)),
      const SizedBox(width: AppSpacing.sm),
      Expanded(child: _MiniStatCard(icon: Icons.text_fields, label: '字数', future: db.diaryDao.wordCountThisWeek(), cs: cs)),
    ]),
  ],
)
```

- [ ] **Step 2: 大主卡组件 `_StreakCard`**

```dart
class _StreakCard extends StatelessWidget {
  // 渐变背景（primary → tertiary）
  // 大数字 + 🔥 emoji + "连续记录天数"
  // 副文本 "比上周多 N 天"
}
```

- [ ] **Step 3: 小卡组件 `_MiniStatCard`**

```dart
class _MiniStatCard extends StatelessWidget {
  // 去图标，只保留数字 + 标签
  // 居中布局
}
```

- [ ] **Step 4: 编译 + 测试 + Commit**

---

### Task 11: 编辑器视觉层次

**Skill 链：** `ecc:flutter-review` → `ecc:gan-design`

**Files:**
- Modify: `zhiji_app/lib/features/diary/diary_editor_screen.dart`
- Modify: `zhiji_app/lib/features/knowledge/knowledge_editor_screen.dart`
- Modify: `zhiji_app/lib/core/widgets/markdown_toolbar.dart`

- [ ] **Step 1: 标题/正文分区**

两个编辑器页面：标题 TextField 外包 `Card`（带圆角边框），正文字段同。

```dart
Card(
  margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
  child: TextField(
    controller: _titleCtrl,
    decoration: const InputDecoration(
      hintText: '标题',
      border: OutlineInputBorder(borderSide: BorderSide.none),
    ),
    style: Theme.of(context).textTheme.titleLarge,
  ),
),
```

- [ ] **Step 2: 工具栏分组**

`markdown_toolbar.dart` 按钮改为三组：
```dart
Row(children: [
  // 格式组: B I H
  IconButton(icon: Icon(Icons.format_bold), ...),
  IconButton(icon: Icon(Icons.format_italic), ...),
  IconButton(icon: Icon(Icons.title), ...),
  const VerticalDivider(),
  // 插入组: 链接/图片/附件/语音
  IconButton(...),
  const VerticalDivider(),
  // AI 组
  IconButton(...),
])
```

- [ ] **Step 3: 字数统计加大**

从 `labelSmall`（11px）→ `labelLarge`（14px）：
```dart
Text('${_bodyCtrl.text.length} 字',
  style: Theme.of(context).textTheme.labelLarge?.copyWith(
    color: Theme.of(context).colorScheme.onSurfaceVariant,
  ),
),
```

- [ ] **Step 4: 自动保存状态提示**

```dart
// 在草稿保存成功后显示微小文字 2 秒
String? _autoSaveLabel;
void _onDraftSaved() {
  setState(() => _autoSaveLabel = '已自动保存 ${TimeOfDay.now().format(context)}');
  Future.delayed(const Duration(seconds: 2), () {
    if (mounted) setState(() => _autoSaveLabel = null);
  });
}
```

- [ ] **Step 5: 编译 + 测试 + Commit**

---

### Task 12: 写作热力图升级

**Skill 链：** `ecc:flutter-review` → `ecc:flutter-test`

**Files:**
- Modify: `zhiji_app/lib/features/home/widgets/emotion_trend_chart.dart`（含 `WritingHeatmap`）
- Modify: `zhiji_app/lib/core/database/daos/common_daos.dart`

- [ ] **Step 1: 28 格 → 全年视图**

修改 `WritingHeatmap`：
```dart
// countByDay 查询从 28 天扩展到 365 天
// 改为按月分组的 PageView
// 每页显示一个月的日历网格（7列 × 最多5行）
```

- [ ] **Step 2: 添加图例**

```dart
// 热力图下方 Row:
Row(children: [
  Text('少', style: ...),
  _LegendBox(color: cs.primary.withValues(alpha: 0.1)),
  _LegendBox(color: cs.primary.withValues(alpha: 0.35)),
  _LegendBox(color: cs.primary.withValues(alpha: 0.6)),
  _LegendBox(color: cs.primary.withValues(alpha: 1.0)),
  Text('多', style: ...),
]),
```

- [ ] **Step 3: 添加连续记录徽章**

```dart
// 查询 currentStreak，如果 >= 7 天显示 🔥 "连续 N 天" 徽章
```

- [ ] **Step 4: 编译 + 测试 + Commit**

---

### Task 13: 情绪趋势图升级

**Skill 链：** `ecc:flutter-review` → `ecc:flutter-build`

**Files:**
- Modify: `zhiji_app/lib/features/home/widgets/emotion_trend_chart.dart`

- [ ] **Step 1: 添加标题**

```dart
// 图表上方添加标题
Padding(
  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
  child: Text('最近7天写作趋势', style: Theme.of(context).textTheme.titleMedium),
),
```

- [ ] **Step 2: 修复日期标签**

替换硬编码 `_dayLabels`：
```dart
static List<String> _buildDayLabels() {
  final now = DateTime.now();
  return List.generate(7, (i) {
    final day = now.subtract(Duration(days: 6 - i));
    return '${day.month}/${day.day}';
  });
}
```

- [ ] **Step 3: 添加 Y 轴和点击交互**

```dart
// leftTitles 改为显示数字刻度
// touchData: BarTouchData 处理点击，显示 tooltip
BarChartData(
  barTouchData: BarTouchData(
    touchTooltipData: BarTouchTooltipData(
      getTooltipItem: (group, groupIndex, rod, rodIndex) {
        return BarTooltipItem('${rod.toY.toInt()} 篇', ...);
      },
    ),
  ),
  // ...
)
```

- [ ] **Step 4: 编译 + 测试 + Commit**

---

### Task 14: 应用锁

**Skill 链：** `ecc:security-review` → `ecc:flutter-build`

**Files:**
- Create: `zhiji_app/lib/features/lock/app_lock_screen.dart`
- Modify: `zhiji_app/lib/main.dart`
- Modify: `zhiji_app/lib/features/settings/settings_screen.dart`
- Modify: `zhiji_app/pubspec.yaml`

- [ ] **Step 1: `pubspec.yaml` 添加依赖**

```yaml
  local_auth: ^2.3.0
```

Run: `cd zhiji_app && flutter pub get`

- [ ] **Step 2: 创建锁屏界面**

```dart
// features/lock/app_lock_screen.dart
// - 4-6 位 PIN 码输入（密码点遮罩显示）
// - local_auth 生物识别（指纹/面部）
// - SHA-256 哈希存储 PIN
// - 3次错误锁定30秒
// - 忘记密码：提示数据加密无法恢复
```

- [ ] **Step 3: `main.dart` 集成锁检查**

```dart
// 应用从后台恢复时检查是否需要解锁
// 使用 WidgetsBindingObserver 监听生命周期
```

- [ ] **Step 4: 设置页添加"应用锁"入口**

```dart
// settings_screen.dart — 在"数据管理" section 之前添加
ListTile(
  leading: const Icon(Icons.lock_outline),
  title: const Text('应用锁'),
  subtitle: Text(_hasLockPin ? '已启用' : '未启用'),
  trailing: const Icon(Icons.chevron_right),
  onTap: () => context.push('/lock-setup'),
),
```

- [ ] **Step 5: 安全审计**

使用 `ecc:security-review` 审查 PIN 存储（SHA-256 hash）、生物识别回退、锁定计时器安全性。

- [ ] **Step 6: 编译 + 测试 + Commit**

---

## 附录

### 验证检查清单

每个 Task 完成后必须执行：

```bash
cd zhiji_app
flutter analyze  # 0 error, 0 warning
flutter test     # 全部通过
```

### 最终验收

14 步全部完成 + 状态文件所有步骤 `completed`：

```bash
cd zhiji_app
flutter analyze        # 确认干净
flutter test           # 确认全绿
flutter build apk --release  # 构建成功
```

### 紧急绕过

若 Hook 阻止必要的修复操作，设置环境变量：
```bash
export UX_HOOK_BYPASS=true
```
