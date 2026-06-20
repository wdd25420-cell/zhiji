import "dart:async";
import "package:flutter/foundation.dart";
import "../network/ai_api_service.dart";
import "../utils/file_attachment_manager.dart";
import "tools/tool.dart";

/// Agent 步骤事件类型
enum AgentStepType {
  thinking,     // 思考中
  searching,    // 正在搜索知识库
  webSearching, // 正在联网搜索
  analyzing,    // 正在分析结果
  writing,      // 正在写入
  responding,   // 流式回复 delta
  done,         // 完成
  error,        // 出错
}

/// Agent 步骤事件
class AgentStep {
  final AgentStepType type;
  final String? contentDelta;
  final String? toolName;
  const AgentStep({required this.type, this.contentDelta, this.toolName});
}

/// Agent 服务——手写 ReAct 循环（三层超时）
class AgentService {
  static const maxIterations = 5;
  static const toolTimeout = Duration(seconds: 45);
  static const totalTimeout = Duration(seconds: 120);

  final ToolRegistry tools;
  final String systemPrompt;

  AgentService({
    required this.tools,
    required this.systemPrompt,
  });

  Future<String> run(
    String userInput, {
    List<Map<String, dynamic>>? history,
    List<AttachedFile>? attachments,
  }) async {
    // 将附件注入工具注册表，ReadAttachmentTool 可查询
    if (attachments != null) {
      tools.setAttachments(attachments);
    } else {
      tools.setAttachments([]);
    }

    // 构建附件提示文本
    final attachmentHint = _buildAttachmentHint(attachments);
    final effectivePrompt = attachmentHint != null
        ? "$systemPrompt\n\n$attachmentHint"
        : systemPrompt;

    final messages = <Map<String, dynamic>>[
      {"role": "system", "content": effectivePrompt},
      if (history != null) ...history,
      {"role": "user", "content": userInput},
    ];

    final toolDefs = tools.toolDefs;

    try {
      return await _loop(messages, toolDefs).timeout(totalTimeout);
    } on Exception catch (_) {
      return "思考时间过长，请简化你的问题后重试。";
    }
  }

  /// 构建附件提示：告知 Agent 当前有哪些附件可用及对应的 attachment_id
  String? _buildAttachmentHint(List<AttachedFile>? attachments) {
    if (attachments == null || attachments.isEmpty) return null;
    final lines = <String>[
      "当前对话中用户上传了以下附件：",
      for (final f in attachments)
        "- attachment_id: ${f.storedPath}（文件名: ${f.name}, 大小: ${f.sizeLabel}）",
      "read_attachment 工具通过这些 attachment_id 来读取文件内容。",
    ];
    return lines.join("\n");
  }

  Future<String> _loop(
    List<Map<String, dynamic>> messages,
    List<ToolDef> toolDefs,
  ) async {
    var loopDetector = <String, int>{};
    final executedTools = <String>[];

    for (var i = 0; i < maxIterations; i++) {
      final response = await AIService.chatCompletion(
        messages: messages,
        tools: toolDefs.isNotEmpty ? toolDefs : null,
      );

      if (response == null) {
        if (executedTools.isNotEmpty) {
          final toolNames = executedTools
              .map((t) => switch (t) {
                "write_diary" => "✅ 日记已写好",
                "save_to_knowledge" => "✅ 知识条目已保存",
                _ => "✅ $t 已完成",
              })
              .join("；");
          return "$toolNames\n\n⚠️ AI 服务暂时不可用，无法生成进一步的回复。请稍后重试。";
        }
        return "抱歉，AI 服务暂时不可用，请稍后重试。";
      }

      final toolCallsRaw = response["tool_calls"] as List?;
      if (toolCallsRaw != null && toolCallsRaw.isNotEmpty) {
        for (final tcJson in toolCallsRaw) {
          final tc = ToolCall.fromJson(tcJson as Map<String, dynamic>);

          loopDetector[tc.name] = (loopDetector[tc.name] ?? 0) + 1;
          if (loopDetector[tc.name]! > 3) {
            messages.add({
              "role": "tool",
              "tool_call_id": tc.id,
              "content": "工具已重复调用多次，请基于已有信息回答。",
            });
            continue;
          }

          final result = await tools
              .executeCall(tc)
              .timeout(toolTimeout, onTimeout: () {
            return ToolResult.error(tc.id, "操作超时");
          });

          if (!result.isError) {
            executedTools.add(tc.name);
          }

          messages.add({
            "role": "tool",
            "tool_call_id": tc.id,
            "content": result.content,
          });
        }

        messages.add({
          "role": "assistant",
          "content": response["content"],
          "tool_calls": toolCallsRaw,
        });
        continue;
      }

      return (response["content"] as String?) ?? "无法处理你的请求。";
    }

    debugPrint("[Agent] 循环耗尽(maxIterations=$maxIterations)，强制总结");
    messages.add({
      "role": "user",
      "content": "请基于已有的工具调用结果，综合回答用户最初的问题。简洁扼要。",
    });
    final response = await AIService.chatCompletion(
      messages: messages,
      maxTokens: 600,
    );
    return (response?["content"] as String?) ?? "信息整理中，请稍后重试。";
  }

