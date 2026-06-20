import "dart:io";
import "package:drift/drift.dart";
import "package:flutter/foundation.dart";
import "package:zhiji/core/database/app_database.dart";
import "package:zhiji/core/database/daos/knowledge_dao.dart";
import "package:zhiji/core/database/daos/diary_dao.dart";
import "package:zhiji/core/utils/file_attachment_manager.dart";
import "package:path/path.dart" as p;
import "tool.dart";
import "web_search.dart";

// ---------------------------------------------------------------
// Tool 1: search_knowledge
// ---------------------------------------------------------------
class SearchKnowledgeTool extends AgentTool {
  final AppDatabase db;
  SearchKnowledgeTool(this.db);

  @override String get name => "search_knowledge";
  @override String get description => "搜索用户的知识库和日记，返回匹配结果。";
  @override Map<String, dynamic> get parameters => {
    "type": "object",
    "properties": {"query": {"type": "string", "description": "搜索关键词"}},
    "required": ["query"],
  };

  @override
  Future<ToolResult> execute(ToolCall call) async {
    try {
      final query = call.arguments["query"] as String;
      final results = await db.search(query);
      return ToolResult(
        toolCallId: call.id,
        content: results.isEmpty ? "未找到相关结果" : results.toString(),
      );
    } catch (e) {
      debugPrint("[search_knowledge] 异常: $e");
      return ToolResult.error(call.id, "搜索知识库时遇到问题，请稍后重试");
    }
  }
}

// ---------------------------------------------------------------
// Tool 2: save_to_knowledge — 真实 DB 写入
// ---------------------------------------------------------------
class SaveToKnowledgeTool extends AgentTool {
  final AppDatabase db;
  SaveToKnowledgeTool(this.db);

  @override String get name => "save_to_knowledge";
  @override String get description => "将内容存入知识库。";
  @override Map<String, dynamic> get parameters => {
    "type": "object",
    "properties": {
      "title": {"type": "string", "description": "知识标题"},
      "content": {"type": "string", "description": "知识内容(Markdown)"},
      "category_id": {"type": "integer", "description": "分类ID(可选)"},
    },
    "required": ["title", "content"],
  };

  @override
  Future<ToolResult> execute(ToolCall call) async {
    try {
      final title = call.arguments["title"] as String;
      final content = call.arguments["content"] as String;
      if (title.trim().isEmpty) {
        return ToolResult.error(call.id, "保存失败：标题不能为空");
      }
      if (content.trim().isEmpty) {
        return ToolResult.error(call.id, "保存失败：内容不能为空");
      }

      final dao = KnowledgeDao(db);
      final categoryId = (call.arguments["category_id"] as num?)?.toInt();
      await dao.insertEntry(
        KnowledgeEntriesCompanion(
          title: Value(title.trim()),
          contentMarkdown: Value(content),
          categoryId: Value(categoryId),
        ),
      );

      return ToolResult(toolCallId: call.id, content: "知识条目已保存：$title");
    } catch (e) {
      debugPrint("[save_to_knowledge] 异常: $e");
      return ToolResult.error(call.id, "保存知识时遇到问题，请稍后重试");
    }
  }
}

// ---------------------------------------------------------------
// Tool 3: write_diary — 真实 DB 写入
// ---------------------------------------------------------------
class WriteDiaryTool extends AgentTool {
  final AppDatabase db;
  WriteDiaryTool(this.db);

  @override String get name => "write_diary";
  @override String get description => "帮用户写日记。";
  @override Map<String, dynamic> get parameters => {
    "type": "object",
    "properties": {
      "title": {"type": "string", "description": "日记标题"},
      "content": {"type": "string", "description": "日记正文"},
      "emotion": {"type": "string", "description": "情绪标签(可选)"},
    },
    "required": ["title", "content"],
  };

  @override
  Future<ToolResult> execute(ToolCall call) async {
    try {
      final title = call.arguments["title"] as String;
      final content = call.arguments["content"] as String;
      if (title.trim().isEmpty) {
        return ToolResult.error(call.id, "保存失败：日记标题不能为空");
      }
      if (content.trim().isEmpty) {
        return ToolResult.error(call.id, "保存失败：日记内容不能为空");
      }

      final dao = DiaryDao(db);
      final emotion = call.arguments["emotion"] as String?;
      await dao.insertEntry(
        DiaryEntriesCompanion(
          title: Value(title.trim()),
          bodyMarkdown: Value(content),
          emotion: Value(emotion),
        ),
      );

      return ToolResult(toolCallId: call.id, content: "日记已保存：$title");
    } catch (e) {
      debugPrint("[write_diary] 异常: $e");
      return ToolResult.error(call.id, "保存日记时遇到问题，请稍后重试");
    }
  }
}

// ---------------------------------------------------------------
// Tool 4: get_diary_stats — 真实统计查询
// ---------------------------------------------------------------
class GetDiaryStatsTool extends AgentTool {
  final AppDatabase db;
  GetDiaryStatsTool(this.db);

  @override String get name => "get_diary_stats";
  @override String get description => "查看日记统计数据。";
  @override Map<String, dynamic> get parameters => {"type": "object", "properties": {}};

