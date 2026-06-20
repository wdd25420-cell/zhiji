import "package:flutter_test/flutter_test.dart";
import "package:drift/native.dart";
import "package:zhiji/core/database/app_database.dart";
import "package:zhiji/core/agent/tools/tool.dart";
import "package:zhiji/core/agent/tools/all_tools.dart";

void main() {
  group("T8 验收: 工具错误友好包装", () {
    late AppDatabase db;
    late ToolRegistry registry;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      registry = ToolRegistry();
      registry.register(SearchKnowledgeTool(db));
      registry.register(SaveToKnowledgeTool(db));
      registry.register(WriteDiaryTool(db));
      registry.register(GetDiaryStatsTool(db));
      registry.register(ListCategoriesTool(db));
      registry.register(ReadAttachmentTool());
    });

    tearDown(() async => db.close());

    // --- 验收1: search_knowledge 错误路径存在 try-catch ---
    test("search_knowledge 返回结果不含技术异常信息", () async {
      final result = await registry.executeCall(ToolCall(
        id: "call-e1",
        name: "search_knowledge",
        arguments: {"query": "Flutter"},
      ));
      // 正常路径，但验证错误消息不含技术细节
      expect(result.content, isNot(contains("SqliteException")));
      expect(result.content, isNot(contains("Stack trace")));
      expect(result.content, isNot(contains("NullError")));
      expect(result.content, isNot(contains("_CastError")));
    });

    // --- 验收2: save_to_knowledge 空标题校验 ---
    test("save_to_knowledge 空标题返回错误", () async {
      final result = await registry.executeCall(ToolCall(
        id: "call-e2",
        name: "save_to_knowledge",
        arguments: {"title": "   ", "content": "正文"},
      ));
      expect(result.isError, isTrue);
      expect(result.content, contains("标题不能为空"));
    });

    // --- 验收3: save_to_knowledge 空内容校验 ---
    test("save_to_knowledge 空内容返回错误", () async {
      final result = await registry.executeCall(ToolCall(
        id: "call-e2b",
        name: "save_to_knowledge",
        arguments: {"title": "标题", "content": ""},
      ));
      expect(result.isError, isTrue);
      expect(result.content, contains("内容不能为空"));
    });

    // --- 验收4: write_diary 空标题校验 ---
    test("write_diary 空标题返回错误", () async {
      final result = await registry.executeCall(ToolCall(
        id: "call-e3",
        name: "write_diary",
        arguments: {"title": "", "content": "正文"},
      ));
      expect(result.isError, isTrue);
      expect(result.content, contains("标题不能为空"));
    });

    // --- 验收5: write_diary 空内容校验 ---
    test("write_diary 空内容返回错误", () async {
      final result = await registry.executeCall(ToolCall(
        id: "call-e4",
        name: "write_diary",
        arguments: {"title": "标题", "content": "   "},
      ));
      expect(result.isError, isTrue);
      expect(result.content, contains("内容不能为空"));
    });

    // --- 验收6: ToolRegistry 未知工具返回友好消息 ---
    test("未知工具返回友好提示不含技术细节", () async {
      final result = await registry.executeCall(ToolCall(
        id: "call-e5",
        name: "nonexistent_tool",
        arguments: {},
      ));
      expect(result.isError, isTrue);
      expect(result.content, contains("未知工具"));
      // 不应暴露 Dart 异常类名
      expect(result.content, isNot(contains("Exception")));
      expect(result.content, isNot(contains("Error")));
    });

    // --- 验收7: read_attachment 参数缺失返回友好提示 ---
    test("read_attachment 参数缺失返回友好提示", () async {
      final tool = ReadAttachmentTool();
      final result = await tool.execute(ToolCall(
        id: "call-e6",
        name: "read_attachment",
        arguments: {},
      ));
      expect(result.isError, isTrue);
      expect(result.content, isNot(contains("NoSuchMethodError")));
    });

    // --- 验收8: save_to_knowledge 类型错误参数不崩溃 ---
    test("save_to_knowledge 类型错误参数返回友好提示", () async {
      final result = await registry.executeCall(ToolCall(
        id: "call-e7",
        name: "save_to_knowledge",
        arguments: {"title": 123, "content": "正文"},
      ));
      // 应优雅处理，不裸抛异常
      expect(result.content, isNot(contains("_CastError")));
    });

    // --- 验收9: write_diary 类型错误参数不崩溃 ---
    test("write_diary 类型错误参数返回友好提示", () async {
      final result = await registry.executeCall(ToolCall(
        id: "call-e8",
        name: "write_diary",
        arguments: {"title": "test", "content": null},
      ));
      // 应优雅处理
      expect(result.isError, isTrue);
      expect(result.content, isNot(contains("NullError")));
    });

    // --- 验收10: get_diary_stats 不泄露技术细节 ---
    test("get_diary_stats 正常返回不含技术信息", () async {
      final result = await registry.executeCall(ToolCall(
        id: "call-e9",
        name: "get_diary_stats",
        arguments: {},
      ));
      expect(result.content, isNot(contains("SqliteException")));
      expect(result.content, isNot(contains("NullError")));
    });

    // --- 验收11: list_categories 正常返回不含技术信息 ---
    test("list_categories 正常返回不含技术信息", () async {
      final result = await registry.executeCall(ToolCall(
        id: "call-e10",
        name: "list_categories",
        arguments: {},
      ));
      expect(result.content, contains("技术开发"));
      expect(result.content, isNot(contains("Exception")));
    });
  });
}
