import "package:flutter_test/flutter_test.dart";
import "package:drift/drift.dart" hide isNotNull, isNull;
import "package:drift/native.dart";
import "package:zhiji/core/database/app_database.dart";
import "package:zhiji/core/agent/tools/tool.dart";
import "package:zhiji/core/agent/tools/all_tools.dart";
import "package:zhiji/core/agent/agent_service.dart";

/// T-E2E-1: Agent 知识搜索 全链路
void main() {
  group("T-E2E-1 Agent 全链路集成", () {
    late AppDatabase db;
    late ToolRegistry registry;
    late AgentService agent;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());

      // 预置知识条目
      await db.knowledgeDao.insertEntry(
        KnowledgeEntriesCompanion.insert(
          title: "Flutter Riverpod 最佳实践",
          contentMarkdown: Value(
            "Riverpod 是 Flutter 推荐的依赖注入方案。"
            "推荐用 FutureProvider 处理异步数据。",
          ),
          categoryId: const Value(1),
        ),
      );

      final readTool = ReadAttachmentTool();

      registry = ToolRegistry();
      registry.register(SearchKnowledgeTool(db));
      registry.register(SaveToKnowledgeTool(db));
      registry.register(WriteDiaryTool(db));
      registry.register(GetDiaryStatsTool(db));
      registry.register(ListCategoriesTool(db));
      registry.register(readTool);

      agent = AgentService(
        tools: registry,
        systemPrompt:
            "你是知记的智能管家。用中文回答。"
            "需要检索知识时调用 search_knowledge。",
      );
    });

    tearDown(() async => db.close());

    test("知识搜索 Agent 全链路", () async {
      final answer = await agent.run("Flutter Riverpod 怎么用？");
      expect(answer, isNotEmpty);
    }, skip: "需要有效 DeepSeek API Key");

    test("搜索不存在的关键词返回空", () async {
      final results = await db.search("量子计算机xyz789");
      expect(results, isEmpty);
    });

    test("Agent 工具注册表含 6 个工具", () {
      final names = [
        "search_knowledge", "save_to_knowledge", "write_diary",
        "get_diary_stats", "list_categories", "read_attachment",
      ];
      for (final name in names) {
        expect(registry.get(name), isNotNull, reason: "工具 $name 未注册");
      }
    });

    test("ReadAttachmentTool 无附件返回友好错误", () async {
      final tool = registry.get("read_attachment")!;
      final result = await tool.execute(ToolCall(
        id: "test-1",
        name: "read_attachment",
        arguments: {"attachment_id": "nonexistent"},
      ));
      expect(result.isError, isTrue);
      expect(result.content, contains("未找到附件"));
    });
  });
}
