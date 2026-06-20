import "package:flutter_riverpod/flutter_riverpod.dart";
import "../database/app_database.dart";
import "tools/tool.dart";
import "tools/all_tools.dart";
import "agent_service.dart";
import "agent_memory.dart";

/// Agent Service Provider——自动注入 db + system prompt + 7 工具 + 用户记忆
final agentServiceProvider = FutureProvider<AgentService>((ref) async {
  final db = await ref.read(databaseProvider.future);

  // T12: 从 agentMemoryProvider 获取记忆
  final memory = ref.read(agentMemoryProvider);
  final memoryFragment = memory.toSystemPromptFragment();

  final registry = ToolRegistry();
  registry.register(SearchKnowledgeTool(db));
  registry.register(SaveToKnowledgeTool(db));
  registry.register(WriteDiaryTool(db));
  registry.register(GetDiaryStatsTool(db));
  registry.register(ListCategoriesTool(db));
  registry.register(ReadAttachmentTool());
  registry.register(WebSearchTool(db));

  return AgentService(
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
        "- 不确定的事诚实说，不要编造\n"
        "- 用中文回答"
        "$memoryFragment",
  );
});

/// T12: 将 memory notifier 暴露为独立 provider，供 UI 层调用
final agentMemoryNotifierProvider = Provider<AgentMemoryNotifier>((ref) {
  return ref.read(agentMemoryProvider.notifier);
});
