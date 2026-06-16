# 知记 (Zhiji)

> AI 原生个人知识管理 Android 应用 · 离线优先 · 隐私至上

[![Flutter](https://img.shields.io/badge/Flutter-3.38.5-blue)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.10.4-blue)](https://dart.dev)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)

---

## 简介

知记是一款离线优先的个人知识管理 Android 应用。支持写日记、存知识、全文搜索、附件管理，通过 DeepSeek API 驱动 AI 摘要、续写、润色、总结和智能问答。所有数据均存储在本地设备，不上传云端。

### 功能亮点

| 模块 | 功能 |
|------|------|
| 📔 日记 | 情绪追踪(8种)、日期分组、标签筛选、批量管理、草稿保护 |
| 📚 知识库 | 分类浏览、Markdown 编辑、关联推荐、附件展示 |
| 🤖 AI 驱动 | 自动摘要、智能标签、续写/润色/总结、RAG 智能问答 |
| 🔍 全文搜索 | FTS5 实时搜索、匹配高亮、搜索历史持久化 |
| 🎤 语音输入 | 中文语音转文字、权限引导 |
| 📎 附件管理 | 拍照/相册/PDF/Word/Excel/PPT/ZIP 等主流格式 |
| ⏮️ 撤销重做 | 50 步快照栈、1.5s 定时自动保存 |
| 🌓 深色模式 | 浅色/深色/跟随系统即时切换 |
| 🔒 隐私优先 | 全本地存储、HTTPS 加密传输、allowBackup=false、隐私政策 7 章节 |

## 技术栈

| 类别 | 技术 |
|------|------|
| 框架 | Flutter 3.38.5 + Dart 3.10.4 |
| 状态管理 | Riverpod 2.6.1 |
| 数据库 | drift 2.28.2 (SQLite + FTS5 全文搜索) |
| 路由 | GoRouter 14.8.0 (StatefulShellRoute + CustomTransitionPage) |
| 网络 | Dio 5.7.0 (HTTPS-only, 15s/30s 超时) |
| AI | DeepSeek API (7 种 AI 方法 + 内容截断保护) |
| UI | Material Design 3 + fl_chart |
| 安全 | FlutterSecureStorage (Android Keystore) + R8 混淆 |

## 架构

```
lib/
├── main.dart                    # ProviderScope + 全局异常兜底
├── core/
│   ├── theme/                   # MD3 ColorScheme.fromSeed(#00897B)
│   ├── router/                  # GoRouter 4 Tab + 8 全屏 (fade+slide)
│   ├── database/                # drift: 7 表 + FTS5 + 6 触发器 + 3 DAO
│   ├── widgets/                 # 8 个共享组件
│   ├── network/                 # Dio 客户端 + DeepSeek API 服务
│   └── utils/                   # 文件导入 + 附件管理
└── features/
    ├── home/                    # 仪表盘 (统计卡 + 趋势图 + 热力图 + AI 回顾)
    ├── diary/                   # 日记列表 + 编辑器 (情绪/语音/附件/AI/撤销/批量删除)
    ├── knowledge/               # 知识浏览 + 编辑器 + 详情 (Markdown/关联推荐)
    ├── chat/                    # AI 智能问答 (RAG: FTS5 → DeepSeek)
    ├── search/                  # FTS5 全文搜索 + RichText 高亮
    └── settings/                # API Key/深色模式/导入导出/隐私政策
```

## 快速开始

```bash
# 安装依赖
flutter pub get

# 代码检查 (0 error, 0 warning)
flutter analyze

# 运行测试 (67/67)
flutter test

# 启动应用
flutter run
```

## 构建

```bash
# Debug APK
flutter build apk --debug

# Release APK (分包)
flutter build apk --release --split-per-abi
```

产物：

| 文件 | 大小 | 适用 |
|------|------|------|
| `app-arm64-v8a-release.apk` | 20.7 MB | 主流 64 位手机 |
| `app-armeabi-v7a-release.apk` | 18.5 MB | 老旧 32 位手机 |
| `app-x86_64-release.apk` | 22.0 MB | 模拟器 |

## 项目状态

| 指标 | 值 |
|------|-----|
| Dart 源文件 | 40 个 |
| 测试文件 | 7 个 |
| 测试用例 | 67 个 (全部通过) |
| `flutter analyze` | 0 error · 0 warning |
| Android API | 24+ (Android 7.0) |
| Target SDK | 36 (Android 15) |

## 文档

| 文档 | 说明 |
|------|------|
| [CLAUDE.md](CLAUDE.md) | AI 编码助手指令 |
| [DEV_DOC.md](DEV_DOC.md) | 完整开发文档 |
| [PROJECT_SUMMARY.md](PROJECT_SUMMARY.md) | 项目开发总览 |
| [APP_LAUNCH_CHECKLIST.md](APP_LAUNCH_CHECKLIST.md) | 上线前工作流程 |

## 配置 DeepSeek API

1. 打开应用 → 设置 → 输入 API Key (`sk-...`) → 保存
2. API Key 通过 Android Keystore 加密存储，保存后即时生效
3. 所有 AI 请求通过 HTTPS 加密传输至 `api.deepseek.com`

## License

MIT
