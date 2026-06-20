# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目

知记 (Zhiji) — AI Agent 驱动的个人知识管理 Flutter 应用 (Android APK)。DeepSeek API 驱动 ReAct Agent，自主调用 7 个本地工具 + 联网搜索。

## 当前状态

| 项目 | 状态 |
|------|------|
| `flutter analyze` | 0 error, 2 info (已有) |
| `flutter test` | 128 通过，10 跳过(需API Key) |
| Release APK | `build\app\outputs\flutter-apk\app-release.apk` ~59MB |
| AI 接入 | DeepSeek `/chat/completions` — ReAct + 7工具 + SSE流式 |
| 联网搜索 | cn.bing.com 抓取（国内可用，无需额外Key） |
| 架构 | v5.0 首页首屏 + 底部5Tab |
| 聊天 | Markdown渲染 + 呼吸点动画 + 步骤提示 |

## 环境

| 组件 | 路径/值 |
|------|--------|
| JDK | `C:\Program Files\Android\Android Studio\jbr` (JBR JDK 21) |
| Flutter | `C:\flutter` (3.38.5) |
| Android SDK | `%LOCALAPPDATA%\Android\Sdk` |
| BlueStacks | `C:\Program Files\BlueStacks_nxt_cn\HD-Player.exe` |

## 架构

```
lib/
├── main.dart                        # ProviderScope + APIKey + 应用锁检查
├── core/
│   ├── agent/
│   │   ├── agent_service.dart       # ReAct循环 + runStream(流式输出)
│   │   ├── agent_provider.dart      # 7工具 + system prompt + 记忆注入
│   │   ├── agent_memory.dart        # 对话主题追踪(最近10个)
│   │   └── tools/
│   │       ├── tool.dart            # 工具基类 + ToolRegistry
│   │       ├── all_tools.dart       # 7工具实现
│   │       └── web_search.dart      # cn.bing.com 抓取(免费无限)
│   ├── database/                    # drift SQLite + FTS5
│   ├── network/
│   │   ├── dio_client.dart          # Dio单例 + APIKey注入
│   │   └── ai_api_service.dart      # chatCompletion + Stream + 编辑器AI
│   ├── widgets/                     # app_shell, shimmer, ai_icon, markdown_toolbar
│   ├── router/app_router.dart       # StatefulShellRoute 5分支
│   ├── theme/                       # AppTheme(fontFamily+dark色), ColorTokens
│   └── providers/theme_provider.dart
└── features/
    ├── chat/chat_screen.dart        # Markdown聊天 + 流式 + 附件(文本备用)
    ├── diary/                       # 列表 + 编辑器
    ├── knowledge/                   # 浏览 + 详情 + 编辑器
    ├── home/home_screen.dart        # 仪表盘(统计卡/热力图/情绪图)
    ├── lock/app_lock_screen.dart    # PIN码应用锁
    ├── search/search_screen.dart    # 全文搜索
    └── settings/settings_screen.dart # APIKey/主题/应用锁/数据管理
```

## Agent 系统

### ReAct 循环
- 5轮max, 总超时120s, 单工具45s
- 重复工具检测(>3次终止)
- runStream() 流式产出 AgentStep(thinking/searching/writing/responding/done)
- 消息顺序修复: assistant(tool_calls) → tool结果

### 7 个工具
1. `search_knowledge` — FTS5全文搜索
2. `save_to_knowledge` — 写入知识库
3. `write_diary` — 写入日记
4. `get_diary_stats` — 日记统计
5. `list_categories` — 知识库分类
6. `read_attachment` — 读取文本附件
7. `web_search` — cn.bing.com 抓取

### 聊天 UI
- AI: MarkdownBody(标题/代码块/引用/列表), 左侧4px竖条, 88%宽
- 用户: SelectableText, primary实色, 75%宽
- 长按复制 + BreathingDots加载动画 + 步骤提示
- 附件: 文件选择器 → 失败时弹文本输入框

## 常用命令

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test
flutter build apk --release
adb connect 127.0.0.1:5555
adb install build\app\outputs\flutter-apk\app-release.apk
```
