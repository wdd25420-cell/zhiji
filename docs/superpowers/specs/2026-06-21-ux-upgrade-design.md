# 知记 UX 全面升级 — 执行设计文档

> 基于 UX_REVIEW.md 的 P0+P1+P2 全覆盖方案
> 日期：2026-06-21

## 一、总览

3 阶段 14 步，从"工程师审美"升级到"精品 App 质感"。

| 阶段 | 步骤 | 目标 | 预计改动文件数 |
|------|------|------|--------------|
| 0: 基础跃升 (P0) | 1-4 | 新用户第一印象 + 视觉质感 | 5-8 |
| 1: 体验提升 (P1) | 5-7 | 加载体验 + AI 真实感 + 反直觉消除 | 8-12 |
| 2: 精品打磨 (P2) | 8-14 | 动画、气泡、编辑器、图表、应用锁 | 12-18 |

## 二、Hook 强制机制

**文件**：`.claude/settings.local.json` + `.claude/ux_upgrade_state.json`

**原理**：PreToolUse hook 拦截 Write/Edit/Bash，读取状态文件检查步骤依赖。非当前步骤的代码修改被拒绝。

**状态文件格式**：
```json
{
  "current_step": 1,
  "steps": {
    "1": {"status": "pending", "name": "首屏冷启动友好化"},
    "2": {"status": "pending", "name": "全局中文字体"},
    ...
  }
}
```

**跳过检查的条件**：
- 只读操作（Read/Glob/Grep）永远放行
- 当前步骤的文件修改放行
- 已完成步骤的文件修改警告但不阻止（允许修复 bug）

## 三、步骤详情

### 步骤 1：首屏冷启动友好化
- **Skill**：`ecc:flutter-review` → 代码审查 → `ecc:flutter-build` → 编译验证
- **改动文件**：
  - `chat_screen.dart`：`initState` 中检测 API Key 是否为空，为空时展示"今日卡片"欢迎页（不触发 `_send` 不报错）
  - `app_shell.dart`：`_showDrawer` 中 `context.go()` 全部改为 `context.push()`
  - `app_router.dart`：确保 push 路径正确
- **验证**：`flutter analyze` 干净 + 无 API Key 时首屏不报错

### 步骤 2：全局中文字体
- **Skill**：`apply-design-md` → `ecc:flutter-build`
- **改动文件**：
  - `app_theme.dart`：`fontFamily` 设为 `'SourceHanSansCN'`（Android），正文 `height: 1.7`
  - `pubspec.yaml`：添加 `google_fonts` 或内置字体文件
  - `color_tokens.dart`：微调主色方案（提高 primaryContainer 明度）
- **验证**：`flutter analyze` + 构建后字体生效

### 步骤 3：导航修复 + 底部 Tab 可选化
- **Skill**：`ecc:flutter-review` → `ecc:flutter-test`
- **改动文件**：
  - `app_shell.dart`：`context.go()` → `context.push()` 修复返回栈丢失
  - `app_router.dart`：`StatefulShellRoute` 已有 branches，保持但将 chat 设为默认分支即可
- **验证**：`flutter test` + 导航流程手动验证

### 步骤 4：AI 视觉语言统一
- **Skill**：`ecc:gan-design` → `ecc:flutter-build`
- **改动文件**：
  - `chat_screen.dart`：替换 `🤖` emoji → 紫蓝渐变图标
  - `home_screen.dart`：`🤖` + `AI` 文字方块 → 统一渐变图标
  - `app_theme.dart`：添加 `aiGradient` 工具方法
  - 新建 `core/widgets/ai_icon.dart`：统一 AI 入口图标组件
- **验证**：`flutter analyze` + 视觉一致性检查

### 步骤 5：骨架屏替换转圈
- **Skill**：`ecc:flutter-review` → `ecc:flutter-test`
- **改动文件**：
  - 新建 `core/widgets/shimmer_placeholder.dart`
  - `home_screen.dart`：4 处 `CircularProgressIndicator` → Shimmer
  - `chat_screen.dart`：加载状态
  - `diary_editor_screen.dart`：加载状态
  - `knowledge_editor_screen.dart`：加载状态
  - `search_screen.dart`：结果加载
  - 其他所有含 `CircularProgressIndicator` 的文件
- **验证**：`flutter test` + 所有加载状态视觉检查

