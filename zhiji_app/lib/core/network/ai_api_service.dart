import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../network/dio_client.dart';

/// DeepSeek AI API 服务
class AIService {
  AIService._();

  static const _baseUrl = 'https://api.deepseek.com';
  static const _model = 'deepseek-chat';

  // ============================================================
  // 私有方法
  // ============================================================

  /// 统一的 POST 请求封装
  static Future<String?> _post(
    String systemPrompt,
    String userContent, {
    int maxTokens = 500,
  }) async {
    final dio = AppDio.instance;
    try {
      final response = await dio.post('$_baseUrl/v1/chat/completions', data: {
        'model': _model,
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': userContent},
        ],
        'temperature': 0.5,
        'max_tokens': maxTokens,
        'stream': false,
      }).timeout(const Duration(seconds: 30));
      final choices = (response.data['choices'] as List);
      if (choices.isEmpty) return null;
      return choices[0]['message']['content'] as String?;
    } on DioException catch (e) {
      debugPrint('AI request failed: $e');
      return null;
    } catch (e) {
      debugPrint('AI error: $e');
      return null;
    }
  }

  /// 解析 JSON 响应 {summary, tags}
  static (String, List<String>) _parseJson(String text) {
    final jsonStart = text.indexOf('{');
    final jsonEnd = text.lastIndexOf('}');
    if (jsonStart < 0 || jsonEnd < 0) return (text, <String>[]);
    try {
      final result = jsonDecode(text.substring(jsonStart, jsonEnd + 1)) as Map<String, dynamic>;
      final summary = result['summary'] as String? ?? text;
      final tags = (result['tags'] as List?)?.map((e) => e.toString()).toList() ?? <String>[];
      return (summary, tags);
    } catch (_) {
      return (text, <String>[]);
    }
  }

  /// 截断过长内容，防止超模型上下文窗口
  static String _truncate(String content, int maxChars) =>
      content.length > maxChars ? '${content.substring(0, maxChars)}...' : content;

  // ============================================================
  // 分析类方法
  // ============================================================

  /// 分析日记内容，返回摘要和标签建议
  static Future<(String summary, List<String> tags)?> analyzeDiary(
    String title,
    String content,
  ) async {
    final text = await _post(
      '你是一位日记分析助手。请用中文给出简短摘要（不超过80字），并提取3-5个关键词标签。'
          '返回格式必须严格为 JSON：{"summary": "摘要内容", "tags": ["标签1", "标签2", "标签3"]}',
      '日记标题：$title\n\n日记内容：\n${_truncate(content, 4000)}',
      maxTokens: 300,
    );
    if (text == null) return null;
    return _parseJson(text);
  }

  /// 分析知识内容，返回摘要和关键词
  static Future<(String summary, List<String> tags)?> analyzeKnowledge(
    String title,
    String content,
  ) async {
    final text = await _post(
      '你是一位知识管理助手。请用中文给出简短摘要（不超过80字），并提取3-5个关键词标签。'
          '返回格式必须严格为 JSON：{"summary": "摘要内容", "tags": ["标签1", "标签2", "标签3"]}',
      '知识标题：$title\n\n知识内容：\n${_truncate(content, 4000)}',
      maxTokens: 300,
    );
    if (text == null) return null;
    return _parseJson(text);
  }

  // ============================================================
  // 编辑器 AI 三件套
  // ============================================================

  /// AI 续写：基于已有内容续写下文
  static Future<String?> continueWriting(String context) async {
    return _post(
      '你是写作助手，请续写用户的内容，风格保持一致，200字以内。只返回续写内容，不要寒暄。',
      _truncate(context, 3000),
      maxTokens: 400,
    );
  }

  /// AI 润色：优化选中段落的表达
  static Future<String?> polish(String selection) async {
    return _post(
      '请润色优化以下文字，保持原意，使其更流畅自然。只返回润色后的文本。',
      _truncate(selection, 2000),
      maxTokens: 600,
    );
  }

  /// AI 总结：把长文压成要点
  static Future<String?> summarize(String selection) async {
    return _post(
      '请用要点形式总结以下内容，每条一行以 - 开头。',
      _truncate(selection, 4000),
      maxTokens: 400,
    );
  }

  /// 基于本周所有日记生成回顾
  static Future<String?> weeklyReview(List<String> diaryContents) async {
    if (diaryContents.isEmpty) return null;
    final content = diaryContents.join('\n\n');
    return _post(
      '你是日记回顾助手。请基于用户本周日记，总结情绪模式、主要主题，并给出1-2条积极建议。300字以内。',
      _truncate(content, 8000),
      maxTokens: 800,
    );
  }

  // ============================================================
  // AI 智能问答 (RAG)
  // ============================================================

  /// 基于检索到的上下文回答用户问题 (RAG)
  static Future<String?> askQuestion(String question, String context) async {
    return _post(
      '你是个人知识管理助手"知记"。请基于以下用户的笔记和日记内容回答问题。'
          '如果相关内容不足以回答，诚实说明，不要编造。用中文回答，简洁有条理。',
      '相关笔记/日记：\n$context\n\n用户问题：$question',
      maxTokens: 600,
    );
  }
}
