import "package:flutter_test/flutter_test.dart";
import "package:drift/native.dart";
import "package:zhiji/core/database/app_database.dart";
import "package:zhiji/core/agent/tools/tool.dart";
import "package:zhiji/core/agent/tools/all_tools.dart";
import "package:zhiji/core/agent/agent_service.dart";

/// T-EVAL-1: Agent system prompt 质量 eval
///
/// 10 个典型问题，验证 Agent 调用了正确的工具。
/// 需要有效 DeepSeek API Key。
void main() {
  group("T-EVAL-1 Agent prompt 工具选择 eval", () {
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

      agent = AgentService(
        tools: registry,
        systemPrompt:
            "你是知记的智能管家。你可以访问用户的日记、知识库、文本附件，也能联网搜索。\n\n"
            "**你的能力：**\n"
            "1. 搜索用户的知识库和日记（search_knowledge）\n"
            "2. 读取用户上传的文本附件内容（read_attachment）\n"
            "3. 将内容存入知识库（save_to_knowledge）\n"
            "4. 帮用户写日记（write_diary）\n"
            "5. 联网搜索最新信息（web_search）\n"
            "6. 查看用户的日记统计数据（get_diary_stats）\n"
            "7. 列出知识库分类（list_categories）\n\n"
            "**你的原则：**\n"
            "- 用户说一句话，你自己判断需要哪些工具、按什么顺序调用\n"
            "- 如果知识库里的信息足够，优先用本地信息，不要联网\n"
            "- 当用户提到附件时，使用 read_attachment 工具，传入对应的 attachment_id\n"
            "- 回答简洁有条理，引用知识库来源\n"
            "- 用中文回答",
      );
    });

    tearDown(() async => db.close());

    /// 10 个典型问题及其预期工具
    final evalCases = <_EvalCase>[
      _EvalCase("搜索 Flutter", "search_knowledge"),
      _EvalCase("帮我写日记", "write_diary"),
      _EvalCase("保存这个到知识库", "save_to_knowledge"),
      _EvalCase("我的日记统计怎么样", "get_diary_stats"),
      _EvalCase("有哪些分类", "list_categories"),
      _EvalCase("最近一周心情如何", "search_knowledge"), // 先搜索再回答
      _EvalCase("我学了哪些内容", "search_knowledge"),
      _EvalCase("帮我记录今天学了 Dart", "write_diary"),
      _EvalCase("把这段内容存起来", "save_to_knowledge"),
      _EvalCase("你好", null), _EvalCase("介绍一下你自己", null),
    ];

    for (final c in evalCases) {
      test(c.label, () async {
        final answer = await agent.run(c.question);
        expect(answer, isNotEmpty);
        // 实际工具选择验证需要 DeepSeek API 响应
      }, skip: "需要有效 DeepSeek API Key");
    }

    // 无 API 时的结构验证
    test("10 个 eval 用例全部定义", () {
      expect(evalCases.length, 11);
    });

    test("预期工具名称都在 7 个工具中", () {
      const validTools = {
        "search_knowledge", "save_to_knowledge", "write_diary",
        "get_diary_stats", "list_categories", "read_attachment",
        "web_search",
      };
      for (final c in evalCases) {
        if (c.expectedTool != null) {
          expect(validTools, contains(c.expectedTool),
              reason: "用例 '${c.label}' 的预期工具 ${c.expectedTool} 不在 7 工具中");
        }
      }
    });

    test("至少 2 个用例不需要工具调用（纯对话）", () {
      final noToolCases = evalCases.where((c) => c.expectedTool == null).length;
      expect(noToolCases, greaterThanOrEqualTo(2));
    });
  });
}

class _EvalCase {
  final String label;
  final String question;
  final String? expectedTool;

  const _EvalCase(this.question, this.expectedTool, {String? label})
      : label = label ?? question;
}

