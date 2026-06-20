import "package:flutter_test/flutter_test.dart";
import "package:drift/native.dart";
import "package:zhiji/core/database/app_database.dart";
import "package:zhiji/core/database/daos/common_daos.dart";
import "package:zhiji/core/agent/agent_memory.dart";

void main() {
  group("T12 验收: 用户偏好记忆", () {
    late AppDatabase db;
    late SettingsDao dao;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      dao = SettingsDao(db);
    });

    tearDown(() async => db.close());

    // --- 验收1: 首次使用返回空记忆 ---
    test("首次使用返回空记忆", () async {
      final memory = await AgentMemory.load(dao);
      expect(memory.interests, isEmpty);
      expect(memory.recentTopics, isEmpty);
      expect(memory.preferredCategories, isEmpty);
      expect(memory.toSystemPromptFragment(), "");
    });

    // --- 验收2: 添加话题 + 持久化 ---
    test("addRecentTopic 追加话题并持久化", () async {
      final memory = AgentMemory();
      memory.addRecentTopic("Flutter");
      memory.addRecentTopic("Dart");
      memory.addRecentTopic("Flutter"); // 去重——移到最前
      await memory.save(dao);

      final loaded = await AgentMemory.load(dao);
      expect(loaded.recentTopics, ["Flutter", "Dart"]);
    });

    // --- 验收3: recentTopics 最多 10 条 ---
    test("recentTopics 最多保留 10 条", () async {
      final memory = AgentMemory();
      for (var i = 0; i < 15; i++) {
        memory.addRecentTopic("topic_$i");
      }
      expect(memory.recentTopics.length, 10);
      // 最新的在前
      expect(memory.recentTopics.first, "topic_14");
    });

    // --- 验收4: toSystemPromptFragment 生成正确 ---
    test("toSystemPromptFragment 生成提示文本", () async {
      final memory = AgentMemory(
        interests: ["Flutter", "Dart"],
        recentTopics: ["Riverpod", "空安全"],
      );
      final fragment = memory.toSystemPromptFragment();
      expect(fragment, contains("Flutter"));
      expect(fragment, contains("Dart"));
      expect(fragment, contains("[用户偏好]"));
    });

    // --- 验收5: touchCategory 更新分类 ---
    test("touchCategory 更新分类顺序", () async {
      final memory = AgentMemory();
      memory.touchCategory(3);
      memory.touchCategory(1);
      memory.touchCategory(3); // 重复——移到最前
      await memory.save(dao);

      final loaded = await AgentMemory.load(dao);
      expect(loaded.preferredCategories, [3, 1]);
    });

    // --- 验收6: 损坏 JSON 不影响加载 ---
    test("损坏 JSON 返回空记忆", () async {
      await dao.setValue("agent_memory", "{bad json!!!");
      final memory = await AgentMemory.load(dao);
      expect(memory.interests, isEmpty);
    });

    // --- 验收7: lastSummarized 持久化 ---
    test("lastSummarized 持久化", () async {
      final memory = AgentMemory(lastSummarized: "2026-06-21");
      await memory.save(dao);

      final loaded = await AgentMemory.load(dao);
      expect(loaded.lastSummarized, "2026-06-21");
    });
  });
}