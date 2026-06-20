# 知记 (Zhiji)

> AI Agent 驱动的个人知识管理 Android 应用 · 离线优先 · 隐私至上

[![Flutter](https://img.shields.io/badge/Flutter-3.38.5-blue)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.10.4-blue)](https://dart.dev)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)

---

## 简介

知记是一款 **AI Agent 驱动** 的个人知识管理 Android 应用。打开即看首页仪表盘，通过底部 5 Tab 一键切换。内置**手写 ReAct 循环**，Agent 自主规划多步操作——搜索本地知识、写日记、联网搜索、分析统计——像助手一样完成复杂任务。所有数据存储在本地，不上传云端。

### 架构 v5.0 — 首页首屏 + 5 Tab

```
用户打开 App → 首页仪表盘 (首屏)
  ┌────────┬────────┬────────┬────────┬────────┐
  │ 首页   │ 日记   │ 知识库  │ AI对话 │ 设置   │
  └────────┴────────┴────────┴────────┴────────┘
```

Agent 拥有 **7 个工具**，按需自主调用：

| 工具 | 能力 |
|------|------|
| `search_knowledge` | FTS5 全文搜索日记和知识库 |
| `save_to_knowledge` | 将内容存入知识库 |
| `write_diary` | 写日记（含情绪标签）|
| `get_diary_stats` | 日记统计（篇数/连续天数/情绪分布）|
| `list_categories` | 列出知识库分类 |
| `read_attachment` | 读取上传的文本附件 |
| `web_search` | cn.bing.com 抓取（国内可用，免费无限）|

## Agent 系统

知记的核心是一个**手写 ReAct (Reasoning + Acting) 循环**——Agent 不只是一问一答，而是自主规划多步操作来完成复杂需求。

### 工作流程

```
用户提问 → ┌─────────────────────────────────────────┐
           │        ReAct 循环 (最多 5 轮)             │
           │  Thinking → 选择工具 → 执行 → 分析结果    │
           │     ↑                              ↓     │
           │     └──── 需要更多信息？继续 ←──────┘     │
           └─────────────────────────────────────────┘
                                                        ↓
                                                   最终回答
```

### 核心特性

| 特性 | 实现 |
|------|------|
| 推理框架 | 手写 ReAct 循环，5 轮迭代上限 |
| 工具系统 | 抽象 `AgentTool` 基类 + `ToolRegistry`，7 个工具即插即用 |
| 流式输出 | `runStream()` 异步生成器，逐 `AgentStep` 推送状态 (thinking→searching→writing→responding→done) |
| 多层超时 | 单工具 45s / 总循环 120s / HTTP 60s，三重防护 |
| 防重复 | 同工具调用 >3 次自动终止，防止死循环 |
| 对话记忆 | `AgentMemory` 追踪最近 10 个主题，自动注入 System Prompt |
| 消息顺序 | OpenAI 标准格式：`assistant(tool_calls)` → `tool(result)`，修复早期 bug |
| 错误恢复 | 工具执行后 API 故障时告知已完成操作，而非空白错误 |

### 联网搜索

| 特性 | 实现 |
|------|------|
| 方式 | cn.bing.com HTML 抓取解析 |
| 费用 | 免费无限，无需任何 API Key |
| 可用性 | 国内直连，无代理依赖 |
| 解析器 | 与开源 [bing-cn-mcp](https://www.npmjs.com/package/bing-cn-mcp) 兼容的解析逻辑 |

### 功能亮点

| 模块 | 功能 |
|------|------|
| 🤖 AI Agent | ReAct 循环(5轮)，7工具自主调用，SSE 流式输出，步骤提示，会话持久化 |
| 📔 日记 | 情绪追踪(8种)、日期分组、标签筛选、AI 自动摘要/标签 |
| 📚 知识库 | 分类浏览、Markdown 编辑、关联推荐、附件展示 |
| 💬 AI 对话 | Markdown 渲染(代码块/引用/列表)、呼吸点动画、步骤状态提示 |
| 🔍 全文搜索 | FTS5 实时搜索、匹配高亮 |
| 🌐 联网搜索 | cn.bing.com 抓取，国内直连，免费无限，无需配置 |
| 📎 附件 | 文件选择器(图片/PDF/Word/Excel/ZIP等) + 文本输入备用 |
| 🔒 应用锁 | 6位PIN码 + 3次错误锁定30秒 + 暴力破解防护 |
| 🎨 视觉 | 骨架屏(Shimmer)、紫蓝渐变AI图标、气泡重做(竖条+阴影)、不对称统计卡 |
| 🌓 深色模式 | SegmentedButton 三段切换 + 深色专用色(#121212/#1E1E1E) |
| ✨ AI 编辑器 | 续写/润色/总结、自动摘要、智能标签 |

## 技术栈

| 类别 | 技术 |
|------|------|
| 框架 | Flutter 3.38.5 + Dart 3.10.4 |
| 状态管理 | Riverpod 2.6.1 |
| 数据库 | drift 2.28.2 (SQLite + FTS5 + agent_messages) |
| 路由 | GoRouter 14.8 (StatefulShellRoute 5分支) |
| 网络 | Dio 5.7 (HTTPS-only) |
| AI | DeepSeek API (ReAct + 7工具 + SSE流式) |
| 搜索 | cn.bing.com HTML 抓取解析 |
| 图表 | fl_chart 0.69 |
| UI | Material Design 3 + google_fonts |
| 安全 | FlutterSecureStorage + R8 混淆 + allowBackup=false |

## 项目状态

| 指标 | 值 |
|------|-----|
| `flutter analyze` | 0 error, 0 warning |
| `flutter test` | 128 通过 |
| Release APK | 59.4MB 单包 |
| Dart 源文件 | 50+ 个 |
| Agent 工具 | 7 个 (6 本地 + 1 联网) |

## 快速开始

```bash
cd zhiji_app
flutter pub get
flutter run --release
```

首次使用：打开 App → 底部「设置」Tab → 填入 DeepSeek API Key → 保存。无需其他配置，联网搜索开箱即用。

## 构建 APK

```bash
flutter build apk --release
# 输出: build/app/outputs/flutter-apk/app-release.apk (~59MB)

# 安装到模拟器 (BlueStacks)
adb connect 127.0.0.1:5555
adb install build\app\outputs\flutter-apk\app-release.apk
```

## 项目文档

- [设计规格](DESIGN_SPEC.md) — 设计 Token → Flutter ThemeData + Agent 架构
- [开发文档](DEV_DOC.md) — 环境配置、架构、API 流程
- [开发总览](PROJECT_SUMMARY.md) — 从零到交付的完整记录
- [实施计划](IMPLEMENTATION_PLAN.md) — 技术选型与实施步骤
