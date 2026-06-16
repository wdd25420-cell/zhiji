# 知记 (Zhiji)

> AI 原生个人知识管理 Android 应用

## 简介

知记是一款离线优先的个人知识管理应用。你可以写日记、存知识、添加附件、全局搜索，通过 DeepSeek API 获得 AI 摘要、续写、润色、总结和智能问答。所有数据本地存储，不上传云端。

## 功能亮点

- 📔 **日记** — 情绪追踪、日期分组、标签筛选、批量管理、草稿保护
- 📚 **知识库** — 分类浏览、Markdown 编辑、关联推荐
- 🤖 **AI 驱动** — 自动摘要、智能标签、续写/润色/总结、RAG 问答
- 🔍 **全文搜索** — FTS5 实时搜索、高亮、搜索历史
- 🎤 **语音输入** — 中文语音转文字
- 📎 **附件管理** — 拍照/相册/文档（PDF/Word/Excel 等）
- ⏮️ **撤销重做** — 50 步快照栈，定时自动保存
- 🌓 **深色模式** — 浅色/深色/跟随系统即时切换
- 📦 **数据导入导出** — JSON 格式全量备份（含标签+分类+AI 数据）
- 🔒 **隐私优先** — 所有数据本地存储，不上传云端。隐私政策 7 章节完整说明

## 技术栈

Flutter 3.38.5 · Dart 3.10.4 · Riverpod 2.6.1 · drift 2.28.2 (SQLite/FTS5) · GoRouter 14.8.0 · Material Design 3

## 开始

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

## 构建

```bash
# Debug APK
flutter build apk --debug

# Release APK (分包)
flutter build apk --release --split-per-abi
```

## 项目文档

| 文档 | 说明 |
|------|------|
| [CLAUDE.md](../CLAUDE.md) | 项目指令 + 架构速览 |
| [DEV_DOC.md](../DEV_DOC.md) | 完整开发文档 |
| [PROJECT_SUMMARY.md](../PROJECT_SUMMARY.md) | 项目总览 + 开发历程 |

## 版本

v1.0.0+1 · Android 5.0+ (API 24) · targetSdk 36
