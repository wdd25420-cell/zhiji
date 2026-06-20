# 知记 (Zhiji)

> AI Agent 驱动的个人知识管理 Android 应用 · 离线优先 · 隐私至上

[![Flutter](https://img.shields.io/badge/Flutter-3.38.5-blue)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.10.4-blue)](https://dart.dev)

---

## 简介

知记是一款 **首页首屏 + AI Agent** 的个人知识管理 Android 应用。打开即对话，通过 DeepSeek API 驱动的 ReAct Agent 自动调用本地知识库、日记、附件和联网搜索来回答用户问题。支持写日记、存知识、全文搜索、附件管理。所有数据均存储在本地设备，不上传云端。

### 架构 v5.0 — 首页首屏 + 底部 5 Tab

\\\
用户打开 App → Agent 对话界面（首屏）
                    ↓
          FAB 功能抽屉（BottomSheet）
          ├── 写日记
          ├── 知识库
          ├── 首页仪表盘
          └── 设置
\\\

Agent 拥有 7 个工具，按需自主调用：

| 工具 | 能力 |
|------|------|
| search_knowledge | 全文搜索用户日记和知识库 |
| save_to_knowledge | 将对话内容存入知识库 |
| write_diary | 帮用户写日记 |
| get_diary_stats | 查询日记统计数据（篇数/连续天数/情绪分布）|
| list_categories | 列出知识库分类 |
| ead_attachment | 读取用户上传的文本附件 |
| web_search | cn.bing.com 抓取（国内可用，免费无限）|

### 功能亮点

| 模块 | 功能 |
|------|------|
| 🤖 AI Agent | ReAct 循环（5 轮），工具自主调用，会话历史持久化，Agent 记忆 |
| 📔 日记 | 情绪追踪(8种)、日期分组、标签筛选、批量管理、草稿保护 |
| 📚 知识库 | 分类浏览、Markdown 编辑、关联推荐、附件展示 |
| ✨ AI 驱动 | 自动摘要、智能标签、续写/润色/总结 |
| 🔍 全文搜索 | FTS5 实时搜索、匹配高亮、搜索历史持久化 |
| 🎤 语音输入 | 中文语音转文字、权限引导 |
| 📎 附件管理 | 拍照/相册/PDF/Word/Excel/PPT/ZIP 等主流格式 |
| ⏮️ 撤销重做 | 50 步快照栈、1.5s 定时自动保存 |
| 🌓 深色模式 | 浅色/深色/跟随系统即时切换 |
| 🔒 隐私优先 | 全本地存储、HTTPS 加密传输、allowBackup=false、隐私政策 |

## 技术栈

| 类别 | 技术 |
|------|------|
| 框架 | Flutter 3.38.5 + Dart 3.10.4 |
| 状态管理 | Riverpod 2.6.1 |
| 数据库 | drift 2.28.2 (SQLite + FTS5 全文搜索 + agent_messages 会话表) |
| 路由 | GoRouter 14.8.0 (StatefulShellRoute + CustomTransitionPage) |
| 网络 | Dio 5.7.0 (HTTPS-only) |
| AI | DeepSeek API（Agent ReAct 循环 + 7 工具 + 4 种编辑器 AI 方法）|
| 搜索 | Bing Web Search API |
| UI | Material Design 3 + fl_chart |
| 安全 | FlutterSecureStorage (Android Keystore) + R8 混淆 |

## 项目状态

| 指标 | 值 |
|------|-----|
| Dart 源文件 | 45 个 |
| 测试文件 | 19 个 |
| Release APK | 58.8MB（单包）|
| 版本 | v4.0（Agent 首屏）|
| 最近修复 | 多轮对话角色映射 bug（ai→assistant）|

## 快速开始

\\\ash
cd C:\AI\claudecode\projects\zhiji\zhiji_app
flutter pub get
flutter run --release
\\\

首次使用需在「设置」中填入 DeepSeek API Key。

## 项目文档

- [设计规格](DESIGN_SPEC.md) — 设计 Token → Flutter ThemeData + Agent 架构
- [开发文档](DEV_DOC.md) — 环境配置、架构、API 流程
- [开发总览](PROJECT_SUMMARY.md) — 从零到交付的完整记录
- [实施计划](IMPLEMENTATION_PLAN.md) — 技术选型与实施步骤
