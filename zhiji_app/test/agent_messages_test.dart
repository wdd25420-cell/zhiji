import "package:flutter_test/flutter_test.dart";
import "package:drift/drift.dart" hide isNotNull, isNull;
import "package:drift/native.dart";
import "package:zhiji/core/database/app_database.dart";

void main() {
  group("T4 验收: agent_messages drift 表", () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test("表创建成功", () async {
      final result = await db.customSelect(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='agent_messages'",
      ).get();
      expect(result, hasLength(1));
    });

    test("按 session_id 查询", () async {
      await db.into(db.agentMessages).insert(
        AgentMessagesCompanion.insert(
          sessionId: "sess-1",
          role: "user",
          content: "帮我搜索 Flutter",
        ),
      );
      await db.into(db.agentMessages).insert(
        AgentMessagesCompanion.insert(
          sessionId: "sess-1",
          role: "assistant",
          content: "好的，正在搜索…",
        ),
      );

      final result = await db.customSelect(
        "SELECT * FROM agent_messages WHERE session_id = ? ORDER BY created_at",
        variables: [Variable.withString("sess-1")],
      ).get();

      expect(result, hasLength(2));
      expect(result[0].read<String>("role"), "user");
      expect(result[1].read<String>("role"), "assistant");
    });

    test("tool 消息带 tool_name", () async {
      await db.customStatement(
        "INSERT INTO agent_messages (session_id, role, content, tool_name) VALUES (?, ?, ?, ?)",
        ["sess-2", "tool", '{"results": 8}', "search_knowledge"],
      );

      final result = await db.customSelect(
        "SELECT tool_name FROM agent_messages WHERE session_id = ?",
        variables: [Variable.withString("sess-2")],
      ).getSingle();
      expect(result.read<String>("tool_name"), "search_knowledge");
    });

    test("时间排序（显式时间戳）", () async {
      final t1 = DateTime(2026, 6, 21, 10, 0, 0);
      final t2 = DateTime(2026, 6, 21, 10, 0, 1);

      await db.customStatement(
        "INSERT INTO agent_messages (session_id, role, content, created_at) VALUES ('s1','user','msg-old',?)",
        [t1.toIso8601String()],
      );
      await db.customStatement(
        "INSERT INTO agent_messages (session_id, role, content, created_at) VALUES ('s1','assistant','msg-new',?)",
        [t2.toIso8601String()],
      );

      final result = await db.customSelect(
        "SELECT content FROM agent_messages ORDER BY created_at DESC",
      ).get();

      expect(result.first.read<String>("content"), "msg-new");
      expect(result.last.read<String>("content"), "msg-old");
    });

    test("schemaVersion 为 2", () {
      expect(db.schemaVersion, 2);
    });
  });
}
