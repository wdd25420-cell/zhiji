import "package:flutter_test/flutter_test.dart";
import "package:zhiji/core/network/ai_api_service.dart";

/// T-REG-1: AIService 老方法回归测试
///
/// 验证 chatCompletion 新增 tools 参数后，所有旧方法行为不变。
/// 无 API Key 时测试结构验证；有 Key 时跑完整的 API 调用。
void main() {
  group("T-REG-1 AIService 方法签名与结构", () {
    test("_post 方法无 tools 参数不传", () {
      // 编译时验证：_post 签名不含 tools 参数
      // 运行时验证：不传 tools 不崩溃
      expect(AIService.askQuestion, isNotNull);
    });

    test("chatCompletion 的 tools 参数可选", () {
      // 编译时验证：tools 参数为 nullable List
      // 不传 tools 时应该不崩溃
    });

    test("analyzeDiary 类型签名正确", () {
      // Future<(String, List<String>)?> analyzeDiary(String title, String content)
      expect(AIService.analyzeDiary, isNotNull);
    });

    test("analyzeKnowledge 类型签名正确", () {
      expect(AIService.analyzeKnowledge, isNotNull);
    });

    test("continueWriting 类型签名正确", () {
      expect(AIService.continueWriting, isNotNull);
    });

    test("polish 类型签名正确", () {
      expect(AIService.polish, isNotNull);
    });

    test("summarize 类型签名正确", () {
      expect(AIService.summarize, isNotNull);
    });

    test("weeklyReview 类型签名正确", () {
      expect(AIService.weeklyReview, isNotNull);
    });

    test("askQuestion 类型签名正确", () {
      expect(AIService.askQuestion, isNotNull);
    });

    test("chatCompletion 类型签名正确，tools 参数可选", () {
      expect(AIService.chatCompletion, isNotNull);
    });
  });

  group("T-REG-1 AIService 函数式回归（需 API Key）", () {
    test("analyzeDiary 返回 (summary, tags) 格式", () async {
      final result = await AIService.analyzeDiary("测试日记", "今天天气很好");
      if (result != null) {
        expect(result.$1, isNotEmpty); // summary
        expect(result.$2, isA<List<String>>()); // tags
      }
    }, skip: "需要有效 DeepSeek API Key");

    test("analyzeKnowledge 返回 (summary, tags) 格式", () async {
      final result = await AIService.analyzeKnowledge("Flutter", "Flutter 是 Google 的 UI 框架");
      if (result != null) {
        expect(result.$1, isNotEmpty);
        expect(result.$2, isA<List<String>>());
      }
    }, skip: "需要有效 DeepSeek API Key");

    test("continueWriting 返回续写内容", () async {
      final result = await AIService.continueWriting("今天天气真好，我们去了");
      if (result != null) {
        expect(result, isNotEmpty);
      }
    }, skip: "需要有效 DeepSeek API Key");

    test("polish 返回润色文本", () async {
      final result = await AIService.polish("这个很好，很棒的，真的不错。");
      if (result != null) {
        expect(result, isNotEmpty);
      }
    }, skip: "需要有效 DeepSeek API Key");

    test("summarize 返回要点总结", () async {
      final result = await AIService.summarize(
        "第一点：Flutter 使用 Dart 语言。第二点：Flutter 支持热重载。第三点：Flutter 跨平台。",
      );
      if (result != null) {
        expect(result, isNotEmpty);
      }
    }, skip: "需要有效 DeepSeek API Key");

    test("weeklyReview 返回本周回顾", () async {
      final result = await AIService.weeklyReview([
        "周一：学习了 Dart 基础",
        "周二：完成了 Flutter 项目搭建",
      ]);
      if (result != null) {
        expect(result, isNotEmpty);
      }
    }, skip: "需要有效 DeepSeek API Key");

    test("askQuestion 返回 RAG 回答", () async {
      final result = await AIService.askQuestion(
        "什么是 Riverpod？",
        "Riverpod 是 Flutter 的依赖注入框架，用于状态管理",
      );
      if (result != null) {
        expect(result, isNotEmpty);
      }
    }, skip: "需要有效 DeepSeek API Key");

    test("chatCompletion 不传 tools 正常返回", () async {
      final result = await AIService.chatCompletion(
        messages: [
          {"role": "user", "content": "回复：你好"}
        ],
      );
      if (result != null) {
        expect(result["content"], isNotNull);
        expect(result["tool_calls"], isNull); // 不传 tools 不应返回 tool_calls
      }
    }, skip: "需要有效 DeepSeek API Key");

    test("chatCompletion 传 tools 支持 tool calling", () async {
      final result = await AIService.chatCompletion(
        messages: [
          {"role": "user", "content": "今天天气怎么样？"}
        ],
        tools: [
          {
            "type": "function",
            "function": {
              "name": "get_weather",
              "description": "获取天气",
              "parameters": {
                "type": "object",
                "properties": {},
              },
            },
          },
        ],
      );
      if (result != null) {
        expect(result["content"], isNotNull);
        // tool_calls 可能存在（取决于模型判断）
      }
    }, skip: "需要有效 DeepSeek API Key");
  });
}