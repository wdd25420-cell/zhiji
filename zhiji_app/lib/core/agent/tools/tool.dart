import "dart:convert";

/// Agent 工具调用参数
class ToolCall {
  final String id;
  final String name;
  final Map<String, dynamic> arguments;

  const ToolCall({
    required this.id,
    required this.name,
    required this.arguments,
  });

  factory ToolCall.fromJson(Map<String, dynamic> json) {
    final func = json["function"] as Map<String, dynamic>;
    return ToolCall(
      id: json["id"] as String,
      name: func["name"] as String,
      arguments: jsonDecode(func["arguments"] as String) as Map<String, dynamic>,
    );
  }
}

/// Agent 工具执行结果
class ToolResult {
  final String toolCallId;
  final String content;
  final bool isError;

  const ToolResult({
    required this.toolCallId,
    required this.content,
    this.isError = false,
  });

  factory ToolResult.error(String toolCallId, String message) =>
      ToolResult(toolCallId: toolCallId, content: message, isError: true);
}

/// DeepSeek tool definition JSON
typedef ToolDef = Map<String, dynamic>;

/// Agent 工具抽象接口
abstract class AgentTool {
  /// 工具名称（与 system prompt 中对齐）
  String get name;

  /// 工具描述
  String get description;

  /// 工具参数 JSON Schema
  Map<String, dynamic> get parameters;

  /// 转换为 DeepSeek tools 格式
  ToolDef toToolDef() => {
        "type": "function",
        "function": {
          "name": name,
          "description": description,
          "parameters": parameters,
        },
      };

  /// 执行工具
  Future<ToolResult> execute(ToolCall call);

  /// 设置当前附件列表（默认空实现，ReadAttachmentTool 覆写）
  void setAttachments(List<dynamic> attachments) {}
}

/// 工具注册表——管理所有 Agent 工具
class ToolRegistry {
  final Map<String, AgentTool> _tools = {};

  void register(AgentTool tool) {
    _tools[tool.name] = tool;
  }

  AgentTool? get(String name) => _tools[name];

  List<ToolDef> get toolDefs =>
      _tools.values.map((t) => t.toToolDef()).toList();

  /// 将附件列表注入到 ReadAttachmentTool（如已注册）
  void setAttachments(List<dynamic> attachments) {
    _tools["read_attachment"]?.setAttachments(attachments);
  }

  /// 执行一个 tool call，统一错误包装
  Future<ToolResult> executeCall(ToolCall call) async {
    final tool = _tools[call.name];
    if (tool == null) {
      return ToolResult.error(
        call.id,
        "未知工具: ${call.name}",
      );
    }
    try {
      return await tool.execute(call);
    } catch (e) {
      return ToolResult.error(call.id, "操作暂时无法完成，请稍后重试");
    }
  }
}
