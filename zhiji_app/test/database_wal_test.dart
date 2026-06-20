import "dart:io";
import "package:flutter_test/flutter_test.dart";
import "package:drift/native.dart";
import "package:zhiji/core/database/app_database.dart";

void main() {
  group("T1 验收: SQLite WAL 模式 + 写入重试", () {
    // === 验收标准 1: PRAGMA journal_mode 返回 wal ===
    test("WAL 模式已启用（文件数据库）", () async {
      final dbPath = "${Directory.systemTemp.path}/test_wal_${DateTime.now().millisecondsSinceEpoch}.db";
      final fileDb = AppDatabase(NativeDatabase(File(dbPath)));
      try {
        final row = await fileDb.customSelect("PRAGMA journal_mode").getSingle();
        final mode = row.read<String>("journal_mode");
        expect(mode.toLowerCase(), "wal");
      } finally {
        await fileDb.close();
        try { await File(dbPath).delete(); } catch (_) {}
      }
    });

    // === 验收标准 2: 两个并发写入不抛 SQLite 锁异常 ===
    test("并发写入不抛锁异常", () async {
      final db = AppDatabase(NativeDatabase.memory());
      try {
        await db.customStatement("""
          CREATE TABLE IF NOT EXISTS agent_messages (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            session_id TEXT NOT NULL,
            role TEXT NOT NULL,
            content TEXT NOT NULL,
            tool_name TEXT,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP
          )
        """);

        final futures = List.generate(10, (i) {
          return db.customStatement(
            "INSERT INTO agent_messages (session_id, role, content) VALUES (?, ?, ?)",
            ["test-session", "user", "msg-$i"],
          );
        });

        await Future.wait(futures);

        final count = await db.customSelect(
          "SELECT COUNT(*) as cnt FROM agent_messages",
        ).getSingle();
        expect(count.read<int>("cnt"), 10);
      } finally {
        await db.close();
      }
    });

    // === 验收标准 3: runWithRetry 正常路径可用 ===
    test("runWithRetry 可正常调用", () async {
      final db = AppDatabase(NativeDatabase.memory());
      try {
        final result = await db.runWithRetry(() async => 42);
        expect(result, 42);
      } finally {
        await db.close();
      }
    });
  });
}