  @override
  Future<ToolResult> execute(ToolCall call) async {
    try {
      final dao = DiaryDao(db);
      final total = await dao.countAll();
      final streak = await dao.currentStreak();
      final weeklyWords = await dao.wordCountThisWeek();
      final emotions = await dao.countByEmotion();

      final lines = <String>[
        "日记总数：$total 篇",
        "连续记录：$streak 天",
        "本周字数：$weeklyWords",
      ];
      if (emotions.isNotEmpty) {
        final emoStr =
            emotions.entries.map((e) => "${e.key}: ${e.value}篇").join("，");
        lines.add("情绪分布：$emoStr");
      }

      return ToolResult(toolCallId: call.id, content: lines.join("\n"));
    } catch (e) {
      debugPrint("[get_diary_stats] 异常: $e");
      return ToolResult.error(call.id, "查询统计时遇到问题，请稍后重试");
    }
  }
}

// ---------------------------------------------------------------
// Tool 5: list_categories — 从 DB 读取
// ---------------------------------------------------------------
class ListCategoriesTool extends AgentTool {
  final AppDatabase db;
  ListCategoriesTool(this.db);

  @override String get name => "list_categories";
  @override String get description => "列出知识库分类。";
  @override Map<String, dynamic> get parameters => {"type": "object", "properties": {}};

  @override
  Future<ToolResult> execute(ToolCall call) async {
    try {
      final dao = KnowledgeDao(db);
      final categories = await dao.listCategories();
      if (categories.isEmpty) {
        return ToolResult(toolCallId: call.id, content: "暂无分类");
      }
      final names = categories.map((c) => c.name).join(", ");
      return ToolResult(toolCallId: call.id, content: names);
    } catch (e) {
      debugPrint("[list_categories] 异常: $e");
      return ToolResult.error(call.id, "获取分类列表时遇到问题，请稍后重试");
    }
  }
}

// ---------------------------------------------------------------
// Tool 6: read_attachment（FileAttachmentManager 集成 + 错误友好包装）
// ---------------------------------------------------------------
class ReadAttachmentTool extends AgentTool {
  List<dynamic> _attachments = [];
  /// 测试用：设置后优先使用此目录解析路径
  Directory? testBaseDir;

  @override
  void setAttachments(List<dynamic> attachments) {
    _attachments = attachments;
  }

  @override String get name => "read_attachment";
  @override String get description => "读取用户上传的文本附件内容。";
  @override Map<String, dynamic> get parameters => {
    "type": "object",
    "properties": {"attachment_id": {"type": "string", "description": "附件ID（对应 storedPath）"}},
    "required": ["attachment_id"],
  };

  @override
  Future<ToolResult> execute(ToolCall call) async {
    try {
      final id = call.arguments["attachment_id"] as String;

      AttachedFile? attached;
      for (final a in _attachments) {
        if (a is AttachedFile && a.storedPath == id) {
          attached = a;
          break;
        }
      }
      if (attached == null) {
        return ToolResult.error(call.id, "未找到附件: $id");
      }

      final String fullPath;
      if (testBaseDir != null) {
        fullPath = p.join(testBaseDir!.path, attached.storedPath);
      } else {
        fullPath = await FileAttachmentManager.getFullPath(attached.storedPath);
      }

      final file = File(fullPath);
      if (!await file.exists()) {
        return ToolResult.error(call.id, "文件不存在: ${attached.name}");
      }

      final ext = file.path.split('.').last.toLowerCase();
      const textExts = ["txt", "md", "csv", "json", "dart", "yaml", "xml", "html"];
      if (!textExts.contains(ext)) {
        return ToolResult.error(call.id, "此文件类型暂不支持预览（$ext）");
      }

      final content = await file.readAsString();
      return ToolResult(toolCallId: call.id, content: content);
    } catch (e) {
      debugPrint("[read_attachment] 异常: $e");
      return ToolResult.error(call.id, "读取文件时遇到问题，请稍后重试");
    }
  }
}

// ---------------------------------------------------------------
// Tool 7: web_search — DuckDuckGo 免费搜索
// ---------------------------------------------------------------
class WebSearchTool extends AgentTool {
  final AppDatabase db;
  WebSearchTool(this.db);

  @override String get name => "web_search";
  @override String get description => "联网搜索最新信息（DuckDuckGo，免费无限）。";
  @override Map<String, dynamic> get parameters => {
    "type": "object",
    "properties": {
      "query": {"type": "string", "description": "搜索关键词"},
      "count": {"type": "integer", "description": "返回结果数，默认5"},
    },
    "required": ["query"],
  };

  @override
  Future<ToolResult> execute(ToolCall call) async {
    try {
      final query = call.arguments["query"] as String;
      final count = (call.arguments["count"] as num?)?.toInt() ?? 5;
      final result = await webSearch(query, count: count);
      if (result.isError) {
        return ToolResult.error(call.id, result.error ?? "搜索失败");
      }
      if (result.items.isEmpty) {
        return ToolResult(toolCallId: call.id, content: "未找到相关结果");
      }
      final lines = <String>[];
      for (var i = 0; i < result.items.length; i++) {
        final item = result.items[i];
        lines.add("${i + 1}. ${item.title}");
        lines.add("   ${item.url}");
        lines.add("   ${item.snippet}");
      }
      return ToolResult(toolCallId: call.id, content: lines.join("\n"));
    } catch (e) {
      debugPrint("[web_search] $e");
      return ToolResult.error(call.id, "联网搜索暂不可用，请检查网络");
    }
  }
}