### 步骤 6：Agent 流式输出 + 步骤提示
- **Skill**：`ecc:flutter-build` → `verify`
- **改动文件**：
  - `ai_api_service.dart`：添加 SSE 流式方法 `chatCompletionStream`
  - `agent_service.dart`：ReAct 循环中实时推送工具状态
  - `chat_screen.dart`：流式更新消息 + "正在搜索知识库…→正在联网…" 步骤文本
- **验证**：实际运行 + `flutter analyze`

### 步骤 7：深色模式三段开关
- **Skill**：`ecc:flutter-review` → `ecc:flutter-build`
- **改动文件**：
  - `settings_screen.dart:259`：循环点击 `onTap` → `SegmentedButton<ThemeMode>`
- **验证**：`flutter analyze` + 三段开关交互正确

### 步骤 8：列表入场动画 + 微交互
- **Skill**：`ecc:gan-design` → `verify`
- **改动文件**：
  - `home_screen.dart`：列表项 `AnimatedList` 交错入场
  - `app_shell.dart`：FAB 点击旋转+缩放动画
  - 新建 `core/widgets/save_success_animation.dart`：对勾画圈动画
  - 各列表页：日记列表、知识库列表交错动画
- **验证**：实际运行观察动画流畅度

### 步骤 9：对话气泡重做
- **Skill**：`ecc:flutter-review` → `ecc:gan-design`
- **改动文件**：
  - `chat_screen.dart:_buildBubble`：AI 气泡加左侧 4px 主色竖条 + 微阴影；用户气泡用 `primary` 实色
  - 气泡内文字添加长按复制功能
- **验证**：`flutter analyze` + 视觉对比

### 步骤 10：统计卡片不对称布局
- **Skill**：`ecc:gan-design` → `ecc:flutter-test`
- **改动文件**：
  - `home_screen.dart:_StatRow`：4 等分 → 1 大主卡（连续记录天数+渐变背景）+ 3 小卡横排
  - `color_tokens.dart`：添加渐变色调
- **验证**：`flutter test` + 布局视觉

### 步骤 11：编辑器视觉层次
- **Skill**：`ecc:flutter-review` → `ecc:gan-design`
- **改动文件**：
  - `diary_editor_screen.dart`：标题加边框分区、正文加边框、工具栏分组+收起
  - `knowledge_editor_screen.dart`：同上
  - `markdown_toolbar.dart`：工具按钮分组（格式/插入/AI），每组间有分隔
  - 字数统计调大为 `labelLarge`（14px）
- **验证**：`flutter analyze` + 编辑器视觉

### 步骤 12：写作热力图升级
- **Skill**：`ecc:flutter-review` → `ecc:flutter-test`
- **改动文件**：
  - `home_screen.dart:_HeatmapSection`：28 格 → 全年 365 格可滚动日历
  - 添加图例（"深色=写得多" 标注）
  - 添加连续记录徽章
- **验证**：`flutter test` + 热力图交互

### 步骤 13：情绪趋势图升级
- **Skill**：`ecc:flutter-review` → `ecc:flutter-build`
- **改动文件**：
  - `widgets/emotion_trend_chart.dart`：加坐标轴、标题、点击某天查看详情
- **验证**：`flutter analyze` + 图表可读性

### 步骤 14：应用锁
- **Skill**：`ecc:security-review` → `ecc:flutter-build`
- **改动文件**：
  - 新建 `features/lock/app_lock_screen.dart`：PIN 码输入+生物识别
  - `main.dart`：应用启动时检查锁状态
  - `settings_screen.dart`：添加"应用锁"设置项
  - `app_database.dart`：settings 表存锁 PIN hash
- **验证**：`flutter analyze` + 安全审计通过

## 四、不覆盖的内容

以下 UX_REVIEW.md 中标记为 P3/工程债的项目**不在本计划内**：
- Markdown 代码高亮/callout/目录
- 多媒体附件（照片/音频）
- 分享卡片生成
- 每日回顾推送（那年今日）
- 模板系统
- 依赖升级（go_router、riverpod）
- ProGuard freezed keep 规则
- 集成测试补充

## 五、风险与回退

- 每步完成后 `flutter analyze` 必须干净
- 每步完成后 `flutter test` 必须全绿
- 任何步骤失败 → 修复该步骤，不跳到下一步
- Hook 文件可在紧急情况下通过设置 `UX_HOOK_BYPASS=true` 环境变量临时跳过
