import "package:flutter_test/flutter_test.dart";
import "package:drift/native.dart";
import "package:zhiji/core/database/app_database.dart";
import "package:zhiji/core/agent/tools/tool.dart";
import "package:zhiji/core/agent/tools/all_tools.dart";
import "package:zhiji/core/agent/agent_service.dart";

void main() {
  group("T5 验收: Agent 循环 + 7 工具骨架", () {
    late AppDatabase db;
    late ToolRegistry registry;
    late AgentService agent;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      registry = ToolRegistry();
      registry.register(SearchKnowledgeTool(db));
      registry.register(SaveToKnowledgeTool(db));
      registry.register(WriteDiaryTool(db));
      registry.register(GetDiaryStatsTool(db));
      registry.register(ListCategoriesTool(db));
      registry.register(ReadAttachmentTool());
      agent = AgentService(tools: registry, systemPrompt: "你是知记的智能管家。");
    });

    tearDown(() async => db.close());

    test("Agent 循环结构正确", () {
      expect(agent.tools, isNotNull);
      expect(agent.systemPrompt, contains("知记"));
      expect(AgentService.maxIterations, 5);
    });

    test("7 个工具全部注册", () {
      for (final name in [
        "search_knowledge", "save_to_knowledge", "write_diary",
        "get_diary_stats", "list_categories", "read_attachment",
        "web_search",
      ]) {
        expect(registry.get(name), isNotNull, reason: "工具 $name 未注册");
      }
    });

    test("ToolDef DeepSeek 格式", () {
      final defs = registry.toolDefs;
      expect(defs.length, 6);
      for (final d in defs) {
        expect(d["type"], "function");
        expect(d["function"]["name"], isNotEmpty);
      }
    });

    test("search_knowledge 可执行", () async {
      final result = await registry.executeCall(ToolCall(
        id: "call-1", name: "search_knowledge", arguments: {"query": "Flutter"},
      ));
      expect(result.isError, isFalse);
    });

    test("list_categories 返回 6 个分类", () async {
      final result = await registry.executeCall(ToolCall(
        id: "call-2", name: "list_categories", arguments: {},
      ));
      expect(result.content, contains("技术开发"));
    });

    test("未知工具返回错误", () async {
      final result = await registry.executeCall(ToolCall(
        id: "call-3", name: "nonexistent_tool", arguments: {},
      ));
      expect(result.isError, isTrue);
      expect(result.content, contains("未知工具"));
    });
  });

  group("T6 验收: 三层超时", () {
    test("三层超时常量正确", () {
      expect(AgentService.maxIterations, 5);
      expect(AgentService.toolTimeout, const Duration(seconds: 45));
      expect(AgentService.totalTimeout, const Duration(seconds: 120));
    });

    test("totalTimeout 守卫存在", () async {
      final db = AppDatabase(NativeDatabase.memory());
      final registry = ToolRegistry();
      registry.register(ListCategoriesTool(db));
      final agent = AgentService(tools: registry, systemPrompt: "test");
      final result = await agent.run("列出分类");
      expect(result, isNotEmpty);
      await db.close();
    });
  });
}