  /// 流式执行 Agent 循环——每步产生 AgentStep 事件
  Stream<AgentStep> runStream(
    String userInput, {
    List<Map<String, dynamic>>? history,
    List<AttachedFile>? attachments,
  }) async* {
    if (attachments != null) {
      tools.setAttachments(attachments);
    } else {
      tools.setAttachments([]);
    }

    final attachmentHint = _buildAttachmentHint(attachments);
    final effectivePrompt = attachmentHint != null
        ? "$systemPrompt\n\n$attachmentHint"
        : systemPrompt;

    final messages = <Map<String, dynamic>>[
      {"role": "system", "content": effectivePrompt},
      if (history != null) ...history,
      {"role": "user", "content": userInput},
    ];

    final toolDefs = tools.toolDefs;
    var loopDetector = <String, int>{};
    var canceled = false;
    final executedTools = <String>[]; // 追踪已成功执行的工具
    final timer = Timer(totalTimeout, () { canceled = true; });

    try {
      for (var i = 0; i < maxIterations && !canceled; i++) {
        yield const AgentStep(type: AgentStepType.thinking);

        final response = await AIService.chatCompletion(
          messages: messages,
          tools: toolDefs.isNotEmpty ? toolDefs : null,
        );

        if (response == null) {
          yield const AgentStep(type: AgentStepType.error);
          if (executedTools.isNotEmpty) {
            // 工具已执行但后续 API 失败——告知用户已完成的操作
            final summary = executedTools
                .map((t) => switch (t) {
                  "write_diary" => "✅ 日记已写好",
                  "save_to_knowledge" => "✅ 知识条目已保存",
                  _ => "✅ $t 已完成",
                })
                .join("；");
            yield AgentStep(
              type: AgentStepType.responding,
              contentDelta: "$summary\n\n⚠️ AI 服务暂时不可用，无法生成进一步的回复。请稍后重试或检查网络连接。",
            );
          } else {
            yield const AgentStep(
              type: AgentStepType.responding,
              contentDelta: "抱歉，AI 服务暂时不可用，请稍后重试。",
            );
          }
          yield const AgentStep(type: AgentStepType.done);
          return;
        }

        final toolCallsRaw = response["tool_calls"] as List?;
        if (toolCallsRaw != null && toolCallsRaw.isNotEmpty) {
          for (final tcJson in toolCallsRaw) {
            final tc = ToolCall.fromJson(tcJson as Map<String, dynamic>);

            loopDetector[tc.name] = (loopDetector[tc.name] ?? 0) + 1;
            if (loopDetector[tc.name]! > 3) {
              messages.add({
                "role": "tool",
                "tool_call_id": tc.id,
                "content": "工具已重复调用多次，请基于已有信息回答。",
              });
              continue;
            }

            // 推送工具状态
            switch (tc.name) {
              case "search_knowledge":
                yield const AgentStep(type: AgentStepType.searching, toolName: "search_knowledge");
                break;
              case "web_search":
                yield const AgentStep(type: AgentStepType.webSearching, toolName: "web_search");
                break;
              case "write_diary":
                yield const AgentStep(type: AgentStepType.writing, toolName: "write_diary");
                break;
              case "save_to_knowledge":
                yield const AgentStep(type: AgentStepType.writing, toolName: "save_to_knowledge");
                break;
              default:
                yield AgentStep(type: AgentStepType.analyzing, toolName: tc.name);
            }

            final result = await tools
                .executeCall(tc)
                .timeout(toolTimeout, onTimeout: () {
              return ToolResult.error(tc.id, "操作超时");
            });

            if (!result.isError) {
              executedTools.add(tc.name);
            }

            messages.add({
              "role": "tool",
              "tool_call_id": tc.id,
              "content": result.content,
            });
          }

          messages.add({
            "role": "assistant",
            "content": response["content"],
            "tool_calls": toolCallsRaw,
          });
          continue;
        }

        // 最后一步：流式输出回复
        final content = response["content"] as String? ?? "";
        if (content.isNotEmpty) {
          yield AgentStep(type: AgentStepType.responding, contentDelta: content);
        }
        timer.cancel();
        yield const AgentStep(type: AgentStepType.done);
        return;
      }

      // 循环耗尽或超时
      timer.cancel();
      yield const AgentStep(type: AgentStepType.error);
      yield AgentStep(
        type: AgentStepType.responding,
        contentDelta: canceled
            ? "思考时间过长，请简化你的问题后重试。"
            : "思考时间过长，请简化你的问题后重试。",
      );
      yield const AgentStep(type: AgentStepType.done);
    } catch (e) {
      timer.cancel();
      yield const AgentStep(type: AgentStepType.error);
      yield AgentStep(
        type: AgentStepType.responding,
        contentDelta: "处理请求时出错，请稍后重试。",
      );
      yield const AgentStep(type: AgentStepType.done);
    }
  }
}