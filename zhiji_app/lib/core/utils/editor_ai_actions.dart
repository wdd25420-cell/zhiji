import "package:zhiji/core/agent/agent_service.dart";

/// 编辑器 AI 操作——通过 AgentService 执行续写/润色/总结
///
/// 所有三个操作通过 Agent 统一入口，保留 UndoManager 调用和 UI 行为不变。
class EditorAiActions {
  /// 续写：基于当前内容续写下文
  static Future<String?> continueWriting(
    AgentService agent,
    String body,
  ) async {
    final result = await agent.run(
      "请续写以下内容：\n$body\n\n只返回续写文本，不要任何解释或寒暄。保持与原文一致的风格。",
    );
    if (result.contains("抱歉") || result.contains("不可用")) return null;
    return result;
  }

  /// 润色：优化选中文本的表达
  static Future<String?> polish(
    AgentService agent,
    String selectedText,
  ) async {
    final result = await agent.run(
      "请润色以下文本，保持原意，使其更流畅自然：\n$selectedText\n\n只返回润色后的文本，不要任何解释。",
    );
    if (result.contains("抱歉") || result.contains("不可用")) return null;
    return result;
  }

  /// 总结：将文本压缩为要点列表
  static Future<String?> summarize(
    AgentService agent,
    String text,
  ) async {
    final result = await agent.run(
      "请用要点列表（每行以 - 开头）总结以下内容：\n$text\n\n只返回总结，不要任何解释。",
    );
    if (result.contains("抱歉") || result.contains("不可用")) return null;
    return result;
  }
}